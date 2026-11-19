import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/system_audio/system_audio.dart';

import 'system_audio_fakes.dart';

Float32List _filled(int n, double v) => Float32List(n)..fillRange(0, n, v);

class _Env {
  _Env({String? setting = 'both', this.platform = CapturePlatform.windows})
    : _setting = setting {
    source = MixedSessionAudioSource(
      mic: mic,
      system: system,
      loadAudioSource: () async => _setting,
      platform: platform,
      clock: clock.call,
      // The pacing timer never fires on its own; tests pump explicitly.
      tick: const Duration(hours: 1),
    );
    source.frames.listen(frames.add);
    source.errors.listen((e) => errors.add(e.messageAr));
    source.states.listen(states.add);
    source.level.listen(levels.add);
  }

  String? _setting;
  final CapturePlatform platform;
  final mic = FakeSessionMic();
  final native = FakeSystemAudioPlatform();
  late final system = SystemAudioSource(platform: native);
  final clock = FakeClock();
  late final MixedSessionAudioSource source;
  final frames = <Float32List>[];
  final errors = <String>[];
  final states = <AudioCaptureState>[];
  final levels = <double>[];

  set setting(String? v) => _setting = v;

  int get emitted => frames.fold(0, (a, f) => a + f.length);

  /// Sends [n] 16 kHz mono system samples of value [v] (no resampling).
  void systemAudio(int n, double v) => native.emit(
    SystemAudioPacket(sampleRate: 16000, channels: 1, samples: _filled(n, v)),
  );
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('insato_f13_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('resolveSessionAudioMode', () {
    test('only Windows records system audio', () {
      for (final p in [
        CapturePlatform.android,
        CapturePlatform.ios,
        CapturePlatform.other,
      ]) {
        expect(resolveSessionAudioMode('system', p), SessionAudioMode.mic);
        expect(resolveSessionAudioMode('both', p), SessionAudioMode.mic);
      }
      const w = CapturePlatform.windows;
      expect(resolveSessionAudioMode('mic', w), SessionAudioMode.mic);
      expect(resolveSessionAudioMode('system', w), SessionAudioMode.system);
      expect(resolveSessionAudioMode('both', w), SessionAudioMode.both);
      expect(resolveSessionAudioMode(null, w), SessionAudioMode.both);
      expect(resolveSessionAudioMode('nonsense', w), SessionAudioMode.both);
    });
  });

  test('mic mode delegates everything, archive included', () async {
    final env = _Env(setting: AppSettingsData.audioSourceMic);
    final path = '${tmp.path}/a.wav';
    await env.source.start(archivePath: path);
    expect(env.source.mode, SessionAudioMode.mic);
    expect(env.mic.archivePath, path);
    expect(env.native.starts, 0);
    env.mic.emit(_filled(1600, 0.1));
    await flushEvents();
    expect(env.emitted, 1600);
    expect(env.levels, [0.25]);
    expect(env.states, [AudioCaptureState.recording]);
    expect(await env.source.stop(), const Duration(milliseconds: 100));
    await env.source.dispose();
  });

  test('off Windows the microphone is used whatever the setting', () async {
    final env = _Env(
      setting: AppSettingsData.audioSourceSystem,
      platform: CapturePlatform.android,
    );
    env.mic.permission = false;
    expect(await env.source.hasPermission(), isFalse);
    await env.source.start();
    expect(env.source.mode, SessionAudioMode.mic);
    expect(env.mic.started, isTrue);
    expect(env.native.starts, 0);
    await env.source.dispose();
  });

  test('both: mixes mic and system on the mic clock and archives', () async {
    final env = _Env();
    final path = '${tmp.path}/both.wav';
    await env.source.start(archivePath: path);
    expect(env.source.mode, SessionAudioMode.both);
    expect(env.mic.archivePath, isNull, reason: 'the mix is archived here');
    expect(env.native.starts, 1);

    env.systemAudio(800, 0.25);
    await flushEvents();
    env.mic.emit(_filled(1600, 0.25));
    await flushEvents();
    expect(env.emitted, 1600);
    final first = env.frames.single;
    // System audio for the first half, silence (zeros) after it.
    expect(first[0], closeTo(0.5, 1e-6));
    expect(first[799], closeTo(0.5, 1e-6));
    expect(first[800], closeTo(0.25, 1e-6));
    expect(env.levels, isNotEmpty);

    final d = await env.source.stop();
    expect(d, const Duration(milliseconds: 100));
    expect(env.native.stops, 1);
    final info = await readWavInfo(path);
    expect(info.sampleRate, 16000);
    expect(info.channels, 1);
    final archived = await readWavAsFloat32(path);
    expect(archived.length, 1600);
    expect(archived[0], closeTo(0.5, 1e-3));
    await env.source.dispose();
  });

  test('both: a system start failure warns and keeps the mic', () async {
    final env = _Env();
    env.native.startResult = false;
    await env.source.start();
    await flushEvents();
    expect(env.errors, [SystemAudioStrings.startFailedMicOnly]);
    env.mic.emit(_filled(160, 0.25));
    await flushEvents();
    expect(env.frames.single.every((s) => s == 0.25), isTrue);
    await env.source.stop();
    expect(env.native.stops, 0);
    await env.source.dispose();
  });

  test('both: pause stops system capture, resume restarts it', () async {
    final env = _Env();
    await env.source.start();
    await env.source.pause();
    expect(env.mic.pauses, 1);
    expect(env.native.stops, 1);
    await env.source.resume();
    expect(env.mic.resumes, 1);
    expect(env.native.starts, 2);
    await flushEvents();
    expect(env.states, contains(AudioCaptureState.paused));
    expect(env.levels, contains(0.0));
    await env.source.stop();
    await env.source.dispose();
  });

  test('both: system warnings are forwarded during the take', () async {
    final env = _Env();
    await env.source.start();
    env.native.emit(const SystemAudioStatus(SystemAudioStatusKind.restarted));
    await flushEvents();
    expect(env.errors, [SystemAudioStrings.deviceChanged]);
    await env.source.stop();
    await env.source.dispose();
  });

  test('system: paced by wall clock with silence filled', () async {
    final env = _Env(setting: AppSettingsData.audioSourceSystem);
    expect(await env.source.hasPermission(), isTrue);
    final path = '${tmp.path}/sys.wav';
    await env.source.start(archivePath: path);
    expect(env.source.mode, SessionAudioMode.system);
    expect(env.mic.started, isFalse);
    await flushEvents();
    expect(env.states, [
      AudioCaptureState.starting,
      AudioCaptureState.recording,
    ]);

    env.systemAudio(1600, 0.25);
    await flushEvents();
    env.clock.advance(const Duration(milliseconds: 250));
    env.source.pumpSystemAudio();
    await flushEvents();
    // 250 ms − 150 ms lag = 100 ms, all real audio.
    expect(env.emitted, 1600);
    expect(env.frames.single.every((s) => s == 0.25), isTrue);

    // A silent second: zeros keep the time line.
    env.clock.advance(const Duration(seconds: 1));
    env.source.pumpSystemAudio();
    await flushEvents();
    expect(env.emitted, 17600);
    expect(env.frames.last.every((s) => s == 0), isTrue);

    // Pause excludes time; stop flushes up to now.
    await env.source.pause();
    env.clock.advance(const Duration(seconds: 5));
    await env.source.resume();
    env.clock.advance(const Duration(milliseconds: 100));
    final d = await env.source.stop();
    await flushEvents();
    expect(d, const Duration(milliseconds: 1350));
    expect(env.emitted, 21600);
    expect(env.states.last, AudioCaptureState.idle);
    expect(env.states, contains(AudioCaptureState.paused));
    expect(env.native.starts, 2);
    expect(env.native.running, isFalse);
    expect(await readWavAsFloat32(path), hasLength(21600));
    await env.source.dispose();
  });

  test('system: a start failure is fatal and leaves the source idle', () async {
    final env = _Env(setting: AppSettingsData.audioSourceSystem);
    env.native.startResult = false;
    await expectLater(
      env.source.start(),
      throwsA(isA<AudioCaptureException>()),
    );
    await flushEvents();
    expect(env.states.last, AudioCaptureState.idle);
    await env.source.dispose();
  });

  test('the archive cannot be created: Arabic error', () async {
    final env = _Env(setting: AppSettingsData.audioSourceSystem);
    final blocker = File('${tmp.path}/file')..writeAsStringSync('x');
    await expectLater(
      env.source.start(archivePath: '${blocker.path}/x.wav'),
      throwsA(
        isA<AudioCaptureException>().having(
          (e) => e.messageAr,
          'messageAr',
          SystemAudioStrings.archiveFailed,
        ),
      ),
    );
    expect(env.native.starts, 0);
    await env.source.dispose();
  });

  test('the setting is read at each start', () async {
    final env = _Env(setting: AppSettingsData.audioSourceMic);
    await env.source.start();
    expect(env.source.mode, SessionAudioMode.mic);
    await env.source.stop();
    env.setting = AppSettingsData.audioSourceBoth;
    await env.source.start();
    expect(env.source.mode, SessionAudioMode.both);
    await env.source.dispose();
    expect(env.native.stops, 1, reason: 'dispose stops the running take');
  });
}
