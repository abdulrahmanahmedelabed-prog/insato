// Microphone capture: `package:record` PCM16 stream → 16 kHz mono Float32
// frames + 0..1 level meter + crash-safe WAV archive.
//
// Platform notes (verified against record 7.2 / record_android 2.3 /
// record_darwin 2.0 / record_windows 2.4 sources):
//
// * Android: `pcm16bits` streaming uses AudioRecord (advanced recorder only;
//   `AndroidRecordConfig.useLegacy` must stay false — the legacy MediaRecorder
//   path rejects pcm16bits). Effects (NS/AGC/AEC) are applied through
//   android.media.audiofx when the device offers them; otherwise they are
//   silently skipped. AudioRecord honours 16 kHz on practically all devices.
// * iOS: capture goes through AVAudioEngine and an AVAudioConverter to the
//   requested rate, so 16 kHz is delivered. Streaming may *reduce* the
//   channel count to what the input has and reports that via
//   `onConfigChanged`. `autoGain` or `echoCancel` switch on Apple's voice
//   processing unit (near-field call processing that attenuates distant
//   talkers), so both stay off for meeting capture; `noiseSuppress` is not
//   used on iOS. When the plugin manages the session it uses the
//   `playAndRecord` category with `IosRecordConfig.categoryOptions`.
// * Windows: Media Foundation source reader delivers PCM16 at the requested
//   rate; the channel count may be lowered to the device's and is reported
//   through `onConfigChanged`. NS/AGC/AEC flags are not applied on Windows.
//
// Whatever format the platform finally delivers is converted to 16 kHz mono
// here (see [PcmStreamConverter]), so downstream code can rely on
// [kSampleRate] mono.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../core/errors.dart';
import '../core/models.dart';
import 'pcm.dart';
import 'wav_writer.dart';

export 'package:record/record.dart' show InputDevice, InputDeviceType;

/// Platform family, used to pick capture options.
enum CapturePlatform {
  /// Android phones and tablets.
  android,

  /// iPhone / iPad.
  ios,

  /// Windows desktop.
  windows,

  /// Anything else (macOS, Linux, tests).
  other;

  /// The platform the app is currently running on.
  static CapturePlatform get current {
    if (Platform.isAndroid) return CapturePlatform.android;
    if (Platform.isIOS) return CapturePlatform.ios;
    if (Platform.isWindows) return CapturePlatform.windows;
    return CapturePlatform.other;
  }
}

/// Tunable capture behaviour. The defaults are chosen for recording a
/// meeting room for speech recognition and speaker identification.
class AudioCaptureOptions {
  /// Creates capture options.
  const AudioCaptureOptions({
    this.noiseSuppress = true,
    this.autoGainOnAndroid = true,
    this.androidAudioSource = AndroidAudioSource.voiceRecognition,
    this.androidManageBluetooth = false,
    this.iosCategoryOptions = const [
      IosAudioCategoryOption.defaultToSpeaker,
      IosAudioCategoryOption.allowBluetooth,
      IosAudioCategoryOption.allowBluetoothA2DP,
    ],
    this.iosAllowSystemSoundsDuringRecording = true,
    this.levelFloorDb = -60.0,
    this.wavPatchInterval = const Duration(seconds: 5),
  });

  /// Platform noise suppression where available (Android). Defaults to true.
  final bool noiseSuppress;

  /// Platform automatic gain control on Android (helps far-away speakers).
  /// Never enabled on iOS, where it would switch on call-style voice
  /// processing.
  final bool autoGainOnAndroid;

  /// Android audio source. `voiceRecognition` is tuned for ASR (flat
  /// response, no call processing) and is the recommended source for
  /// transcription.
  final AndroidAudioSource androidAudioSource;

  /// Whether Android should route capture to a Bluetooth SCO headset. Off by
  /// default: a headset mic only hears its wearer, not the room.
  final bool androidManageBluetooth;

  /// AVAudioSession category options for the `playAndRecord` session.
  final List<IosAudioCategoryOption> iosCategoryOptions;

  /// iOS: keep recording while an incoming call rings (the take is only
  /// interrupted if the call is answered).
  final bool iosAllowSystemSoundsDuringRecording;

  /// dBFS that maps to level 0 on the meter.
  final double levelFloorDb;

  /// How often the WAV archive header is patched / fsync'ed.
  final Duration wavPatchInterval;
}

/// Builds the `record` configuration for [platform].
///
/// Always requests PCM16 at [kSampleRate] mono; echo cancellation is off
/// (it would cancel the voices of people in the same room playing through
/// the device in hybrid meetings and degrade far-field capture).
RecordConfig buildRecordConfig({
  required CapturePlatform platform,
  AudioCaptureOptions options = const AudioCaptureOptions(),
  InputDevice? device,
}) {
  final isIos = platform == CapturePlatform.ios;
  return RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: kSampleRate,
    numChannels: 1,
    device: device,
    echoCancel: false,
    autoGain: platform == CapturePlatform.android && options.autoGainOnAndroid,
    noiseSuppress: !isIos && options.noiseSuppress,
    androidConfig: AndroidRecordConfig(
      useLegacy: false,
      manageBluetooth: options.androidManageBluetooth,
      audioSource: options.androidAudioSource,
    ),
    iosConfig: IosRecordConfig(
      categoryOptions: options.iosCategoryOptions,
      allowHapticsAndSystemSoundsDuringRecording:
          options.iosAllowSystemSoundsDuringRecording,
    ),
    // A phone call pauses the take and it resumes automatically afterwards.
    audioInterruption: AudioInterruptionMode.pauseResume,
    // A disconnected mic should not end a meeting: move to the default input.
    audioRouteChange: AudioRouteChangeMode.follow,
  );
}

/// Lifecycle state of an [AudioCaptureService].
enum AudioCaptureState {
  /// Not capturing.
  idle,

  /// [AudioCaptureService.start] in progress.
  starting,

  /// Capturing audio.
  recording,

  /// Paused by the user or the system (e.g. a phone call).
  paused,

  /// [AudioCaptureService.stop] in progress / finalising.
  stopping,
}

/// Captures the microphone as 16 kHz mono float frames.
///
/// One instance can run many sessions sequentially. [frames], [level],
/// [states] and [errors] are broadcast streams that live as long as the
/// service, so listeners may subscribe once before the first [start].
class AudioCaptureService {
  /// Creates the service.
  ///
  /// [recorderFactory] and [platform] are injectable for tests.
  AudioCaptureService({
    this.options = const AudioCaptureOptions(),
    AudioRecorder Function()? recorderFactory,
    CapturePlatform? platform,
  }) : _recorderFactory = recorderFactory ?? AudioRecorder.new,
       _platform = platform ?? CapturePlatform.current;

  /// Capture options used for every session.
  final AudioCaptureOptions options;

  final AudioRecorder Function() _recorderFactory;
  final CapturePlatform _platform;

  /// Samples per level-meter update (50 ms → ~20 Hz).
  static const int _levelWindow = kSampleRate ~/ 20;

  final _framesCtrl = StreamController<Float32List>.broadcast();
  final _levelCtrl = StreamController<double>.broadcast();
  final _statesCtrl = StreamController<AudioCaptureState>.broadcast();
  final _errorsCtrl = StreamController<AudioCaptureException>.broadcast();

  AudioRecorder? _recorder;
  StreamSubscription<RecordState>? _recorderStateSub;
  StreamSubscription<RecordStop>? _recorderStopSub;
  StreamSubscription<Uint8List>? _dataSub;

  AudioCaptureState _state = AudioCaptureState.idle;
  InputDevice? _selectedDevice;
  String? _archivePath;
  WavWriter? _wav;
  bool _wavFailed = false;

  int _inputRate = kSampleRate;
  int _inputChannels = 1;
  PcmStreamConverter _converter = PcmStreamConverter(
    inputSampleRate: kSampleRate,
    inputChannels: 1,
  );
  final Pcm16Decoder _aligner = Pcm16Decoder();

  int _samplesEmitted = 0;
  double _levelSumSq = 0;
  int _levelCount = 0;

  Completer<void>? _finalizing;
  bool _disposed = false;

  /// 16 kHz mono float frames, in capture order. Chunk sizes vary by
  /// platform (typically 20–200 ms).
  Stream<Float32List> get frames => _framesCtrl.stream;

  /// Input level in 0..1 (dBFS mapped linearly from
  /// [AudioCaptureOptions.levelFloorDb] to 0 dB), about 20 updates per
  /// second while recording; 0 is emitted on pause/stop.
  Stream<double> get level => _levelCtrl.stream;

  /// State transitions.
  Stream<AudioCaptureState> get states => _statesCtrl.stream;

  /// Non-fatal and platform-initiated failures (e.g. the system ended the
  /// take, archive write failed). Fatal start errors are thrown by [start].
  Stream<AudioCaptureException> get errors => _errorsCtrl.stream;

  /// Current state.
  AudioCaptureState get state => _state;

  /// True while a session is active (recording or paused).
  bool get isRecording =>
      _state == AudioCaptureState.recording ||
      _state == AudioCaptureState.paused;

  /// True while the session is paused.
  bool get isPaused => _state == AudioCaptureState.paused;

  /// Audio time captured in the current (or last) session. Derived from the
  /// number of 16 kHz samples delivered, so it excludes pauses and matches
  /// segment timestamps exactly.
  Duration get elapsed => Duration(
    microseconds: _samplesEmitted * Duration.microsecondsPerSecond ~/ kSampleRate,
  );

  /// Path of the WAV archive of the current (or last) session, if any.
  String? get archivePath => _archivePath;

  /// The input device used for the next session (null = system default).
  InputDevice? get selectedDevice => _selectedDevice;

  /// The sample rate / channel count the platform actually delivers in the
  /// current session (before conversion to 16 kHz mono).
  ({int sampleRate, int channels}) get deliveredFormat =>
      (sampleRate: _inputRate, channels: _inputChannels);

  AudioRecorder get _rec {
    _checkNotDisposed();
    final existing = _recorder;
    if (existing != null) return existing;
    final r = _recorderFactory();
    _recorder = r;
    _recorderStateSub = r.onStateChanged().listen(
      _onRecorderState,
      onError: (Object _) {},
    );
    _recorderStopSub = r.onStopped().listen(
      _onRecorderStopped,
      onError: (Object _) {},
    );
    return r;
  }

  /// Checks microphone permission, asking the user when [request] is true
  /// and permission was not decided yet.
  Future<bool> hasPermission({bool request = true}) async {
    try {
      return await _rec.hasPermission(request: request);
    } catch (e) {
      throw AudioCaptureException(
        'تعذّر التحقق من إذن استخدام الميكروفون.',
        debugDetails: '$e',
        cause: e,
      );
    }
  }

  /// Lists the available input devices (useful on Windows with several
  /// microphones). Requires microphone permission on some platforms.
  Future<List<InputDevice>> listInputDevices() async {
    try {
      return await _rec.listInputDevices();
    } catch (e) {
      throw AudioCaptureException(
        'تعذّر الحصول على قائمة أجهزة الميكروفون.',
        debugDetails: '$e',
        cause: e,
      );
    }
  }

  /// Selects the input device for the next [start] (null = system default).
  /// Does not affect a session that is already running.
  void selectDevice(InputDevice? device) => _selectedDevice = device;

  /// Starts capturing.
  ///
  /// When [archivePath] is given, the 16 kHz mono audio is also written to a
  /// crash-safe WAV file there.
  ///
  /// Throws [AudioCaptureException] when permission is denied, the device is
  /// unavailable, or the archive cannot be created.
  Future<void> start({String? archivePath}) async {
    _checkNotDisposed();
    if (_state != AudioCaptureState.idle) {
      throw const AudioCaptureException('التسجيل قيد التشغيل بالفعل.');
    }
    _setState(AudioCaptureState.starting);
    try {
      final rec = _rec;
      final bool granted;
      try {
        granted = await rec.hasPermission();
      } catch (e) {
        throw AudioCaptureException(
          'تعذّر التحقق من إذن استخدام الميكروفون.',
          debugDetails: '$e',
          cause: e,
        );
      }
      if (!granted) {
        throw const AudioCaptureException(
          'لم يُمنح التطبيق إذن استخدام الميكروفون. يُرجى السماح بالوصول إلى '
          'الميكروفون من إعدادات الجهاز ثم المحاولة مجددًا.',
        );
      }

      bool supported;
      try {
        supported = await rec.isEncoderSupported(AudioEncoder.pcm16bits);
      } catch (_) {
        // Let startStream report the real problem.
        supported = true;
      }
      if (!supported) {
        throw const AudioCaptureException(
          'هذا الجهاز لا يدعم التقاط الصوت بالصيغة المطلوبة.',
          debugDetails: 'pcm16bits encoder not supported',
        );
      }

      _resetSession();
      if (archivePath != null) {
        try {
          _wav = await WavWriter.open(
            archivePath,
            sampleRate: kSampleRate,
            channels: 1,
            patchInterval: options.wavPatchInterval,
          );
          _archivePath = archivePath;
        } catch (e) {
          throw AudioCaptureException(
            'تعذّر إنشاء ملف حفظ التسجيل الصوتي. تحقّق من مساحة التخزين.',
            debugDetails: '$e',
            cause: e,
          );
        }
      }

      final config = buildRecordConfig(
        platform: _platform,
        options: options,
        device: _selectedDevice,
      );
      _configure(config.sampleRate, config.numChannels);
      await rec.setOnConfigChanged(_onConfigChanged);

      final Stream<Uint8List> stream;
      try {
        stream = await rec.startStream(config);
      } catch (e) {
        throw AudioCaptureException(
          'تعذّر بدء التسجيل من الميكروفون. تأكّد من توصيل الميكروفون وعدم '
          'استخدامه من تطبيق آخر.',
          debugDetails: '$e',
          cause: e,
        );
      }
      _finalizing = null;
      _dataSub = stream.listen(
        _onData,
        onError: _onStreamError,
        onDone: () => unawaited(_finalize()),
      );
      _setState(AudioCaptureState.recording);
    } catch (e) {
      await _abortStart();
      if (e is AudioCaptureException) rethrow;
      throw AudioCaptureException(
        'تعذّر بدء التسجيل.',
        debugDetails: '$e',
        cause: e,
      );
    }
  }

  /// Pauses capture. No-op unless recording.
  Future<void> pause() async {
    if (_state != AudioCaptureState.recording) return;
    try {
      await _rec.pause();
    } catch (e) {
      throw AudioCaptureException(
        'تعذّر إيقاف التسجيل مؤقتًا.',
        debugDetails: '$e',
        cause: e,
      );
    }
    _enterPaused();
  }

  /// Resumes capture after [pause]. No-op unless paused.
  Future<void> resume() async {
    if (_state != AudioCaptureState.paused) return;
    try {
      await _rec.resume();
    } on RecordResumeNoDeviceException catch (e) {
      throw AudioCaptureException(
        'لا يوجد ميكروفون متاح لاستئناف التسجيل. يُرجى توصيل ميكروفون ثم '
        'المحاولة مجددًا.',
        debugDetails: e.message,
        cause: e,
      );
    } on PlatformException catch (e) {
      if (e.code == noInputDeviceErrorCode) {
        throw AudioCaptureException(
          'لا يوجد ميكروفون متاح لاستئناف التسجيل. يُرجى توصيل ميكروفون ثم '
          'المحاولة مجددًا.',
          debugDetails: '$e',
          cause: e,
        );
      }
      throw AudioCaptureException(
        'تعذّر استئناف التسجيل.',
        debugDetails: '$e',
        cause: e,
      );
    } catch (e) {
      throw AudioCaptureException(
        'تعذّر استئناف التسجيل.',
        debugDetails: '$e',
        cause: e,
      );
    }
    if (_state == AudioCaptureState.paused) {
      _setState(AudioCaptureState.recording);
    }
  }

  /// Stops capture, flushes the remaining frames, finalises the WAV archive
  /// and returns the captured audio duration. Safe to call when idle.
  Future<Duration> stop() async {
    if (_state == AudioCaptureState.idle) return elapsed;
    if (_state == AudioCaptureState.starting) {
      throw const AudioCaptureException('لم يبدأ التسجيل بعد.');
    }
    final pending = _finalizing;
    if (_state == AudioCaptureState.stopping && pending != null) {
      await pending.future;
      return elapsed;
    }
    _setState(AudioCaptureState.stopping);
    Object? stopError;
    try {
      await _rec.stop();
    } catch (e) {
      stopError = e;
    }
    await _finalize();
    if (stopError != null) {
      _errorsCtrl.add(
        AudioCaptureException(
          'حدث خطأ أثناء إيقاف التسجيل، وقد حُفظ ما سُجّل حتى الآن.',
          debugDetails: '$stopError',
          cause: stopError,
        ),
      );
    }
    return elapsed;
  }

  /// Stops any session and releases the recorder and streams.
  Future<void> dispose() async {
    if (_disposed) return;
    if (isRecording) {
      try {
        await stop();
      } catch (_) {
        // Best effort while tearing down.
      }
    }
    _disposed = true;
    await _dataSub?.cancel();
    await _recorderStateSub?.cancel();
    await _recorderStopSub?.cancel();
    final rec = _recorder;
    _recorder = null;
    if (rec != null) {
      try {
        await rec.dispose();
      } catch (_) {
        // Platform side may already be gone.
      }
    }
    await _wav?.close().catchError((Object _) {});
    await _framesCtrl.close();
    await _levelCtrl.close();
    await _statesCtrl.close();
    await _errorsCtrl.close();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  void _checkNotDisposed() {
    if (_disposed) throw StateError('AudioCaptureService has been disposed');
  }

  void _setState(AudioCaptureState s) {
    if (_state == s) return;
    _state = s;
    if (!_statesCtrl.isClosed) _statesCtrl.add(s);
  }

  void _resetSession() {
    _samplesEmitted = 0;
    _levelSumSq = 0;
    _levelCount = 0;
    _archivePath = null;
    _wav = null;
    _wavFailed = false;
    _aligner.reset();
  }

  void _configure(int sampleRate, int channels) {
    _inputRate = sampleRate;
    _inputChannels = channels;
    _converter = PcmStreamConverter(
      inputSampleRate: sampleRate,
      inputChannels: channels,
    );
    _aligner.reset();
  }

  void _onConfigChanged(RecordConfig cfg) {
    final rate = cfg.sampleRate;
    final channels = cfg.numChannels;
    if (rate <= 0 || channels <= 0) return;
    if (rate == _inputRate && channels == _inputChannels) return;
    // Release what the previous converter still holds, then switch.
    if (isRecording) _emit(_converter.flush(), null);
    _configure(rate, channels);
  }

  void _onData(Uint8List bytes) {
    if (bytes.isEmpty) return;
    if (_converter.isIdentity) {
      final aligned = _aligner.align(bytes);
      if (aligned.isEmpty) return;
      _emit(pcm16LeBytesToFloat32(aligned), aligned);
    } else {
      _emit(_converter.convert(bytes), null);
    }
  }

  /// Delivers [samples] downstream; [pcm] are the same samples as PCM16 when
  /// already available (avoids a lossy round trip for the archive).
  void _emit(Float32List samples, Uint8List? pcm) {
    if (samples.isEmpty) return;
    _samplesEmitted += samples.length;
    _archive(samples, pcm);
    if (!_framesCtrl.isClosed && _framesCtrl.hasListener) {
      _framesCtrl.add(samples);
    }
    _updateLevel(samples);
  }

  void _archive(Float32List samples, Uint8List? pcm) {
    final wav = _wav;
    if (wav == null || _wavFailed) return;
    final f = pcm != null ? wav.appendPcm16(pcm) : wav.appendFloat32(samples);
    f.catchError((Object e) {
      if (_wavFailed) return;
      _wavFailed = true;
      if (!_errorsCtrl.isClosed) {
        _errorsCtrl.add(
          AudioCaptureException(
            'تعذّر حفظ الصوت على الجهاز (قد تكون مساحة التخزين ممتلئة). '
            'يستمر النسخ المباشر دون حفظ الصوت.',
            debugDetails: '$e',
            cause: e,
          ),
        );
      }
    });
  }

  void _updateLevel(Float32List samples) {
    var i = 0;
    while (i < samples.length) {
      final take = math.min(_levelWindow - _levelCount, samples.length - i);
      for (var k = 0; k < take; k++) {
        final s = samples[i + k];
        _levelSumSq += s * s;
      }
      i += take;
      _levelCount += take;
      if (_levelCount >= _levelWindow) {
        final value = dbfsToMeterLevel(
          rmsToDbfs(math.sqrt(_levelSumSq / _levelCount)),
          floorDb: options.levelFloorDb,
        );
        _levelSumSq = 0;
        _levelCount = 0;
        if (!_levelCtrl.isClosed) _levelCtrl.add(value);
      }
    }
  }

  void _emitZeroLevel() {
    _levelSumSq = 0;
    _levelCount = 0;
    if (!_levelCtrl.isClosed) _levelCtrl.add(0);
  }

  void _enterPaused() {
    if (_state != AudioCaptureState.recording) return;
    _setState(AudioCaptureState.paused);
    _emitZeroLevel();
    // A pause is a natural checkpoint: make the archive consistent on disk.
    final wav = _wav;
    if (wav != null && !_wavFailed) {
      wav.flush().catchError((Object _) {});
    }
  }

  void _onRecorderState(RecordState s) {
    switch (s) {
      case RecordState.pause:
        // System-initiated pause (phone call, route change) or our own.
        _enterPaused();
      case RecordState.record:
        if (_state == AudioCaptureState.paused) {
          _setState(AudioCaptureState.recording);
        }
      case RecordState.stop:
        // Handled through the stream's done event / onStopped.
        break;
    }
  }

  void _onRecorderStopped(RecordStop stop) {
    if (stop.reason == RecordStopReason.stop) return;
    if (!isRecording) return;
    final message = switch (stop.reason) {
      RecordStopReason.interruption =>
        'توقّف التسجيل بسبب مقاطعة من النظام (مثل مكالمة هاتفية). '
            'حُفظ ما سُجّل حتى الآن.',
      RecordStopReason.routeChange =>
        'توقّف التسجيل لأن جهاز الإدخال الصوتي فُصل. حُفظ ما سُجّل حتى الآن.',
      _ =>
        'توقّف التسجيل بسبب خطأ في الميكروفون. حُفظ ما سُجّل حتى الآن.',
    };
    _errorsCtrl.add(
      AudioCaptureException(
        message,
        debugDetails: 'record stopped: ${stop.reason.name} ${stop.error ?? ''}',
      ),
    );
    unawaited(_finalize());
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (_errorsCtrl.isClosed) return;
    _errorsCtrl.add(
      AudioCaptureException(
        'حدث خطأ أثناء التقاط الصوت من الميكروفون.',
        debugDetails: '$error',
        cause: error,
      ),
    );
  }

  /// Ends the current session exactly once: flushes the converter, closes
  /// the archive and returns to idle.
  Future<void> _finalize() {
    final existing = _finalizing;
    if (existing != null) return existing.future;
    final done = Completer<void>();
    _finalizing = done;
    () async {
      try {
        if (_state != AudioCaptureState.stopping) {
          _setState(AudioCaptureState.stopping);
          // The platform ended the take on its own; make sure the recorder
          // is released too.
          try {
            await _rec.stop();
          } catch (_) {
            // Already stopped.
          }
        }
        await _dataSub?.cancel();
        _dataSub = null;
        _emit(_converter.flush(), null);
        final wav = _wav;
        _wav = null;
        if (wav != null) {
          try {
            await wav.close();
          } catch (e) {
            if (!_wavFailed && !_errorsCtrl.isClosed) {
              _errorsCtrl.add(
                AudioCaptureException(
                  'تعذّر إكمال حفظ ملف التسجيل الصوتي.',
                  debugDetails: '$e',
                  cause: e,
                ),
              );
            }
          }
        }
        try {
          await _recorder?.setOnConfigChanged(null);
        } catch (_) {
          // Not critical.
        }
        _emitZeroLevel();
      } finally {
        _setState(AudioCaptureState.idle);
        done.complete();
      }
    }();
    return done.future;
  }

  Future<void> _abortStart() async {
    final wav = _wav;
    _wav = null;
    if (wav != null) {
      await wav.close().catchError((Object _) {});
    }
    await _dataSub?.cancel();
    _dataSub = null;
    _setState(AudioCaptureState.idle);
  }
}

/// App-wide [AudioCaptureService]. Disposed with the provider container.
final audioCaptureServiceProvider = Provider<AudioCaptureService>((ref) {
  final service = AudioCaptureService();
  ref.onDispose(service.dispose);
  return service;
});
