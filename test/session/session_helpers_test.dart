import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/core/models.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/diarization/clustering.dart';
import 'package:insato/diarization/vector_math.dart';
import 'package:insato/speech/model_catalog.dart';
import 'package:insato/speech/processing_isolate.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/session/post_processor.dart';
import 'package:insato/session/providers.dart';

import 'fakes.dart';

Speaker _speaker(
  String id, {
  bool named = false,
  Float32List? centroid,
  int count = 0,
}) => Speaker(
  id: id,
  name: id,
  colorValue: 0xFF000000,
  isNamedByUser: named,
  createdAt: DateTime(2026),
  centroid: centroid,
  embeddingCount: centroid == null ? 0 : count,
);

TranscriptSegment _seg(
  String id,
  int index,
  String? speaker, {
  int durMs = 2000,
  bool locked = false,
  int? startMs,
}) => TranscriptSegment(
  id: id,
  meetingId: 'm',
  index: index,
  startMs: startMs ?? index * 3000,
  endMs: (startMs ?? index * 3000) + durMs,
  text: 't$index',
  speakerId: speaker,
  speakerLocked: locked,
);

RefinementResult _result(
  List<RefinedCluster> clusters, {
  List<String> skipped = const [],
}) => RefinementResult(
  clusters: clusters,
  clusterIdBySegment: {
    for (final c in clusters)
      for (final s in c.segmentIds) s: c.id,
  },
  skippedSegmentIds: skipped,
);

RefinedCluster _cluster(
  String id,
  List<String> segs,
  int voice, {
  String? linked,
  int totalMs = 4000,
}) => RefinedCluster(
  id: id,
  segmentIds: segs,
  centroid: voiceOf(voice),
  totalMs: totalMs,
  linkedSpeakerId: linked,
  linkReason: linked == null
      ? ClusterLinkReason.none
      : ClusterLinkReason.voiceprint,
);

// ---- Isolate fakes (constructed inside the worker isolate) ----------------

class _IsoEmbedder implements SpeakerEmbedder {
  _IsoEmbedder(this.crashMarker);
  final String crashMarker;
  @override
  int get dimension => kFakeDim;
  @override
  Future<void> initialize() async {}
  @override
  Future<Float32List?> embed(Float32List samples) async {
    // Crash the worker once (the first time a 3 s segment arrives).
    if (crashMarker.isNotEmpty &&
        samples.length == 48000 &&
        !File(crashMarker).existsSync()) {
      File(crashMarker).writeAsStringSync('crashed');
      Isolate.current.kill(priority: Isolate.immediate);
    }
    final k = decodeVoice(samples);
    return k == null ? null : embeddingOf(k, samples.length);
  }

  @override
  Future<void> dispose() async {}
}

Future<WorkerEngines> _isoFactory(ProcessingIsolateConfig c) async =>
    WorkerEngines(
      asr: c.runAsr ? FakeAsr() : null,
      embedder: _IsoEmbedder(c.speakerModel),
    );

ProcessingIsolateConfig _isoConfig({bool runAsr = true, String marker = ''}) =>
    ProcessingIsolateConfig(
      whisperEncoder: 'e',
      whisperDecoder: 'd',
      whisperTokens: 't',
      speakerModel: marker,
      runAsr: runAsr,
    );

void main() {
  group('planClusterSpeakers', () {
    test('keeps linked clusters and reuses the dominant live speaker', () {
      final segs = [
        _seg('s0', 0, 'a'),
        _seg('s1', 1, 'a'),
        _seg('s2', 2, 'b'),
        _seg('s3', 3, 'k'),
      ];
      final known = _speaker('k', named: true, centroid: voiceOf(5), count: 9);
      final plan = planClusterSpeakers(
        segments: segs,
        result: _result([
          _cluster('cluster:1', ['s0', 's1', 's2'], 0, totalMs: 6000),
          _cluster('cluster:2', ['s3'], 5, linked: 'k'),
        ]),
        speakersById: {'a': _speaker('a'), 'b': _speaker('b'), 'k': known},
        reusableSpeakerIds: {'a', 'b'},
        matchThreshold: 0.55,
      );
      expect(plan, {'cluster:1': 'a', 'cluster:2': 'k'});
    });

    test('named speakers win close votes; claimed speakers are not reused', () {
      final segs = [
        _seg('s0', 0, 'auto', durMs: 3000),
        _seg('s1', 1, 'named', durMs: 2000),
        _seg('s2', 2, 'auto', durMs: 2000),
      ];
      final speakers = {
        'auto': _speaker('auto'),
        'named': _speaker('named', named: true),
      };
      final plan = planClusterSpeakers(
        segments: segs,
        result: _result([
          _cluster('cluster:1', ['s0', 's1'], 0, totalMs: 5000),
          _cluster('cluster:2', ['s2'], 1, totalMs: 2000),
        ]),
        speakersById: speakers,
        reusableSpeakerIds: {'auto', 'named'},
        matchThreshold: 0.55,
      );
      // 2000 ms × 2 (named) > 3000 ms (auto).
      expect(plan['cluster:1'], 'named');
      expect(plan['cluster:2'], 'auto');
    });

    test('a non-reusable speaker is only reused when the voice matches', () {
      final segs = [_seg('s0', 0, 'lib'), _seg('s1', 1, 'lib2')];
      final speakers = {
        'lib': _speaker('lib', centroid: voiceOf(0), count: 5),
        'lib2': _speaker('lib2', centroid: voiceOf(9), count: 5),
      };
      final plan = planClusterSpeakers(
        segments: segs,
        result: _result([
          _cluster('cluster:1', ['s0'], 0),
          _cluster('cluster:2', ['s1'], 1),
        ]),
        speakersById: speakers,
        reusableSpeakerIds: const {},
        matchThreshold: 0.55,
      );
      expect(plan['cluster:1'], 'lib');
      expect(plan['cluster:2'], isNull); // voice 1 ≠ voiceprint 9
    });
  });

  group('computeSegmentAssignments', () {
    test('relabels clustered segments, never locked ones', () {
      final segs = [
        _seg('s0', 0, 'a'),
        _seg('s1', 1, 'a'),
        _seg('s2', 2, 'x', locked: true),
      ];
      final changes = computeSegmentAssignments(
        segments: segs,
        result: _result([
          _cluster('c1', ['s0'], 0),
          _cluster('c2', ['s1', 's2'], 1),
        ]),
        speakerByCluster: {'c1': 'a', 'c2': 'b'},
        removableSpeakerIds: const {},
      );
      expect(changes, {'s1': 'b'});
    });

    test('unclustered segments of a removed speaker take the nearest '
        'neighbour', () {
      final segs = [
        _seg('s0', 0, 'a', startMs: 0, durMs: 2000),
        _seg('s1', 1, 'gone', startMs: 2100, durMs: 400), // no embedding
        _seg('s2', 2, 'b', startMs: 10000, durMs: 2000),
        _seg('s3', 3, 'gone', startMs: 9000, durMs: 500), // closer to s2
        _seg('s4', 4, 'keep', startMs: 20000, durMs: 300),
      ];
      final changes = computeSegmentAssignments(
        segments: segs,
        result: _result(
          [
            _cluster('c1', ['s0'], 0),
            _cluster('c2', ['s2'], 1),
          ],
          skipped: ['s1', 's3', 's4'],
        ),
        speakerByCluster: {'c1': 'a', 'c2': 'b'},
        removableSpeakerIds: {'gone'},
      );
      expect(changes, {'s1': 'a', 's3': 'b'});
    });
  });

  group('voiceprint maths', () {
    test('unlearn reverses learn approximately', () {
      final base = List.generate(8, (i) => embeddingOf(0, i));
      final (c, n) = updateVoiceprint(null, 0, base);
      final intruder = embeddingOf(1, 99);
      final (c2, n2) = updateVoiceprint(c, n, [intruder]);
      expect(n2, 9);
      final (c3, n3) = unlearnFromVoiceprint(c2, n2, [intruder]);
      expect(n3, 8);
      expect(cosine(c3!, c), greaterThan(0.99));
      expect(cosine(c3, voiceOf(0)), greaterThan(cosine(c2, voiceOf(0))));
    });

    test('unlearning everything clears the voiceprint', () {
      final e = embeddingOf(0, 1);
      expect(unlearnFromVoiceprint(e, 1, [e]), (null, 0));
      expect(unlearnFromVoiceprint(e, 0, [e]), (null, 0));
      // Wrong dimension is ignored.
      final (c, n) = unlearnFromVoiceprint(e, 3, [Float32List(3)..[0] = 1]);
      expect(n, 3);
      expect(c, same(e));
    });

    test('ledger codec tolerates corruption', () {
      final l = {'seg-1': 'sp-1', 'seg-2': 'sp-2'};
      expect(decodeVoiceprintLedger(encodeVoiceprintLedger(l)), l);
      expect(decodeVoiceprintLedger('not json'), isEmpty);
      expect(decodeVoiceprintLedger('[1,2]'), isEmpty);
      expect(decodeVoiceprintLedger('{"a": 1, "b": "x"}'), {'b': 'x'});
      expect(decodeVoiceprintLedger(null), isEmpty);
    });
  });

  test('carryOverLocks follows time overlap', () {
    final old = [
      _seg('o1', 0, 'sara', startMs: 1000, durMs: 2000, locked: true),
      _seg('o2', 1, 'ali', startMs: 5000, durMs: 2000),
    ];
    final fresh = [
      _seg('n1', 0, 'x', startMs: 900, durMs: 2000), // 1900 ms overlap
      _seg('n2', 1, 'y', startMs: 2500, durMs: 2000), // 500 ms: too little
      _seg('n3', 2, 'z', startMs: 5000, durMs: 2000), // unlocked old
    ];
    final out = carryOverLocks(fresh, old);
    expect(out[0].speakerId, 'sara');
    expect(out[0].speakerLocked, isTrue);
    expect(out[0].text, 't0');
    expect(out[1].speakerId, 'y');
    expect(out[1].speakerLocked, isFalse);
    expect(out[2].speakerId, 'z');
    expect(carryOverLocks(fresh, const []), same(fresh));
  });

  group('model requirements', () {
    test('on-device mode needs VAD, speaker and the chosen Whisper model', () {
      final ids = requiredModelIds(
        const SessionEngineRequest(
          asrEngine: AppSettingsData.asrLocal,
          whisperModelId: 'whisper-small',
        ),
        (_) => false,
      );
      expect(ids, [
        ModelCatalog.sileroVad.id,
        ModelCatalog.recommendedFor(ModelKind.speaker).id,
        'whisper-small',
      ]);
    });

    test('cloud mode needs no Whisper; unknown ids fall back', () {
      final cloud = SessionEngineRequest.fromSettings(
        AppSettingsData.defaults.copyWith(asrEngine: AppSettingsData.asrCloud),
      );
      expect(cloud.usesCloudAsr, isTrue);
      expect(requiredModelIds(cloud, (_) => false), hasLength(2));
      final unknown = requiredModelIds(
        const SessionEngineRequest(
          asrEngine: AppSettingsData.asrLocal,
          whisperModelId: 'nope',
        ),
        (_) => false,
      );
      expect(unknown.last, ModelCatalog.recommendedFor(ModelKind.asr).id);
    });

    test('an installed alternative speaker model is preferred', () {
      final alt = ModelCatalog.ofKind(ModelKind.speaker)
          .firstWhere((m) => !m.recommended)
          .id;
      expect(pickInstalledModelId(ModelKind.speaker, (id) => id == alt), alt);
      expect(
        pickInstalledModelId(ModelKind.speaker, (_) => true),
        ModelCatalog.recommendedFor(ModelKind.speaker).id,
      );
    });
  });

  test('MinutesEngineHandle releases once', () {
    var n = 0;
    final h = MinutesEngineHandle(FakeMinutesEngine(), release: () => n++);
    h.release();
    h.release();
    expect(n, 1);
  });

  group('IsolateSegmentProcessor', () {
    test(
      'on-device mode returns transcripts and embeddings in order',
      () async {
        final proc = await IsolateSegmentProcessor.start(
          spawn: () =>
              ProcessingIsolate.spawnWithFactory(_isoConfig(), _isoFactory),
        );
        expect(proc.embeddingDimension, kFakeDim);
        final results = await Future.wait([
          for (var i = 0; i < 4; i++)
            proc.process(speech(i, i * 2500, 2000, i)),
        ]);
        expect(results.map((r) => r.asr.text), [
          'كلام 0',
          'كلام 1',
          'كلام 2',
          'كلام 3',
        ]);
        expect(results.every((r) => r.embedding!.length == kFakeDim), isTrue);
        await proc.dispose(waitForPending: true);
        await expectLater(
          proc.process(speech(9, 0, 2000, 0)),
          throwsA(isA<AsrException>()),
        );
      },
    );

    test(
      'cloud mode: ASR from the remote engine, embeddings from the worker',
      () async {
        final cloud = FakeAsr(failIndices: {1});
        final proc = await IsolateSegmentProcessor.start(
          spawn: () => ProcessingIsolate.spawnWithFactory(
            _isoConfig(runAsr: false),
            _isoFactory,
          ),
          cloudAsr: cloud,
          maxConcurrentCloudRequests: 2,
        );
        final ok = await proc.process(speech(0, 0, 2000, 1));
        expect(ok.asr.text, 'كلام 0');
        expect(ok.embedding, isNotNull);
        await expectLater(
          proc.process(speech(1, 0, 2000, 1)),
          throwsA(isA<AsrException>()),
        );
        await proc.dispose();
        expect(cloud.disposed, isTrue);
      },
    );

    test('respawns a crashed worker and retries the segment', () async {
      final dir = await Directory.systemTemp.createTemp('insato_iso_');
      addTearDown(() => dir.delete(recursive: true));
      final marker = '${dir.path}/crashed';
      var spawns = 0;
      final proc = await IsolateSegmentProcessor.start(
        spawn: () {
          spawns++;
          return ProcessingIsolate.spawnWithFactory(
            _isoConfig(marker: marker),
            _isoFactory,
          );
        },
      );
      final first = await proc.process(speech(0, 0, 2000, 0));
      expect(first.asr.text, 'كلام 0');
      final crashed = await proc.process(speech(1, 2500, 3000, 1));
      expect(crashed.asr.text, 'كلام 1');
      expect(File(marker).existsSync(), isTrue);
      expect(spawns, 2);
      final after = await proc.process(speech(2, 6000, 2000, 0));
      expect(after.asr.text, 'كلام 2');
      await proc.dispose();
    });
  });

  group('review fixes', () {
    test(
      'disposeSegmenterSafely returns for an unlistened segmenter',
      () async {
        // close() on a single-subscription stream nobody listened to never
        // completes; disposal must not hang on it.
        final seg = FakeSegmenter();
        await disposeSegmenterSafely(
          seg,
          timeout: const Duration(milliseconds: 50),
        ).timeout(const Duration(seconds: 2));
        expect(seg.disposed, isTrue);
      },
    );

    test(
      'SessionEngines.dispose releases everything without a listener',
      () async {
        final seg = FakeSegmenter();
        final asr = FakeAsr();
        var extra = false;
        final engines = SessionEngines(
          segmenter: seg,
          processor: InlineSegmentProcessor(asr: asr, embedder: FakeEmbedder()),
          description: 'x',
          onDispose: () async => extra = true,
        );
        await engines.dispose().timeout(const Duration(seconds: 10));
        expect(seg.disposed, isTrue);
        expect(asr.disposed, isTrue);
        expect(extra, isTrue);
      },
    );

    test('maxToleratedReprocessFailures', () {
      expect(maxToleratedReprocessFailures(0), 2);
      expect(maxToleratedReprocessFailures(10), 2);
      expect(maxToleratedReprocessFailures(100), 5);
      expect(maxToleratedReprocessFailures(101), 6);
    });

    group('AppPaths', () {
      late Directory root;
      late Directory docs;
      late Directory local;
      setUp(() async {
        root = await Directory.systemTemp.createTemp('insato_paths_');
        docs = await Directory('${root.path}/Documents').create();
        local = await Directory('${root.path}/LocalAppData/Insato')
            .create(recursive: true);
      });
      tearDown(() => root.delete(recursive: true));

      AppPaths paths({required bool windows}) => AppPaths(
        documentsDir: () async => docs,
        supportDir: () async => root,
        localDataDir: () async => local,
        isWindows: windows,
      );

      test('mobile keeps data in the private documents directory', () async {
        final pp = paths(windows: false);
        expect(await pp.recordingsDir(), '${docs.path}/recordings');
        expect(await pp.exportsDir(), '${docs.path}/exports');
        expect(await pp.databaseDir(), docs.path);
      });

      test('Windows keeps data out of Documents', () async {
        final pp = paths(windows: true);
        expect(await pp.recordingsDir(), '${local.path}/recordings');
        expect(await pp.exportsDir(), '${local.path}/exports');
        expect(await pp.databaseDir(), '${local.path}/data');
      });

      test('Windows migration moves only Insato files', () async {
        const id = '3c1c8728-6e38-40b0-b899-f2ee38a61eb7';
        File('${docs.path}/insato.sqlite').writeAsStringSync('db');
        File('${docs.path}/insato.sqlite-wal').writeAsStringSync('wal');
        await Directory('${docs.path}/recordings').create();
        File('${docs.path}/recordings/$id.wav').writeAsStringSync('wav');
        File('${docs.path}/recordings/holiday.wav').writeAsStringSync('x');
        File('${docs.path}/other.sqlite').writeAsStringSync('y');

        final pp = paths(windows: true);
        await pp.migrateLegacyWindowsData();
        expect(
          File('${local.path}/data/insato.sqlite').readAsStringSync(),
          'db',
        );
        expect(
          File('${local.path}/data/insato.sqlite-wal').existsSync(),
          isTrue,
        );
        expect(File('${docs.path}/insato.sqlite').existsSync(), isFalse);
        expect(File('${local.path}/recordings/$id.wav').existsSync(), isTrue);
        expect(File('${docs.path}/recordings/$id.wav').existsSync(), isFalse);
        // Someone else's files stay where they are.
        expect(
          File('${docs.path}/recordings/holiday.wav').existsSync(),
          isTrue,
        );
        expect(File('${docs.path}/other.sqlite').existsSync(), isTrue);

        // Idempotent; never overwrites the migrated database.
        File('${docs.path}/insato.sqlite').writeAsStringSync('stale');
        await pp.migrateLegacyWindowsData();
        expect(
          File('${local.path}/data/insato.sqlite').readAsStringSync(),
          'db',
        );
      });

      test('migration is a no-op off Windows', () async {
        File('${docs.path}/insato.sqlite').writeAsStringSync('db');
        await paths(windows: false).migrateLegacyWindowsData();
        expect(File('${docs.path}/insato.sqlite').existsSync(), isTrue);
      });

      test('resolveRecording follows the file, not a stale path', () async {
        const id = '3c1c8728-6e38-40b0-b899-f2ee38a61eb7';
        final pp = paths(windows: false);
        final dir = await pp.recordingsDir();
        expect(recordingFileName(id), '$id.wav');
        expect(await pp.resolveRecording('$id.wav'), '$dir/$id.wav');
        // An absolute path of an old iOS container that no longer exists.
        const stale =
            '/var/mobile/Containers/Data/Application/OLD/Documents/'
            'recordings/$id.wav';
        expect(await pp.resolveRecording(stale), '$dir/$id.wav');
        // An absolute path that still exists outside the recordings dir.
        final elsewhere = File('${root.path}/$id.wav')..writeAsStringSync('w');
        expect(await pp.resolveRecording(elsewhere.path), elsewhere.path);
        // ...but the recordings dir wins once the file is there.
        File('$dir/$id.wav').writeAsStringSync('w');
        expect(await pp.resolveRecording(elsewhere.path), '$dir/$id.wav');
      });
    });
  });
}
