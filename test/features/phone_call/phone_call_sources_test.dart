import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/diarization/channel_cue.dart';
import 'package:insato/features/phone_call/phone_call.dart';
import 'package:insato/features/system_audio/system_audio.dart';

import '../system_audio/system_audio_fakes.dart';
import 'call_signals.dart';

const int _frame = 1600; // 100 ms
const int _preroll = 2000; // > 80 ms jitter pre-roll + one frame margin

class _Env {
  _Env() {
    source = PhoneLinkSessionAudioSource(mic: mic, system: system);
    source.frames.listen(frames.add);
    source.localLevel.listen(local.add);
    source.remoteLevel.listen(remote.add);
  }

  final mic = FakeSessionMic();
  final native = FakeSystemAudioPlatform();
  late final system = SystemAudioSource(platform: native);
  late final PhoneLinkSessionAudioSource source;
  final frames = <Float32List>[];
  final local = <double>[];
  final remote = <double>[];

  void sys(Float32List s) => native.emit(
    SystemAudioPacket(sampleRate: 16000, channels: 1, samples: s),
  );

  /// Plays [micAudio] and [lineAudio] (same length) through the source,
  /// frame by frame, after priming the loopback jitter buffer.
  Future<void> play(Float32List micAudio, Float32List lineAudio) async {
    sys(Float32List(_preroll));
    await flushEvents();
    for (var at = 0; at + _frame <= micAudio.length; at += _frame) {
      sys(Float32List.sublistView(lineAudio, at, at + _frame));
      await flushEvents();
      mic.emit(Float32List.fromList(micAudio.sublist(at, at + _frame)));
      await flushEvents();
    }
  }

  int get emitted => frames.fold(0, (a, f) => a + f.length);

  Float32List get mixed {
    final out = Float32List(emitted);
    var at = 0;
    for (final f in frames) {
      out.setAll(at, f);
      at += f.length;
    }
    return out;
  }
}

void main() {
  group('PhoneLinkSessionAudioSource', () {
    test('fails clearly without loopback support', () async {
      final env = _Env()..native.supported = false;
      await expectLater(
        env.source.start(),
        throwsA(
          isA<AudioCaptureException>().having(
            (e) => e.messageAr,
            'message',
            PCS.loopbackUnavailable,
          ),
        ),
      );
      expect(env.mic.starts, 0);
    });

    test('a failing loopback stops the microphone again', () async {
      final env = _Env()..native.startResult = false;
      await expectLater(
        env.source.start(),
        throwsA(isA<AudioCaptureException>()),
      );
      expect(env.mic.stops, 1);
    });

    test('remote speech with speaker bleed → remote side, from the '
        'loopback channel, band-limited', () async {
      final env = _Env();
      await env.source.start();
      final line = speechLike(3000, seed: 11);
      // The microphone hears the speakers 30 ms after the line plays.
      final micAudio = add([echo(line, gain: 0.3, delayMs: 30), noise(3000)]);
      await env.play(micAudio, line);
      expect(env.emitted, 3000 * 16);
      expect(env.remote.any((l) => l > 0.2), isTrue);

      final seg = SpeechSegment(index: 0, startMs: 0, samples: env.mixed);
      final fused = env.source.fuseSegment(seg);
      expect(fused.channels?.partition, 'remote');
      expect(fused.channels?.snrDb.keys, {'local', 'remote'});
      expect(fused.segment.samples.length, seg.samples.length);
      expect(fused.segment.index, 0);
      // The loopback (delayed by the jitter buffer), band-limited: not the
      // mix, and nothing of the microphone.
      final expected = TelephoneAudioProfile.standard.bandLimit(
        Float32List(3000 * 16)
          ..setAll(_preroll, line.sublist(0, 3000 * 16 - _preroll)),
      );
      for (final i in [5000, 20000, 40000]) {
        expect(fused.segment.samples[i], closeTo(expected[i], 1e-6));
      }
      expect(env.source.stats.remoteSegments, 1);
      expect(env.source.stats.bleedSuppressed, 1);
      await env.source.stop();
    });

    test('local speech with a silent line → local side, microphone samples '
        'unchanged', () async {
      final env = _Env();
      await env.source.start();
      final micAudio = add([speechLike(2000, seed: 12), noise(2000)]);
      await env.play(micAudio, Float32List(2000 * 16));
      final seg = SpeechSegment(index: 3, startMs: 0, samples: env.mixed);
      final fused = env.source.fuseSegment(seg);
      expect(fused.channels?.partition, 'local');
      expect(fused.segment.samples, micAudio);
      expect(env.source.stats.localSegments, 1);
      expect(env.source.stats.bleedSuppressed, 0);
      expect(env.local.any((l) => l > 0.2), isTrue);
    });

    test('a segment older than the rings keeps the mix', () async {
      final env = _Env();
      await env.source.start();
      final seg = SpeechSegment(
        index: 0,
        startMs: -100000,
        samples: Float32List(1600),
      );
      final fused = env.source.fuseSegment(seg);
      expect(fused.channels, isNull);
      expect(identical(fused.segment, seg), isTrue);
      expect(env.source.stats.unattributed, 1);
    });

    test('the session sees the mix of both channels', () async {
      final env = _Env();
      await env.source.start();
      final micAudio = Float32List(1600 * 5)..fillRange(0, 8000, 0.1);
      final line = Float32List(1600 * 5)..fillRange(0, 8000, 0.2);
      await env.play(micAudio, line);
      final m = env.mixed;
      expect(m[0], closeTo(0.1, 1e-6)); // line still in the pre-roll
      expect(m[_preroll + 10], closeTo(0.3, 1e-6));
      expect(env.source.elapsed, const Duration(milliseconds: 500));
      expect(env.source.activeAudioSource, 'both');
      await env.source.stop();
      expect(env.native.stops, greaterThan(0));
    });
  });

  group('SpeakerphoneSessionAudioSource', () {
    test('delegates capture and attributes by bandwidth', () async {
      final mic = FakeSessionMic();
      final source = SpeakerphoneSessionAudioSource(mic: mic);
      await source.start(archivePath: 'x.wav');
      expect(mic.archivePath, 'x.wav');

      final wide = speechLike(1500, seed: 21);
      final local = source.fuseSegment(
        SpeechSegment(index: 0, startMs: 0, samples: wide),
      );
      expect(local.channels?.partition, 'local');
      expect(identical(local.segment.samples, wide), isTrue);

      final narrow = Float32List.fromList(
        const TelephoneBandLimiter().process(speechLike(1500, seed: 22)),
      );
      for (var k = 0; k < 2; k++) {
        for (final q in [0.5411961, 1.3065630]) {
          Biquad.lowPass(3400, q).processInPlace(narrow);
        }
      }
      final remote = source.fuseSegment(
        SpeechSegment(index: 1, startMs: 2000, samples: narrow),
      );
      expect(remote.channels?.partition, 'remote');
      expect(remote.segment.startMs, 2000);
      expect(identical(remote.segment.samples, narrow), isFalse);

      final unsure = source.fuseSegment(
        SpeechSegment(index: 2, startMs: 4000, samples: Float32List(16000)),
      );
      expect(unsure.channels, isNull);
      expect(source.stats.localSegments, 1);
      expect(source.stats.remoteSegments, 1);
      expect(source.stats.unattributed, 1);
      expect(source.callMode, PhoneCallMode.speakerphone);
      await source.stop();
      expect(mic.stops, 1);
      await source.dispose();
    });
  });

  group('PhoneCallLog', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('JSON round trip and derived views', () {
      const log = PhoneCallLog(
        mode: PhoneCallMode.phoneLink,
        sides: {'a': CallSide.local, 'b': CallSide.remote},
        bleedSuppressed: 2,
        overlaps: 1,
      );
      final back = PhoneCallLog.fromJson(log.toJson())!;
      expect(back.mode, PhoneCallMode.phoneLink);
      expect(back.sides, log.sides);
      expect(back.bleedSuppressed, 2);
      expect(back.overlaps, 1);
      expect(back.remoteSegmentIds, {'b'});
      expect(back.partitions['a']?.partition, 'local');
      expect(back.minutesHint.mode, 'phone_link');
      expect(back.minutesHint.remoteSegmentIds, {'b'});
      expect(PhoneCallLog.fromJson({'mode': 'nope'}), isNull);
      expect(PhoneCallLog.fromJson('x'), isNull);
    });

    test('callLogOf keeps the partitioned segments', () {
      final log = callLogOf(PhoneCallMode.speakerphone, {
        's1': ChannelProfile(const {}, partition: 'remote'),
        's2': ChannelProfile(const {'host': 3}),
      }, const CallLiveStats(unattributed: 4));
      expect(log.sides, {'s1': CallSide.remote});
      expect(log.unattributed, 4);
    });

    test('store: save, load, loaders and deletion with the meeting', () async {
      final store = PhoneCallLogStore(db);
      final meetings = MeetingRepository(db);
      final m = await meetings.create(
        title: 'مكالمة',
        createdAt: DateTime(2026),
      );
      expect(await store.load(m.id), isNull);
      await store.save(
        m.id,
        const PhoneCallLog(
          mode: PhoneCallMode.phoneLink,
          sides: {'r1': CallSide.remote, 'l1': CallSide.local},
        ),
      );
      expect((await store.partitions(m.id)).keys, {'r1', 'l1'});
      expect(await store.segmentVoiceDevices(m.id), {
        'r1': kTelephoneVoiceDeviceKey,
      });
      expect((await store.minutesHint(m.id))?.remoteSegmentIds, {'r1'});
      await meetings.delete(m.id);
      expect(await store.load(m.id), isNull);
    });

    test('a source with a store writes the log at the end of a take', () async {
      final store = PhoneCallLogStore(db);
      final mic = FakeSessionMic();
      final source = SpeakerphoneSessionAudioSource(mic: mic, logStore: store);
      await source.finishTake(
        meetingId: 'm9',
        segmentProfiles: {'x': ChannelProfile(const {}, partition: 'local')},
      );
      final log = await store.load('m9');
      expect(log?.mode, PhoneCallMode.speakerphone);
      expect(log?.sides, {'x': CallSide.local});
    });
  });
}
