// The import flow over an in-memory database and fake speech engines: a WAV
// (pure Dart) or a "compressed" file (fake platform decoder) becomes a
// meeting with a transcript, speakers, the imported tag and its details;
// cancelling or refusing leaves nothing behind.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/wav_writer.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/database.dart';
import 'package:insato/data/repositories.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/import_audio/audio_decoder.dart';
import 'package:insato/features/import_audio/audio_formats.dart';
import 'package:insato/features/import_audio/import_store.dart';
import 'package:insato/features/import_audio/recording_importer.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart' show AppPaths;
import 'package:intl/date_symbol_data_local.dart';
import 'package:insato/core/time_format.dart';

import '../../session/fakes.dart';
import 'import_fakes.dart';

void main() {
  late AppDatabase db;
  late MeetingRepository meetings;
  late SegmentRepository segments;
  late SpeakerRepository speakers;
  late AppSettings settings;
  late FakeEnginesFactory engines;
  late PostProcessor post;
  late Directory tmp;
  late AppPaths paths;
  late ImportInfoStore store;
  FakeNativeDecoder? native;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    ensureArabicDateFormatting();
  });

  setUp(() async {
    db = memoryDb();
    meetings = MeetingRepository(db);
    segments = SegmentRepository(db);
    speakers = SpeakerRepository(db);
    settings = AppSettings(db);
    engines = FakeEnginesFactory()..segmenterBuilder = RunSegmenter.new;
    tmp = await Directory.systemTemp.createTemp('insato_import_');
    paths = AppPaths(
      documentsDir: () async => Directory('${tmp.path}/docs'),
      supportDir: () async => tmp,
      isWindows: false,
    );
    post = PostProcessor(
      db: db,
      meetings: meetings,
      segments: segments,
      speakers: speakers,
      settings: settings,
      enginesFactory: engines,
      paths: paths,
    );
    store = ImportInfoStore(db);
    native = null;
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  RecordingImporter importer() => RecordingImporter(
    meetings: meetings,
    post: post,
    settings: settings,
    engines: engines,
    recordingsDir: paths.recordingsDir,
    store: store,
    decoder: ImportAudioDecoder(native: native),
    now: () => DateTime(2026, 11, 20, 12),
  );

  /// Three voices: A, B, A (2 s each with 0.5 s pauses).
  Float32List conversation() {
    final parts = [
      voiceSamples(0, 2000),
      voiceSamples(null, 500),
      voiceSamples(1, 2000),
      voiceSamples(null, 500),
      voiceSamples(0, 2000),
    ];
    final out = Float32List(parts.fold(0, (a, p) => a + p.length));
    var o = 0;
    for (final p in parts) {
      out.setRange(o, o + p.length, p);
      o += p.length;
    }
    return out;
  }

  Future<String> writeWav(String name, Float32List samples) async {
    final path = '${tmp.path}/$name';
    final w = await WavWriter.open(path);
    await w.appendFloat32(samples);
    await w.close();
    return path;
  }

  /// A file with an MPEG-4 header whose audio the fake decoder serves.
  String fakeM4a(String name) {
    final path = '${tmp.path}/$name';
    final head = Uint8List(64)..setRange(4, 12, 'ftypM4A '.codeUnits);
    File(path).writeAsBytesSync(head);
    return path;
  }

  test('a WAV voice memo becomes a transcribed, tagged meeting', () async {
    final path = await writeWav(
      'Recording_20241115_103012.wav',
      conversation(),
    );
    final progress = <ImportProgress>[];
    final outcome = await importer().importFile(
      ImportRequest(path: path),
      onProgress: progress.add,
    );
    expect(outcome.segments, 3);
    expect(outcome.failedSegments, 0);
    expect(outcome.durationMs, 7000);
    expect(outcome.container, AudioContainer.wav);

    final m = (await meetings.get(outcome.meetingId))!;
    expect(m.status, MeetingStatus.ready);
    expect(isImportedMeeting(m), isTrue);
    expect(m.inputDevice, kImportedInputDevice);
    expect(m.title, 'Recording');
    expect(m.createdAt, DateTime(2024, 11, 15, 10, 30, 12));
    expect(m.durationMs, 7000);
    expect(m.audioPath, '${outcome.meetingId}.wav');
    expect(
      File('${await paths.recordingsDir()}/${m.audioPath}').existsSync(),
      isTrue,
    );

    final segs = await segments.getForMeeting(m.id);
    expect(segs.map((s) => s.text), ['كلام 0', 'كلام 1', 'كلام 2']);
    expect(segs[0].speakerId, isNotNull);
    expect(segs[0].speakerId, segs[2].speakerId);
    expect(segs[1].speakerId, isNot(segs[0].speakerId));

    final info = (await store.load(m.id))!;
    expect(info.fileName, 'Recording_20241115_103012.wav');
    expect(info.format, 'WAV');
    expect(info.sourceSampleRate, 16000);
    expect(info.callRecording, isFalse);

    expect(progress.first.stage, ImportStage.checking);
    expect(progress.map((p) => p.stage), contains(ImportStage.decoding));
    expect(progress.map((p) => p.stage), contains(ImportStage.transcribing));
    for (var i = 1; i < progress.length; i++) {
      expect(
        progress[i].fraction,
        greaterThanOrEqualTo(progress[i - 1].fraction - 1e-9),
      );
    }
    expect(progress.last.fraction, 1.0);
    // The source file is the user's own: kept.
    expect(File(path).existsSync(), isTrue);
  });

  test('speakers are recognised by their voiceprints', () async {
    final first = await importer().importFile(
      ImportRequest(path: await writeWav('one.wav', conversation())),
    );
    final segs = await segments.getForMeeting(first.meetingId);
    await post.renameSpeaker(segs[0].speakerId!, 'هدى');
    final second = await importer().importFile(
      ImportRequest(path: await writeWav('two.wav', conversation())),
    );
    final again = await segments.getForMeeting(second.meetingId);
    final byId = await speakers.getAllById();
    expect(byId[again[0].speakerId]!.name, 'هدى');
  });

  test('a call recording through the platform decoder', () async {
    native = FakeNativeDecoder(
      chunks: [
        for (final part in [
          voiceSamples(0, 2000),
          voiceSamples(null, 500),
          voiceSamples(1, 2000),
        ])
          PcmChunk(pcm16(part), sampleRate: 16000, channels: 1),
      ],
      info: const NativeAudioInfo(
        sampleRate: 16000,
        channels: 1,
        durationMs: 4500,
        codec: 'audio/mp4a-latm',
        creationDate: '20241001T081500.000Z',
      ),
    );
    final path = fakeM4a('Call recording Ahmad_241001_111500.m4a');
    final outcome = await importer().importFile(
      ImportRequest(path: path, viaShare: true, deleteSourceWhenDone: true),
    );
    final m = (await meetings.get(outcome.meetingId))!;
    expect(m.title, 'مكالمة: Ahmad');
    // The container date wins over the file name.
    expect(m.createdAt, DateTime.utc(2024, 10, 1, 8, 15).toLocal());
    expect(await segments.getForMeeting(m.id), hasLength(2));
    final info = (await store.load(m.id))!;
    expect(info.format, 'M4A');
    expect(info.codec, 'audio/mp4a-latm');
    expect(info.callRecording, isTrue);
    expect(info.viaShare, isTrue);
    expect(native!.closed, 1);
    // A share copy is deleted after the import.
    expect(File(path).existsSync(), isFalse);
  });

  test('"keep audio" off: the converted WAV is dropped afterwards', () async {
    await settings.setKeepAudio(false);
    final outcome = await importer().importFile(
      ImportRequest(path: await writeWav('memo.wav', conversation())),
    );
    final m = (await meetings.get(outcome.meetingId))!;
    expect(m.audioPath, isNull);
    expect(Directory(await paths.recordingsDir()).listSync(), isEmpty);
    expect(await segments.getForMeeting(m.id), hasLength(3));
  });

  test('a user title is kept', () async {
    final outcome = await importer().importFile(
      ImportRequest(
        path: await writeWav('x.wav', conversation()),
        title: ' اجتماع اللجنة ',
      ),
    );
    expect((await meetings.get(outcome.meetingId))!.title, 'اجتماع اللجنة');
  });

  group('cancel', () {
    test('during transcription: nothing is left behind', () async {
      final token = ImportCancelToken();
      final path = await writeWav('memo.wav', conversation());
      await expectLater(
        importer().importFile(
          ImportRequest(path: path),
          cancel: token,
          onProgress: (p) {
            if (p.stage == ImportStage.transcribing) token.cancel();
          },
        ),
        throwsA(isA<OperationCancelledException>()),
      );
      expect(await meetings.getAll(), isEmpty);
      expect(await speakers.getAll(), isEmpty);
      expect(Directory(await paths.recordingsDir()).listSync(), isEmpty);
      final rows = await db.select(db.settings).get();
      expect(rows.where((r) => r.key.startsWith('import_info:')), isEmpty);
    });

    test('during decoding: the platform decoder is released', () async {
      final token = ImportCancelToken();
      native = FakeNativeDecoder(
        chunks: [
          for (var i = 0; i < 20; i++)
            PcmChunk(
              pcm16(voiceSamples(0, 1000)),
              sampleRate: 16000,
              channels: 1,
            ),
        ],
      )..onRead = (i) {
          if (i == 3) token.cancel();
        };
      await expectLater(
        importer().importFile(
          ImportRequest(path: fakeM4a('a.m4a')),
          cancel: token,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
      expect(native!.closed, 1);
      expect(await meetings.getAll(), isEmpty);
      expect(Directory(await paths.recordingsDir()).listSync(), isEmpty);
    });
  });

  group('refused files (no meeting is created)', () {
    Future<void> expectRefused(
      Future<Object?> f,
      ImportFailure failure,
    ) async {
      await expectLater(
        f,
        throwsA(
          isA<ImportException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.messageAr, 'messageAr', isNotEmpty),
        ),
      );
      expect(await meetings.getAll(), isEmpty);
    }

    test('missing, empty, not audio', () async {
      await expectRefused(
        importer().importFile(ImportRequest(path: '${tmp.path}/nope.m4a')),
        ImportFailure.notFound,
      );
      final empty = File('${tmp.path}/empty.mp3')..writeAsBytesSync([]);
      await expectRefused(
        importer().importFile(ImportRequest(path: empty.path)),
        ImportFailure.empty,
      );
      final pdf = File('${tmp.path}/doc.mp3')
        ..writeAsBytesSync('%PDF-1.7 something'.codeUnits);
      await expectRefused(
        importer().importFile(ImportRequest(path: pdf.path)),
        ImportFailure.notAudio,
      );
    });

    test('no decoder for the codec on this device', () async {
      await expectRefused(
        importer().importFile(ImportRequest(path: fakeM4a('a.m4a'))),
        ImportFailure.unsupported,
      );
      native = FakeNativeDecoder(
        openError: const ImportException(ImportFailure.unsupported, 'x'),
      );
      final ogg = File('${tmp.path}/voice.ogg')
        ..writeAsBytesSync(Uint8List(64)..setRange(0, 4, 'OggS'.codeUnits));
      await expectLater(
        importer().importFile(ImportRequest(path: ogg.path)),
        throwsA(
          isA<ImportException>().having(
            (e) => e.messageAr,
            'messageAr',
            contains('OGG'),
          ),
        ),
      );
    });

    test('too long (declared duration)', () async {
      native = FakeNativeDecoder(
        info: const NativeAudioInfo(
          sampleRate: 16000,
          channels: 1,
          durationMs: 9 * 3600 * 1000,
        ),
      );
      await expectRefused(
        importer().importFile(ImportRequest(path: fakeM4a('long.m4a'))),
        ImportFailure.tooLong,
      );
      expect(native!.closed, 1);
    });

    test('too short / silent', () async {
      await expectRefused(
        importer().importFile(
          ImportRequest(path: await writeWav('s.wav', voiceSamples(0, 500))),
        ),
        ImportFailure.tooShort,
      );
      expect(Directory(await paths.recordingsDir()).listSync(), isEmpty);
    });

    test('a decoder failure half-way', () async {
      native = FakeNativeDecoder(
        chunks: [
          PcmChunk(pcm16(voiceSamples(0, 2000)), sampleRate: 16000, channels: 1),
        ],
        readError: const ImportException(
          ImportFailure.decodeFailed,
          'تعذّر فكّ ترميز الصوت',
        ),
        readErrorAfter: 1,
      );
      await expectRefused(
        importer().importFile(ImportRequest(path: fakeM4a('bad.m4a'))),
        ImportFailure.decodeFailed,
      );
      expect(Directory(await paths.recordingsDir()).listSync(), isEmpty);
    });

    test('speech models missing', () async {
      engines.notReady = const ModelException('النموذج غير مُنزَّل');
      await expectLater(
        importer().importFile(
          ImportRequest(path: await writeWav('m.wav', conversation())),
        ),
        throwsA(isA<ModelException>()),
      );
      expect(await meetings.getAll(), isEmpty);
    });
  });

  test('a transcription failure keeps the meeting and its audio', () async {
    engines.asr = FakeAsr(failIndices: {0, 1, 2});
    String? created;
    await expectLater(
      importer().importFile(
        ImportRequest(path: await writeWav('m.wav', conversation())),
        onMeetingCreated: (id) => created = id,
      ),
      throwsA(isA<InsatoException>()),
    );
    final m = (await meetings.get(created!))!;
    expect(m.status, MeetingStatus.failed);
    expect(m.errorMessage, contains('إعادة المعالجة'));
    expect(m.audioPath, isNotNull);
    // Re-processing works once the engine is fine again.
    engines.asr = FakeAsr();
    final report = await post.reprocessFromAudio(m.id);
    expect(report.segments, 3);
  });

  test('transcriptionStatus maps the post-processor progress', () {
    expect(transcriptionStatus(0.01), contains('نماذج'));
    expect(transcriptionStatus(0.425), contains('50'));
    expect(transcriptionStatus(0.85), contains('إكمال'));
    expect(transcriptionStatus(0.97), contains('المتحدثين'));
  });
}
