import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/speech/model_catalog.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ModelCatalog', () {
    test('ids are unique and every kind has exactly one recommended model',
        () {
      final ids = ModelCatalog.all.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final kind in ModelKind.values) {
        final rec =
            ModelCatalog.ofKind(kind).where((m) => m.recommended).toList();
        expect(rec, hasLength(1), reason: 'kind $kind');
        expect(ModelCatalog.recommendedFor(kind), rec.single);
      }
    });

    test('URLs point to the sherpa-onnx release assets', () {
      for (final m in ModelCatalog.all) {
        expect(m.url, startsWith('$kSherpaReleaseBase/'));
        expect(Uri.parse(m.url).isAbsolute, isTrue);
        expect(m.approxSizeMb, greaterThan(0));
        expect(m.requiredFiles, isNotEmpty);
        expect(m.displayNameAr, isNotEmpty);
        expect(m.descriptionAr, isNotEmpty);
        expect(m.archive, m.url.endsWith('.tar.bz2'));
      }
    });

    test('ASR models are multilingual Whisper archives (never .en)', () {
      final asr = ModelCatalog.ofKind(ModelKind.asr);
      expect(asr.map((m) => m.id),
          ['whisper-turbo', 'whisper-medium', 'whisper-small']);
      for (final m in asr) {
        expect(m.url, contains('/asr-models/sherpa-onnx-whisper-'));
        expect(m.url, isNot(contains('.en')));
        expect(m.archive, isTrue);
        expect(m.extractFiles, isNotNull);
      }
      expect(ModelCatalog.recommendedFor(ModelKind.asr).id, 'whisper-turbo');
    });

    test('speaker models use the upstream (misspelled) release tag', () {
      for (final m in ModelCatalog.ofKind(ModelKind.speaker)) {
        expect(m.url, contains('/speaker-recongition-models/'));
        expect(m.archive, isFalse);
      }
      expect(ModelCatalog.recommendedFor(ModelKind.speaker).fileName,
          'wespeaker_en_voxceleb_resnet34_LM.onnx');
      expect(ModelCatalog.sileroVad.fileName, 'silero_vad.onnx');
    });

    test('byId / tryById', () {
      expect(ModelCatalog.byId('silero-vad'), same(ModelCatalog.sileroVad));
      expect(ModelCatalog.tryById('nope'), isNull);
      expect(() => ModelCatalog.byId('nope'), throwsArgumentError);
    });
  });

  group('glob matching', () {
    test('wildcards and case-insensitivity', () {
      expect(matchesGlob('/a/b/turbo-encoder.int8.onnx', '*-encoder*.onnx'),
          isTrue);
      expect(matchesGlob('turbo-decoder.onnx', '*-encoder*.onnx'), isFalse);
      expect(matchesGlob('Small-Tokens.TXT', '*-tokens.txt'), isTrue);
      expect(matchesGlob('a.onnx', '?.onnx'), isTrue);
      expect(matchesGlob('ab.onnx', '?.onnx'), isFalse);
      // Regex metacharacters are literal.
      expect(matchesGlob('axonnx', '*.onnx'), isFalse);
    });

    test('pickBestMatch prefers int8, then shallow, then short', () {
      final files = [
        '/m/x/turbo-encoder.onnx',
        '/m/x/turbo-encoder.int8.onnx',
        '/m/x/deep/turbo-encoder.int8.onnx',
      ];
      expect(pickBestMatch(files, '*-encoder*.onnx'),
          '/m/x/turbo-encoder.int8.onnx');
      expect(pickBestMatch(files, '*-encoder*.onnx', preferInt8: false),
          '/m/x/turbo-encoder.onnx');
      expect(pickBestMatch(files, '*-decoder*.onnx'), isNull);
    });
  });

  group('resolution', () {
    final whisperFiles = [
      '/m/sherpa-onnx-whisper-turbo/turbo-encoder.int8.onnx',
      '/m/sherpa-onnx-whisper-turbo/turbo-encoder.onnx',
      '/m/sherpa-onnx-whisper-turbo/turbo-decoder.int8.onnx',
      '/m/sherpa-onnx-whisper-turbo/turbo-decoder.onnx',
      '/m/sherpa-onnx-whisper-turbo/turbo-tokens.txt',
      '/m/sherpa-onnx-whisper-turbo/test_wavs/0.wav',
    ];

    test('resolveWhisperFiles picks int8 encoder/decoder and tokens', () {
      final r = resolveWhisperFiles(whisperFiles)!;
      expect(r.encoder, endsWith('turbo-encoder.int8.onnx'));
      expect(r.decoder, endsWith('turbo-decoder.int8.onnx'));
      expect(r.tokens, endsWith('turbo-tokens.txt'));
    });

    test('falls back to fp32 files when int8 are absent', () {
      final r = resolveWhisperFiles(
          whisperFiles.where((f) => !f.contains('int8')))!;
      expect(r.encoder, endsWith('turbo-encoder.onnx'));
      expect(r.decoder, endsWith('turbo-decoder.onnx'));
    });

    test('missing files', () {
      final noTokens = whisperFiles.where((f) => !f.endsWith('.txt'));
      expect(resolveWhisperFiles(noTokens), isNull);
      expect(missingRequiredFiles(ModelCatalog.whisperSmall, noTokens),
          ['*-tokens.txt']);
      expect(resolveModelFiles(ModelCatalog.whisperSmall, noTokens), isNull);
      expect(missingRequiredFiles(ModelCatalog.whisperSmall, whisperFiles),
          isEmpty);
      expect(resolveModelFiles(ModelCatalog.whisperSmall, whisperFiles),
          isA<WhisperModelPaths>());
    });

    test('single-file models resolve to the exact upstream file', () {
      final r = resolveModelFiles(ModelCatalog.wespeakerResnet34, [
        '/m/other.onnx',
        '/m/wespeaker_en_voxceleb_resnet34_LM.onnx',
      ]);
      expect(r, isA<SingleFileModelPath>());
      expect((r! as SingleFileModelPath).path,
          '/m/wespeaker_en_voxceleb_resnet34_LM.onnx');
      expect(resolveModelFiles(ModelCatalog.sileroVad, ['/m/x.txt']), isNull);
    });

    test('listModelFilesSync skips empty and hidden files', () {
      final tmp = Directory.systemTemp.createTempSync('katib_catalog');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File(p.join(tmp.path, 'a.onnx')).writeAsBytesSync([1]);
      File(p.join(tmp.path, 'empty.onnx')).writeAsBytesSync([]);
      File(p.join(tmp.path, '.marker')).writeAsBytesSync([1]);
      Directory(p.join(tmp.path, 'sub')).createSync();
      File(p.join(tmp.path, 'sub', 'b.txt')).writeAsBytesSync([1, 2]);
      final files = listModelFilesSync(tmp.path).map(p.basename).toList();
      expect(files, unorderedEquals(['a.onnx', 'b.txt']));
      expect(listModelFilesSync(p.join(tmp.path, 'missing')), isEmpty);
    });
  });
}
