import AVFoundation
import Flutter
import UIKit
import UserNotifications
import flutter_foreground_task

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeAppDataFromBackup()

    // flutter_foreground_task runs its TaskHandler in a separate headless
    // engine; plugins must be registered on that engine too (see the plugin's
    // README, "iOS > Swift").
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Lets the "recording in progress" notification show while Insato is in
    // the foreground.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBatteryChannel(engineBridge.pluginRegistry)
    registerAudioImportChannels(engineBridge.pluginRegistry)
  }

  // Recording import (lib/features/import_audio/): kept alive with the app.
  private var audioDecoder: AudioDecoderChannel?
  private var sharedAudio: SharedAudioInbox?

  /// The AVAssetReader decoder ("insato/audio_decoder") and the "Open in" /
  /// share-sheet inbox ("insato/shared_audio", scene URL callbacks).
  private func registerAudioImportChannels(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "InsatoAudioImport") else { return }
    audioDecoder = AudioDecoderChannel(messenger: registrar.messenger())
    let inbox = SharedAudioInbox(messenger: registrar.messenger())
    registrar.addSceneDelegate(inbox)
    sharedAudio = inbox
  }

  /// v1.2 C: a guest device reports its battery to the meeting host
  /// (lib/features/multi_device/battery.dart).
  private func registerBatteryChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "InsatoBattery") else { return }
    let channel = FlutterMethodChannel(
      name: "insato/battery", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let device = UIDevice.current
      device.isBatteryMonitoringEnabled = true
      let level = device.batteryLevel
      var reply: [String: Any] = [:]
      if level >= 0 { reply["level"] = Int((level * 100).rounded()) }
      switch device.batteryState {
      case .charging, .full: reply["charging"] = true
      case .unplugged: reply["charging"] = false
      default: break
      }
      result(reply)
    }
  }

  /// Keeps meeting audio, transcripts, voiceprints and downloaded models out
  /// of iCloud / computer backups (privacy policy: they never leave the
  /// device; models are re-downloadable). Excluding a directory excludes
  /// everything inside it. Mirrors android:allowBackup="false" on Android.
  private func excludeAppDataFromBackup() {
    let fileManager = FileManager.default
    let directories: [FileManager.SearchPathDirectory] = [
      .documentDirectory,
      .applicationSupportDirectory,
    ]
    for directory in directories {
      guard var url = fileManager.urls(for: directory, in: .userDomainMask).first else {
        continue
      }
      do {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
      } catch {
        NSLog("Insato: could not exclude %@ from backup: %@", url.path, error.localizedDescription)
      }
    }
  }
}

// MARK: - Recording import

/// A decoding failure with a protocol error code (unsupported, not_found,
/// io, decode); see lib/features/import_audio/audio_decoder.dart.
struct AudioDecodeFailure: Error {
  let code: String
  let message: String
}

/// MethodChannel "insato/audio_decoder": decodes m4a / AAC, mp3, wav, caf,
/// aiff, flac, amr and 3gp audio with AVAssetReader into interleaved
/// 16-bit PCM. The reader converts to 16 kHz mono itself; the reply states
/// the format, so a fallback to the file's own rate also works. All
/// decoding runs on one serial background queue; replies go back to the
/// main thread. Dart pulls the PCM chunk by chunk.
final class AudioDecoderChannel {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "app.insato.audio-decoder")
  // Accessed on `queue` only.
  private var sessions: [Int: AudioDecodeSession] = [:]
  private var nextHandle = 1

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "insato/audio_decoder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private static func fail(_ result: @escaping FlutterResult, _ error: Error) {
    let failure = error as? AudioDecodeFailure
      ?? AudioDecodeFailure(code: "decode", message: error.localizedDescription)
    DispatchQueue.main.async {
      result(FlutterError(code: failure.code, message: failure.message, details: nil))
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "isSupported":
      result(true)
    case "open":
      guard let path = args?["path"] as? String else {
        result(FlutterError(code: "io", message: "missing path", details: nil))
        return
      }
      Task {
        do {
          let session = try await AudioDecodeSession.open(path: path)
          self.queue.async {
            let handle = self.nextHandle
            self.nextHandle += 1
            self.sessions[handle] = session
            var reply: [String: Any] = [
              "handle": handle,
              "sampleRate": session.sampleRate,
              "channels": session.channels,
            ]
            if let d = session.durationMs { reply["durationMs"] = d }
            if let c = session.codec { reply["codec"] = c }
            if let c = session.creationDate { reply["creationDate"] = c }
            AudioDecoderChannel.reply(result, reply)
          }
        } catch {
          AudioDecoderChannel.fail(result, error)
        }
      }
    case "read":
      let handle = args?["handle"] as? Int ?? -1
      let maxBytes = min(max(args?["maxBytes"] as? Int ?? 262_144, 4096), 4 * 1024 * 1024)
      queue.async {
        guard let session = self.sessions[handle] else {
          AudioDecoderChannel.fail(
            result, AudioDecodeFailure(code: "decode", message: "unknown handle"))
          return
        }
        do {
          guard let data = try session.read(maxBytes: maxBytes) else {
            AudioDecoderChannel.reply(result, nil)
            return
          }
          AudioDecoderChannel.reply(result, [
            "data": FlutterStandardTypedData(bytes: data),
            "sampleRate": session.sampleRate,
            "channels": session.channels,
          ])
        } catch {
          AudioDecoderChannel.fail(result, error)
        }
      }
    case "close":
      let handle = args?["handle"] as? Int ?? -1
      queue.async {
        self.sessions.removeValue(forKey: handle)?.close()
        AudioDecoderChannel.reply(result, nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// One open file: an AVAssetReader on its first audio track.
final class AudioDecodeSession {
  let sampleRate: Int
  let channels: Int
  let durationMs: Int?
  let codec: String?
  let creationDate: String?
  private let reader: AVAssetReader
  private let output: AVAssetReaderTrackOutput
  private var finished = false

  private init(
    reader: AVAssetReader, output: AVAssetReaderTrackOutput, sampleRate: Int,
    channels: Int, durationMs: Int?, codec: String?, creationDate: String?
  ) {
    self.reader = reader
    self.output = output
    self.sampleRate = sampleRate
    self.channels = channels
    self.durationMs = durationMs
    self.codec = codec
    self.creationDate = creationDate
  }

  static func open(path: String) async throws -> AudioDecodeSession {
    guard FileManager.default.fileExists(atPath: path) else {
      throw AudioDecodeFailure(code: "not_found", message: path)
    }
    guard FileManager.default.isReadableFile(atPath: path) else {
      throw AudioDecodeFailure(code: "io", message: "not readable")
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let tracks: [AVAssetTrack]
    do {
      tracks = try await asset.loadTracks(withMediaType: .audio)
    } catch {
      // No AVFoundation importer for this container (e.g. Ogg).
      throw AudioDecodeFailure(code: "unsupported", message: error.localizedDescription)
    }
    guard let track = tracks.first else {
      throw AudioDecodeFailure(code: "unsupported", message: "no audio track")
    }

    var sourceRate = 0
    var sourceChannels = 0
    var codec: String?
    if let descriptions = try? await track.load(.formatDescriptions),
      let first = descriptions.first,
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(first)?.pointee
    {
      sourceRate = Int(asbd.mSampleRate)
      sourceChannels = Int(asbd.mChannelsPerFrame)
      codec = fourCC(asbd.mFormatID)
    }
    var durationMs: Int?
    if let duration = try? await asset.load(.duration), duration.isNumeric {
      let seconds = CMTimeGetSeconds(duration)
      if seconds.isFinite && seconds > 0 { durationMs = Int(seconds * 1000) }
    }
    var creationDate: String?
    if let item = try? await asset.load(.creationDate) {
      if let date = try? await item.load(.dateValue) {
        creationDate = ISO8601DateFormatter().string(from: date)
      } else if let text = try? await item.load(.stringValue) {
        creationDate = text
      }
    }

    // Preferred: let AVFoundation resample and downmix to 16 kHz mono.
    let converted: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
    ]
    // Fallback: the file's own rate and channels.
    let native: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let attempts: [([String: Any], Int, Int)] = [
      (converted, 16000, 1),
      (native, sourceRate > 0 ? sourceRate : 16000, max(sourceChannels, 1)),
    ]
    var lastError: Error?
    for (settings, rate, channels) in attempts {
      do {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { continue }
        reader.add(output)
        guard reader.startReading() else {
          lastError = reader.error
          continue
        }
        return AudioDecodeSession(
          reader: reader, output: output, sampleRate: rate, channels: channels,
          durationMs: durationMs, codec: codec, creationDate: creationDate)
      } catch {
        lastError = error
      }
    }
    throw AudioDecodeFailure(
      code: "unsupported",
      message: lastError?.localizedDescription ?? "cannot decode \(codec ?? "audio")")
  }

  /// Up to about `maxBytes` of PCM16; nil at the end of the stream.
  func read(maxBytes: Int) throws -> Data? {
    if finished { return nil }
    var data = Data()
    data.reserveCapacity(maxBytes + 65_536)
    while data.count < maxBytes {
      guard let buffer = output.copyNextSampleBuffer() else {
        if reader.status == .failed {
          throw AudioDecodeFailure(
            code: "decode", message: reader.error?.localizedDescription ?? "reader failed")
        }
        finished = true
        break
      }
      guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
      let length = CMBlockBufferGetDataLength(block)
      if length <= 0 { continue }
      var bytes = Data(count: length)
      let status = bytes.withUnsafeMutableBytes { raw -> OSStatus in
        guard let base = raw.baseAddress else { return kCMBlockBufferBadCustomBlockSourceErr }
        return CMBlockBufferCopyDataBytes(
          block, atOffset: 0, dataLength: length, destination: base)
      }
      if status == kCMBlockBufferNoErr { data.append(bytes) }
    }
    if data.isEmpty && finished { return nil }
    return data
  }

  func close() {
    if reader.status == .reading { reader.cancelReading() }
    finished = true
  }

  private static func fourCC(_ id: AudioFormatID) -> String {
    let chars = [24, 16, 8, 0].map { Character(UnicodeScalar(UInt8((id >> $0) & 0xFF))) }
    return String(chars).trimmingCharacters(in: .whitespaces)
  }
}

/// "Open in Insato" / share sheet: audio files other apps hand over
/// (CFBundleDocumentTypes in Info.plist; iOS copies them into
/// Documents/Inbox). Each file is moved to the temporary directory and
/// queued for Dart, which pulls the queue through "insato/shared_audio"
/// (takePending) after an "onShared" notification; see
/// lib/features/import_audio/shared_audio_inbox.dart.
final class SharedAudioInbox: NSObject, FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel
  // Main thread only.
  private var pending: [[String: Any]] = []

  // Same limit as kMaxImportBytes in audio_formats.dart (2 GiB).
  private static let maxBytes: Int64 = 2 * 1024 * 1024 * 1024

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "insato/shared_audio", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takePending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.pending ?? [])
      self?.pending.removeAll()
    }
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts, !contexts.isEmpty else { return false }
    return receive(contexts.map { $0.url })
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return receive(URLContexts.map { $0.url })
  }

  private func receive(_ urls: [URL]) -> Bool {
    // Meeting packages (.insato) stay in Documents/Inbox for the package
    // import, which looks there at start and on resume
    // (lib/features/meeting_package/package_providers.dart).
    let files = urls.filter { $0.isFileURL && $0.pathExtension.lowercased() != "insato" }
    if files.isEmpty { return false }
    DispatchQueue.global(qos: .userInitiated).async {
      let entries = files.prefix(5).map { SharedAudioInbox.copy($0) }
      DispatchQueue.main.async {
        self.pending.append(contentsOf: entries)
        self.channel.invokeMethod("onShared", arguments: nil)
      }
    }
    return true
  }

  private static func copy(_ url: URL) -> [String: Any] {
    let name = url.lastPathComponent
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let fileManager = FileManager.default
    if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
      Int64(size) > maxBytes
    {
      removeInboxCopy(url)
      return ["name": name, "error": "too_large"]
    }
    let dir = fileManager.temporaryDirectory.appendingPathComponent(
      "shared_audio", isDirectory: true)
    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    let target = dir.appendingPathComponent("\(stamp)_\(name)")
    do {
      try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
      try fileManager.copyItem(at: url, to: target)
      removeInboxCopy(url)
      return ["path": target.path, "name": name]
    } catch {
      return ["name": name, "error": "copy_failed"]
    }
  }

  /// Deletes the copy iOS placed in Documents/Inbox (private data root).
  private static func removeInboxCopy(_ url: URL) {
    if url.path.contains("/Documents/Inbox/") {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
