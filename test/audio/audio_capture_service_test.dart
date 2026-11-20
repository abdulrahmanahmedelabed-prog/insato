import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/audio/pcm.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/errors.dart';
import 'package:record/record.dart';

/// In-memory stand-in for the native recorder.
class FakeRecordPlatform extends RecordPlatform {
  bool permission = true;
  bool encoderSupported = true;
  Object? startError;
  Object? resumeError;
  RecordConfig? lastConfig;
  RecordConfig? announceOnStart;
  void Function(RecordConfig config)? onConfigChanged;
  StreamController<Uint8List>? data;
  final states = StreamController<RecordState>.broadcast();
  final stops = StreamController<RecordStop>.broadcast();
  List<InputDevice> devices = const [];

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      permission;

  @override
  Future<bool> isEncoderSupported(String recorderId, AudioEncoder e) async =>
      encoderSupported;

  @override
  void setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig config)? handler,
  ) => onConfigChanged = handler;

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    if (startError != null) throw startError!;
    lastConfig = config;
    final announce = announceOnStart;
    if (announce != null) onConfigChanged?.call(announce);
    data = StreamController<Uint8List>();
    states.add(RecordState.record);
    return data!.stream;
  }

  @override
  Future<String?> stop(String recorderId) async {
    await data?.close();
    states.add(RecordState.stop);
    return null;
  }

  @override
  Future<void> pause(String recorderId) async => states.add(RecordState.pause);

  @override
  Future<void> resume(String recorderId) async {
    if (resumeError != null) throw resumeError!;
    states.add(RecordState.record);
  }

  @override
  Future<void> cancel(String recorderId) => stop(recorderId);

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -160, max: -160);

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> isRecording(String recorderId) async => data != null;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async =>
      devices;

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async => throw UnimplementedError();

  @override
  Stream<RecordState> onStateChanged(String recorderId) => states.stream;

  @override
  Stream<RecordStop> onStopped(String recorderId) => stops.stream;
}

Uint8List tonePcm(int rate, int channels, int frames, {double amp = 0.5}) {
  final s = Float32List(frames * channels);
  for (var i = 0; i < frames; i++) {
    final v = amp * math.sin(2 * math.pi * 440 * i / rate);
    for (var c = 0; c < channels; c++) {
      s[i * channels + c] = v;
    }
  }
  return float32ToPcm16Bytes(s);
}

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late FakeRecordPlatform fake;
  late Directory dir;
  late AudioCaptureService service;

  setUp(() async {
    fake = FakeRecordPlatform();
    RecordPlatform.instance = fake;
    dir = await Directory.systemTemp.createTemp('insato_capture_test');
    service = AudioCaptureService(platform: CapturePlatform.android);
  });

  tearDown(() async {
    await service.dispose();
    await dir.delete(recursive: true);
  });

  test('buildRecordConfig requests 16 kHz mono PCM16 with sane effects', () {
    final android = buildRecordConfig(platform: CapturePlatform.android);
    expect(android.encoder, AudioEncoder.pcm16bits);
    expect(android.sampleRate, 16000);
    expect(android.numChannels, 1);
    expect(android.echoCancel, isFalse);
    // Call-style NS/AGC are opt-in: they hurt far-field ASR and voiceprints.
    expect(android.noiseSuppress, isFalse);
    expect(android.autoGain, isFalse);
    expect(android.androidConfig.useLegacy, isFalse);
    expect(
      android.androidConfig.audioSource,
      AndroidAudioSource.voiceRecognition,
    );
    expect(android.androidConfig.manageBluetooth, isFalse);
    // Android must never request audio focus: media / notifications / VoIP
    // would otherwise pause the take (permanently on AUDIOFOCUS_LOSS).
    expect(android.audioInterruption, AudioInterruptionMode.none);
    expect(android.audioRouteChange, AudioRouteChangeMode.follow);

    final ios = buildRecordConfig(platform: CapturePlatform.ios);
    expect(ios.autoGain, isFalse); // would enable voice processing
    expect(ios.echoCancel, isFalse);
    expect(ios.noiseSuppress, isFalse);
    expect(ios.iosConfig.allowHapticsAndSystemSoundsDuringRecording, isTrue);
    expect(ios.audioInterruption, AudioInterruptionMode.pauseResume);
    // No HFP by default: iOS would route input to a connected headset mic.
    expect(
      ios.iosConfig.categoryOptions,
      isNot(contains(IosAudioCategoryOption.allowBluetooth)),
    );
    expect(
      ios.iosConfig.categoryOptions,
      containsAll(<IosAudioCategoryOption>[
        IosAudioCategoryOption.defaultToSpeaker,
        IosAudioCategoryOption.allowBluetoothA2DP,
      ]),
    );

    const device = InputDevice(id: 'usb', label: 'USB Mic');
    final win = buildRecordConfig(
      platform: CapturePlatform.windows,
      device: device,
    );
    expect(win.device, device);
    expect(win.autoGain, isFalse);
  });

  test('opt-in Android NS/AGC are still passed through', () {
    final cfg = buildRecordConfig(
      platform: CapturePlatform.android,
      options: const AudioCaptureOptions(
        noiseSuppress: true,
        autoGainOnAndroid: true,
      ),
    );
    expect(cfg.noiseSuppress, isTrue);
    expect(cfg.autoGain, isTrue);
  });

  test('iOS allows HFP only for an explicitly selected Bluetooth mic', () {
    const airpods = InputDevice(
      id: 'x',
      label: 'AirPods',
      type: InputDeviceType.bluetoothSco,
    );
    final bt = buildRecordConfig(
      platform: CapturePlatform.ios,
      device: airpods,
    );
    expect(
      bt.iosConfig.categoryOptions,
      contains(IosAudioCategoryOption.allowBluetooth),
    );
    expect(
      bt.iosConfig.categoryOptions
          .where((o) => o == IosAudioCategoryOption.allowBluetooth)
          .length,
      1,
    );

    const builtIn = InputDevice(
      id: 'b',
      label: 'iPhone Microphone',
      type: InputDeviceType.builtIn,
    );
    final mic = buildRecordConfig(
      platform: CapturePlatform.ios,
      device: builtIn,
    );
    expect(
      mic.iosConfig.categoryOptions,
      isNot(contains(IosAudioCategoryOption.allowBluetooth)),
    );

    // Already allowed by the caller: not duplicated.
    final dup = buildRecordConfig(
      platform: CapturePlatform.ios,
      device: airpods,
      options: const AudioCaptureOptions(
        iosCategoryOptions: [IosAudioCategoryOption.allowBluetooth],
      ),
    );
    expect(dup.iosConfig.categoryOptions, [
      IosAudioCategoryOption.allowBluetooth,
    ]);
  });

  group('silence watchdog', () {
    const watchdog = Duration(milliseconds: 100);
    // 100 ms at 16 kHz.
    const watchdogSamples = 1600;

    AudioCaptureService make(CapturePlatform platform) => AudioCaptureService(
      platform: platform,
      options: const AudioCaptureOptions(silenceWatchdog: watchdog),
    );

    test(
      'warns once (with the Windows privacy hint) on all-zero PCM',
      () async {
        final svc = make(CapturePlatform.windows);
        final errors = <AudioCaptureException>[];
        svc.errors.listen(errors.add);
        await svc.start();
        fake.data!.add(Uint8List(watchdogSamples * 2 - 2));
        await pump();
        expect(errors, isEmpty);
        fake.data!.add(Uint8List(4));
        await pump();
        expect(errors, hasLength(1));
        expect(errors.single.messageAr, contains('الخصوصية'));
        expect(errors.single.debugDetails, contains('all-zero'));
        // Keeps recording; no repeated warning.
        fake.data!.add(Uint8List(watchdogSamples * 4));
        await Future<void>.delayed(watchdog * 2);
        expect(errors, hasLength(1));
        expect(svc.state, AudioCaptureState.recording);
        await svc.dispose();
      },
    );

    test('warns when no audio arrives at all', () async {
      final svc = make(CapturePlatform.windows);
      final errors = <AudioCaptureException>[];
      svc.errors.listen(errors.add);
      await svc.start();
      await Future<void>.delayed(watchdog * 2);
      expect(errors, hasLength(1));
      expect(errors.single.debugDetails, contains('no PCM'));
      expect(svc.isRecording, isTrue);
      await svc.dispose();
    });

    test('stays quiet when the mic delivers real signal', () async {
      final svc = make(CapturePlatform.android);
      final errors = <AudioCaptureException>[];
      svc.errors.listen(errors.add);
      await svc.start();
      // Very low-level noise floor (a few LSB) still counts as signal.
      fake.data!.add(tonePcm(16000, 1, 160, amp: 4 / 32768));
      fake.data!.add(Uint8List(watchdogSamples * 4));
      await Future<void>.delayed(watchdog * 2);
      expect(errors, isEmpty);
      await svc.dispose();
    });

    test('does not fire while paused and re-arms on resume', () async {
      final svc = make(CapturePlatform.android);
      final errors = <AudioCaptureException>[];
      svc.errors.listen(errors.add);
      await svc.start();
      await svc.pause();
      await Future<void>.delayed(watchdog * 2);
      expect(errors, isEmpty);
      await svc.resume();
      await Future<void>.delayed(watchdog * 2);
      expect(errors, hasLength(1));
      expect(errors.single.messageAr, isNot(contains('Windows')));
      await svc.stop();
      await Future<void>.delayed(watchdog * 2);
      expect(errors, hasLength(1));
      await svc.dispose();
    });
  });

  test('Windows access-denied start error carries the privacy hint', () async {
    final svc = AudioCaptureService(platform: CapturePlatform.windows);
    fake.startError = Exception('MF error 0x80070005 (E_ACCESSDENIED)');
    await expectLater(
      svc.start(),
      throwsA(
        isA<AudioCaptureException>().having(
          (e) => e.messageAr,
          'messageAr',
          contains('الخصوصية'),
        ),
      ),
    );
    await svc.dispose();
  });

  test(
    'streams frames, levels and archives a WAV; stop returns duration',
    () async {
      final frames = <Float32List>[];
      final levels = <double>[];
      final states = <AudioCaptureState>[];
      service.frames.listen(frames.add);
      service.level.listen(levels.add);
      service.states.listen(states.add);

      final wavPath = '${dir.path}/m.wav';
      await service.start(archivePath: wavPath);
      expect(service.isRecording, isTrue);
      expect(service.archivePath, wavPath);
      expect(fake.lastConfig!.sampleRate, 16000);

      // 1 s of audio in odd-sized chunks.
      final pcm = tonePcm(16000, 1, 16000);
      var i = 0;
      while (i < pcm.length) {
        final n = math.min(3201, pcm.length - i);
        fake.data!.add(Uint8List.sublistView(pcm, i, i + n));
        i += n;
      }
      await pump();
      expect(service.elapsed, const Duration(seconds: 1));

      final duration = await service.stop();
      await pump();
      expect(duration, const Duration(seconds: 1));
      expect(service.state, AudioCaptureState.idle);
      expect(frames.fold<int>(0, (a, f) => a + f.length), 16000);
      expect(levels.where((l) => l > 0.5).length, greaterThanOrEqualTo(19));
      expect(levels.last, 0);
      expect(states, [
        AudioCaptureState.starting,
        AudioCaptureState.recording,
        AudioCaptureState.stopping,
        AudioCaptureState.idle,
      ]);

      final raw = await File(wavPath).readAsBytes();
      expect(Uint8List.sublistView(raw, kWavHeaderBytes), orderedEquals(pcm));
      final info = await readWavInfo(wavPath);
      expect(info.duration, const Duration(seconds: 1));
    },
  );

  test(
    'converts a platform-adjusted 48 kHz stereo stream to 16 kHz mono',
    () async {
      fake.announceOnStart = const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 48000,
        numChannels: 2,
      );
      final frames = <Float32List>[];
      service.frames.listen(frames.add);
      final wavPath = '${dir.path}/s.wav';
      await service.start(archivePath: wavPath);
      expect(service.deliveredFormat, (sampleRate: 48000, channels: 2));
      fake.data!.add(tonePcm(48000, 2, 48000));
      await pump();
      await service.stop();
      await pump();
      final total = frames.fold<int>(0, (a, f) => a + f.length);
      expect(total, closeTo(16000, 1));
      final info = await readWavInfo(wavPath);
      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.frameCount, total);
    },
  );

  test(
    'throws an Arabic AudioCaptureException when permission is denied',
    () async {
      fake.permission = false;
      await expectLater(
        service.start(),
        throwsA(
          isA<AudioCaptureException>().having(
            (e) => e.messageAr,
            'messageAr',
            contains('الميكروفون'),
          ),
        ),
      );
      expect(service.state, AudioCaptureState.idle);
    },
  );

  test('wraps platform start failures and cleans up', () async {
    fake.startError = Exception('device busy');
    final wavPath = '${dir.path}/fail.wav';
    await expectLater(
      service.start(archivePath: wavPath),
      throwsA(isA<AudioCaptureException>()),
    );
    expect(service.state, AudioCaptureState.idle);
    fake.startError = null;
    await service.start();
    expect(service.isRecording, isTrue);
  });

  test('rejects a second start while recording', () async {
    await service.start();
    expect(service.start(), throwsA(isA<AudioCaptureException>()));
  });

  test('pause and resume, including system-initiated pause', () async {
    await service.start();
    await service.pause();
    expect(service.isPaused, isTrue);
    expect(service.isRecording, isTrue);
    await service.resume();
    expect(service.state, AudioCaptureState.recording);

    fake.states.add(RecordState.pause); // e.g. phone call
    await pump();
    expect(service.isPaused, isTrue);
    fake.states.add(RecordState.record); // auto resume
    await pump();
    expect(service.state, AudioCaptureState.recording);

    await service.pause();
    fake.resumeError = const RecordResumeNoDeviceException();
    await expectLater(service.resume(), throwsA(isA<AudioCaptureException>()));
    expect(service.isPaused, isTrue);
  });

  test('platform-ended take is finalised and reported', () async {
    final errors = <AudioCaptureException>[];
    service.errors.listen(errors.add);
    final wavPath = '${dir.path}/p.wav';
    await service.start(archivePath: wavPath);
    fake.data!.add(tonePcm(16000, 1, 1600));
    await pump();
    // Finalisation closes the WAV file (real disk I/O), which can take longer
    // than a couple of event-loop turns on a busy CI runner: wait for idle.
    final idle = service.states
        .firstWhere((s) => s == AudioCaptureState.idle)
        .timeout(const Duration(seconds: 5));
    fake.stops.add(
      const RecordStop(reason: RecordStopReason.error, error: 'boom'),
    );
    await idle;
    expect(service.state, AudioCaptureState.idle);
    expect(errors, hasLength(1));
    expect(errors.single.messageAr, contains('توقّف التسجيل'));
    final info = await readWavInfo(wavPath);
    expect(info.frameCount, 1600);
  });

  test('device listing and selection', () async {
    const mic = InputDevice(id: '2', label: 'Desk mic');
    fake.devices = const [mic];
    expect(await service.listInputDevices(), [mic]);
    service.selectDevice(mic);
    expect(service.selectedDevice, mic);
    await service.start();
    expect(fake.lastConfig!.device, mic);
    expect(await service.hasPermission(), isTrue);
  });

  test('stop when idle is a no-op', () async {
    expect(await service.stop(), Duration.zero);
  });
}
