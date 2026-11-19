import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/pcm.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/repositories_v11.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/codes/reversed_speech.dart';
import 'package:insato/features/codes/reversed_speech_logic.dart';
import 'package:insato/features/codes/strings.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/providers.dart' show AppPaths;

import '../../session/fakes.dart';

/// Hidden message recognised when (and only when) the audio is reversed.
const String kHidden = 'رسالة سرية';

/// ASR fake: a falling ramp (a reversed rising ramp) decodes to [kHidden];
/// anything else is voiced audio without text. Throws for [failIndices].
class RampAsr implements AsrEngine {
  RampAsr({this.failIndices = const {}});

  final Set<int> failIndices;
  final List<int> calls = [];
  bool disposed = false;

  @override
  String get name => 'ramp-asr';

  @override
  Future<void> initialize() async {}

  @override
  Future<AsrResult> transcribe(
    SpeechSegment segment, {
    String? languageHint,
  }) async {
    calls.add(segment.index);
    if (failIndices.contains(segment.index)) {
      throw const AsrException('فشل', debugDetails: 'fake');
    }
    final s = segment.samples;
    if (s.length > 10 && s.first > s.last + 0.05) {
      return const AsrResult(text: kHidden, language: 'ar', confidence: 0.9);
    }
    return const AsrResult(text: '', rejection: AsrRejection.noText);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class RampEnginesFactory implements SessionEnginesFactory {
  RampEnginesFactory(this.asr);

  final RampAsr asr;
  InsatoException? notReady;
  int created = 0;
  bool disposed = false;
  SessionEngineRequest? lastRequest;

  @override
  Future<void> ensureReady(SessionEngineRequest request) async {
    final e = notReady;
    if (e != null) throw e;
  }

  @override
  Future<SessionEngines> create(SessionEngineRequest request) async {
    lastRequest = request;
    created++;
    return SessionEngines(
      segmenter: FakeSegmenter(),
      processor: InlineSegmentProcessor(asr: asr, embedder: FakeEmbedder()),
      description: 'ramp',
      onDispose: () async => disposed = true,
    );
  }
}

/// 16-bit PCM WAV bytes of mono [samples] at [rate] with [channels]
/// identical channels.
Uint8List wav16(Float32List samples, {int rate = 16000, int channels = 1}) {
  final inter = Float32List(samples.length * channels);
  for (var i = 0; i < samples.length; i++) {
    for (var c = 0; c < channels; c++) {
      inter[i * channels + c] = samples[i];
    }
  }
  final data = float32ToPcm16Bytes(inter);
  return Uint8List.fromList([
    ...buildWavHeader(
      sampleRate: rate,
      channels: channels,
      dataBytes: data.length,
    ),
    ...data,
  ]);
}

/// 32-bit integer PCM WAV (read through the streaming fallback).
Uint8List wav32(Float32List samples, {int rate = 16000}) {
  final data = ByteData(samples.length * 4);
  for (var i = 0; i < samples.length; i++) {
    data.setInt32(i * 4, (samples[i] * 2147483647).round(), Endian.little);
  }
  return Uint8List.fromList([
    ...buildWavHeader(
      sampleRate: rate,
      channels: 1,
      dataBytes: samples.length * 4,
      bitsPerSample: 32,
    ),
    ...data.buffer.asUint8List(),
  ]);
}

/// A rising ramp signal: sample i of [ms] at 16 kHz.
Float32List ramp(int ms, {double from = 0.1, double to = 0.5}) {
  final n = ms * 16;
  return Float32List.fromList([
    for (var i = 0; i < n; i++) from + (to - from) * i / (n - 1),
  ]);
}

Float32List flat(int ms, double v) =>
    Float32List(ms * 16)..fillRange(0, ms * 16, v);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('insato_codes_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('readWavClips', () {
    // 0..1 s: 0.1, 1..2 s: rising ramp, 2..3 s: 0.3.
    final signal = Float32List.fromList([
      ...flat(1000, 0.1),
      ...ramp(1000),
      ...flat(1000, 0.3),
    ]);

    test('16 kHz mono: seeks to each range', () async {
      final f = File('${tmp.path}/a.wav')..writeAsBytesSync(wav16(signal));
      final clips = await readWavClips(f.path, const [
        (1000, 2000),
        (2500, 2600),
        (2900, 4000),
        (5000, 6000),
      ]);
      expect(clips[0].length, 16000);
      expect(clips[0].first, closeTo(0.1, 1e-3));
      expect(clips[0].last, closeTo(0.5, 1e-3));
      expect(clips[1].length, 1600);
      expect(clips[1].every((v) => (v - 0.3).abs() < 1e-3), isTrue);
      expect(clips[2].length, 1600, reason: 'clamped to the file');
      expect(clips[3], isEmpty);
      expect(await readWavClips(f.path, const []), isEmpty);
    });

    test('48 kHz stereo: down-mixed and resampled to 16 kHz', () async {
      final hi = resampleLinear(signal, 16000, 48000);
      final f = File('${tmp.path}/b.wav')
        ..writeAsBytesSync(wav16(hi, rate: 48000, channels: 2));
      final clips = await readWavClips(f.path, const [(2200, 2800)]);
      expect(clips.single.length, closeTo(9600, 2));
      final mid = clips.single[clips.single.length ~/ 2];
      expect(mid, closeTo(0.3, 0.01));
    });

    test('other formats: one streaming pass', () async {
      final f = File('${tmp.path}/c.wav')..writeAsBytesSync(wav32(signal));
      final clips = await readWavClips(f.path, const [
        (1000, 2000),
        (0, 500),
      ]);
      expect(clips[0].length, 16000);
      expect(clips[0].first, closeTo(0.1, 1e-3));
      expect(clips[0].last, closeTo(0.5, 1e-3));
      expect(clips[1].length, 8000);
      expect(clips[1].first, closeTo(0.1, 1e-3));
    });

    test('malformed file', () async {
      final f = File('${tmp.path}/d.wav')..writeAsStringSync('not a wav');
      expect(
        () => readWavClips(f.path, const [(0, 100)]),
        throwsFormatException,
      );
    });
  });

  group('ReversedSpeechReprocessor', () {
    late AppDatabase db;
    late MeetingRepository meetings;
    late SegmentRepository segments;
    late SpeakerRepository speakers;
    late CodeFindingRepository findings;
    late RampAsr asr;
    late RampEnginesFactory factory;
    late AppPaths paths;
    late String meetingId;
    late String speakerId;
    var active = false;

    ReversedSpeechReprocessor service({int batch = 8}) =>
        ReversedSpeechReprocessor(
          meetings: meetings,
          segments: segments,
          speakers: speakers,
          findings: findings,
          enginesFactory: factory,
          loadSettings: () async =>
              const AppSettingsData(languageHint: 'ar'),
          resolveRecording: paths.resolveRecording,
          isMeetingActive: (id) => active && id == meetingId,
          clock: () => DateTime.utc(2026, 11, 19),
          batchSize: batch,
        );

    TranscriptSegment s(
      int index,
      int startMs,
      int durMs, {
      SegmentKind kind = SegmentKind.unintelligible,
      String text = '',
    }) => TranscriptSegment(
      id: '',
      meetingId: meetingId,
      index: index,
      startMs: startMs,
      endMs: startMs + durMs,
      text: text,
      kind: kind,
      speakerId: speakerId,
    );

    setUp(() async {
      active = false;
      db = memoryDb();
      meetings = MeetingRepository(db);
      segments = SegmentRepository(db);
      speakers = SpeakerRepository(db);
      findings = CodeFindingRepository(db);
      asr = RampAsr(failIndices: {5});
      factory = RampEnginesFactory(asr);
      paths = AppPaths(
        documentsDir: () async => tmp,
        supportDir: () async => tmp,
        isWindows: false,
      );
      final m = await meetings.create(
        title: 'اجتماع',
        status: MeetingStatus.ready,
      );
      meetingId = m.id;
      speakerId = (await speakers.create(name: 'سارة')).id;
      // Timeline (1 s blocks): 0 speech, 1 ramp (#1), 2 ramp (#2),
      // 3 flat (#3), 4.0–4.2 ramp (#4, too short), 5 ramp (#5, fails).
      final audio = Float32List.fromList([
        ...flat(1000, 0.2),
        ...ramp(1000),
        ...ramp(1000),
        ...flat(1000, 0.25),
        ...ramp(200),
        ...flat(800, 0),
        ...ramp(1000),
      ]);
      final dir = await paths.recordingsDir();
      File('$dir/$meetingId.wav').writeAsBytesSync(wav16(audio));
      await meetings.setAudioPath(meetingId, '$meetingId.wav');
      await segments.insertAll([
        s(0, 0, 1000, kind: SegmentKind.speech, text: 'مرحبا'),
        s(1, 1000, 1000),
        s(2, 2000, 1000, text: 'تخمين'),
        s(3, 3000, 1000),
        s(4, 4000, 200),
        s(5, 5000, 1000),
      ]);
      await findings.replaceForMeeting(meetingId, [
        CodeFinding(
          id: 0,
          meetingId: meetingId,
          kind: CodeFindingKind.jargon,
          payload: const JargonItem(
            term: 'النسر',
            inferredMeaning: 'مشروع',
            confidence: HypothesisConfidence.low,
          ).toJson(),
          createdAt: DateTime(2026),
        ),
        CodeFinding(
          id: 0,
          meetingId: meetingId,
          kind: CodeFindingKind.speechCoded,
          speakerId: speakerId,
          segmentIds: const [1, 3],
          payload: const CodedSpeechItem(
            speaker: 'سارة',
            character: CodedSpeechCharacter.inventedLanguage,
            description: 'وصف',
            evidence: [1, 3],
          ).toJson(),
          createdAt: DateTime(2026),
        ),
      ]);
    });

    tearDown(() => db.close());

    test('enriches findings, creates app findings, keeps the transcript',
        () async {
      final progress = <ReversedSpeechProgress>[];
      final report = await service(batch: 2).run(
        meetingId,
        onProgress: progress.add,
      );
      expect(report.analysed, 2 + 1, reason: '#1, #2, #3 (#5 failed)');
      expect(report.found, 2);
      expect(report.failed, 1);
      expect(report.cancelled, isFalse);
      // The short segment is never sent to the engine.
      expect(asr.calls, [1, 2, 3, 5]);
      expect(factory.lastRequest!.languageHint, 'ar');
      expect(factory.disposed, isTrue);
      expect(asr.disposed, isTrue);
      expect(progress.first.statusAr, KS.reverseLoading);
      expect(progress.last.statusAr, KS.reverseSaving);
      expect(progress.last.fraction, 1);

      final stored = await findings.getForMeeting(meetingId);
      expect(stored.map((f) => f.kind), [
        CodeFindingKind.jargon,
        CodeFindingKind.speechCoded,
        CodeFindingKind.speechCoded,
      ]);
      expect(stored[0].payload['term'], 'النسر');
      final enriched = stored[1].payload;
      expect(enriched['description'], 'وصف');
      expect(enriched['character'], 'invented_language');
      expect(readReversedResults(enriched).single.segment, 1);
      expect(readReversedResults(enriched).single.text, kHidden);
      expect(readReversedChecked(enriched), {1, 3});
      final app = stored[2];
      expect(app.payload[kFindingOriginKey], kOriginApp);
      expect(app.segmentIds, [2]);
      expect(app.speakerId, speakerId);
      expect(app.payload['speaker'], 'سارة');
      expect(app.payload['description'], KS.appFindingDescription(1000));
      expect(readReversedResults(app.payload).single.confidence, 0.9);

      // The transcript is never rewritten.
      final after = await segments.getForMeeting(meetingId);
      expect(after.where((x) => x.isUnintelligible).map((x) => x.index), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(after.firstWhere((x) => x.index == 2).text, 'تخمين');
      expect(after.firstWhere((x) => x.index == 1).text, '');
    });

    test('second run only updates payloads in place', () async {
      await service().run(meetingId);
      final ids = (await findings.getForMeeting(meetingId)).map((f) => f.id);
      final report = await service().run(meetingId);
      expect(report.found, 2);
      final again = await findings.getForMeeting(meetingId);
      expect(again.map((f) => f.id), ids);
      expect(again.length, 3);
      expect(readReversedResults(again[1].payload).length, 1);
    });

    test('cancel stops after the current segment and saves', () async {
      var n = 0;
      final report = await service().run(
        meetingId,
        isCancelled: () => n++ >= 1,
      );
      expect(report.cancelled, isTrue);
      expect(report.analysed, 1);
      expect(asr.calls, [1]);
      final stored = await findings.getForMeeting(meetingId);
      expect(stored.length, 2);
      expect(readReversedChecked(stored[1].payload), {1});
    });

    test('refuses without audio, while recording, or engines not ready',
        () async {
      active = true;
      await expectLater(
        service().run(meetingId),
        throwsA(
          isA<InsatoException>().having(
            (e) => e.messageAr,
            'messageAr',
            KS.reverseRecording,
          ),
        ),
      );
      active = false;
      factory.notReady = const ModelException('نماذج ناقصة');
      await expectLater(
        service().run(meetingId),
        throwsA(isA<ModelException>()),
      );
      factory.notReady = null;
      await meetings.setAudioPath(meetingId, null);
      expect(await service().audioFileOf(meetingId), isNull);
      await expectLater(
        service().run(meetingId),
        throwsA(
          isA<InsatoException>().having(
            (e) => e.messageAr,
            'messageAr',
            KS.reverseNoAudio,
          ),
        ),
      );
      await expectLater(
        service().run('missing'),
        throwsA(isA<InsatoException>()),
      );
      expect(factory.created, 0);
    });

    test('a meeting without unintelligible segments does nothing', () async {
      final m = await meetings.create(title: 'x', status: MeetingStatus.ready);
      final dir = await paths.recordingsDir();
      File('$dir/${m.id}.wav').writeAsBytesSync(wav16(flat(500, 0.1)));
      await meetings.setAudioPath(m.id, '${m.id}.wav');
      final report = await service().run(m.id);
      expect(report.analysed, 0);
      expect(factory.created, 0);
    });

    test('an unreadable recording is reported in Arabic', () async {
      final dir = await paths.recordingsDir();
      File('$dir/$meetingId.wav').writeAsStringSync('broken');
      await expectLater(
        service().run(meetingId),
        throwsA(
          isA<InsatoException>().having(
            (e) => e.messageAr,
            'messageAr',
            KS.reverseBadAudio,
          ),
        ),
      );
      expect(factory.disposed, isTrue);
    });
  });
}
