// GGUF catalog entries and their download through ModelManager.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/interfaces.dart' show ModelStatus;
import 'package:insato/features/local_llm/llm_catalog.dart';
import 'package:insato/speech/model_catalog.dart';
import 'package:insato/speech/model_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  group('catalog entries', () {
    test('ids, files and repos are unique and well formed', () {
      final all = LocalLlmCatalog.all;
      expect(all.map((m) => m.id).toSet().length, all.length);
      expect(all.map((m) => m.fileName).toSet().length, all.length);
      for (final m in all) {
        expect(m.id, matches(RegExp(r'^[a-z0-9.\-]+$')), reason: m.id);
        expect(m.fileName, endsWith('.gguf'));
        expect(m.fileName, contains('Q4_K_M'));
        expect(m.repo, matches(RegExp(r'^[\w.\-]+/[\w.\-]+-GGUF$')));
        expect(
          m.url,
          'https://huggingface.co/${m.repo}/resolve/main/${m.fileName}',
        );
        expect(Uri.parse(m.url).pathSegments.last, m.fileName);
        expect(m.sizeBytes, greaterThan(500 * 1000 * 1000));
        expect(m.minRamGb, greaterThan(m.sizeBytes / 1e9));
        expect(m.contextTokens, inInclusiveRange(4096, 32768));
        expect(m.displayNameAr, isNotEmpty);
        expect(m.descriptionAr, isNotEmpty);
        expect(m.modelLabel, m.fileName.replaceAll('.gguf', ''));
      }
    });

    test('exactly one recommended model per device class', () {
      for (final target in LocalLlmTarget.values) {
        expect(
          LocalLlmCatalog.all.where((m) => m.recommended && m.target == target),
          hasLength(1),
          reason: '$target',
        );
      }
      expect(
        LocalLlmCatalog.recommended(desktop: false),
        LocalLlmCatalog.qwen3_4b,
      );
      expect(
        LocalLlmCatalog.recommended(desktop: true),
        LocalLlmCatalog.qwen3_8b,
      );
    });

    test('phones only see phone models; PCs see all', () {
      final phone = LocalLlmCatalog.forDevice(desktop: false);
      expect(phone, isNotEmpty);
      expect(phone.every((m) => m.target == LocalLlmTarget.phone), isTrue);
      expect(phone.every((m) => m.minRamGb <= 8), isTrue);
      expect(LocalLlmCatalog.forDevice(desktop: true), LocalLlmCatalog.all);
    });

    test('resolve falls back to the recommended model', () {
      expect(
        LocalLlmCatalog.resolve('qwen3-14b-q4km', desktop: true),
        LocalLlmCatalog.qwen3_14b,
      );
      expect(
        LocalLlmCatalog.resolve(null, desktop: true),
        LocalLlmCatalog.qwen3_8b,
      );
      expect(
        LocalLlmCatalog.resolve('unknown', desktop: false),
        LocalLlmCatalog.qwen3_4b,
      );
      expect(LocalLlmCatalog.tryById('nope'), isNull);
    });

    test('sizes are reported in MiB and GB', () {
      const m = LocalLlmCatalog.qwen3_4b;
      expect(m.sizeMb, (m.sizeBytes / (1024 * 1024)).ceil());
      expect(m.sizeGbText, '2.5');
      expect(LocalLlmCatalog.qwen3_14b.sizeGbText, '9.0');
    });

    test('model specs are single GGUF files resolved by name', () {
      final specs = LocalLlmCatalog.modelSpecs;
      expect(specs, hasLength(LocalLlmCatalog.all.length));
      for (final s in specs) {
        final m = LocalLlmCatalog.tryById(s.id)!;
        expect(s.archive, isFalse);
        expect(s.url, m.url);
        expect(s.fileName, m.fileName);
        expect(s.requiredFiles, ['*.gguf']);
        expect(s.approxSizeMb, m.sizeMb);
        expect(s.recommended, m.recommended);
        final resolved = resolveModelFiles(s, ['/x/${s.id}/${m.fileName}']);
        expect(resolved, isA<SingleFileModelPath>());
        expect((resolved! as SingleFileModelPath).path, endsWith(m.fileName));
        expect(resolveModelFiles(s, ['/x/${s.id}/model.onnx']), isNull);
      }
    });
  });

  group('download', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('insato_llm_dl'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('downloads a GGUF model and resolves its file path', () async {
      final body = Uint8List.fromList(List.generate(20000, (i) => i % 251));
      final requested = <Uri>[];
      final client = MockClient.streaming((req, _) async {
        requested.add(req.url);
        Stream<List<int>> chunks() async* {
          for (var i = 0; i < body.length; i += 4096) {
            yield body.sublist(
              i,
              i + 4096 > body.length ? body.length : i + 4096,
            );
          }
        }

        return http.StreamedResponse(chunks(), 200, contentLength: body.length);
      });
      final manager = ModelManager(
        tmp.path,
        client: client,
        catalog: LocalLlmCatalog.modelSpecs,
        sleep: (_) async {},
        retryBaseDelay: Duration.zero,
      );
      const model = LocalLlmCatalog.qwen3_1_7b;
      await manager.refresh();
      expect(manager.isReady(model.id), isFalse);

      await manager.download(model.id);

      expect(requested.single.toString(), model.url);
      expect(manager.isReady(model.id), isTrue);
      expect(manager.stateOf(model.id).status, ModelStatus.ready);
      final path = await manager.filePath(model.id);
      expect(p.basename(path), model.fileName);
      expect(File(path).readAsBytesSync(), body);
      // Other models are untouched.
      expect(manager.isReady(LocalLlmCatalog.qwen3_4b.id), isFalse);

      await manager.delete(model.id);
      expect(manager.isReady(model.id), isFalse);
      await manager.dispose();
    });

    test('an HTTP error leaves the model not ready', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      final manager = ModelManager(
        tmp.path,
        client: client,
        catalog: LocalLlmCatalog.modelSpecs,
        sleep: (_) async {},
        retryBaseDelay: Duration.zero,
        maxAttempts: 1,
      );
      const model = LocalLlmCatalog.qwen3_4b;
      await expectLater(manager.download(model.id), throwsA(anything));
      expect(manager.isReady(model.id), isFalse);
      await manager.dispose();
    });
  });
}
