// The F14 engine builders read by the shared engine selection.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/local_llm/llm_catalog.dart';
import 'package:insato/features/local_llm/llm_server_client.dart';
import 'package:insato/features/local_llm/local_llm_providers.dart';
import 'package:insato/features/local_llm/local_minutes_backends.dart';
import 'package:insato/minutes/minutes_backend.dart';
import 'package:insato/speech/model_manager.dart' show kModelMarkerFile;
import 'package:path/path.dart' as p;

import 'fakes.dart';

const Map<String, dynamic> _schema = {
  'type': 'object',
  'required': ['ok'],
};

const _request = MinutesBackendRequest(system: 'S', user: 'U', schema: _schema);

void main() {
  group('server engine', () {
    late List<http.Request> log;
    late ProviderContainer container;

    setUp(() {
      log = [];
      final client = MockClient((req) async {
        log.add(req);
        if (req.url.path == '/api/show') {
          return http.Response(
            jsonEncode({
              'model_info': {'qwen3.context_length': 8192},
            }),
            200,
          );
        }
        return http.Response(
          '${jsonEncode({
            'model': 'qwen3:8b',
            'message': {'content': '{"ok": true}'},
            'done': true,
          })}\n',
          200,
        );
      });
      container = ProviderContainer(
        overrides: [
          llmServerClientFactoryProvider.overrideWithValue(
            (url) => LlmServerClient(baseUrl: url, client: client),
          ),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('no backend until a model is chosen', () async {
      final b = container.read(serverMinutesBackendBuilderProvider)!;
      expect(await b.build(AppSettingsData.defaults), isNull);
      expect(
        await b.build(AppSettingsData.defaults.copyWith(serverModel: '  ')),
        isNull,
      );
      expect(b.unavailableMessageAr, isNotEmpty);
      expect(b.settings, isNotNull);
    });

    test('generates through the server; loopback stays on device', () async {
      final b = container.read(serverMinutesBackendBuilderProvider)!;
      final backend = (await b.build(
        AppSettingsData.defaults.copyWith(serverModel: 'qwen3:8b'),
      ))!;
      expect(backend.engineId, AppSettingsData.engineServer);
      expect(backend.sendsDataOffDevice, isFalse);
      final out = await backend.generateStructured(_request);
      expect(out.text, '{"ok": true}');
      expect(out.model, 'ollama/qwen3:8b');
      expect(log.map((r) => r.url.path), ['/api/show', '/api/chat']);
      expect((jsonDecode(log.last.body) as Map)['options']['num_ctx'], 8192);
      backend.close();
    });

    test('a LAN server sends data off the device', () async {
      final b = container.read(serverMinutesBackendBuilderProvider)!;
      final backend = (await b.build(
        AppSettingsData.defaults.copyWith(
          serverModel: 'm',
          serverUrl: 'http://192.168.1.20:11434',
        ),
      ))!;
      expect(backend.sendsDataOffDevice, isTrue);
      backend.close();
    });
  });

  group('on-device engine', () {
    late Directory tmp;
    late List<FakeGenerator> loaded;
    late List<String> loadedPaths;
    late ProviderContainer container;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('insato_llm_builder');
      loaded = [];
      loadedPaths = [];
      container = ProviderContainer(
        overrides: [
          localLlmModelsDirProvider.overrideWith((ref) async => tmp.path),
          localLlmIsDesktopProvider.overrideWithValue(false),
          localLlmLoaderProvider.overrideWithValue((model, path) async {
            loadedPaths.add(path);
            final g = FakeGenerator(
              name: model.modelLabel,
              contextTokens: model.contextTokens,
              responses: ['{"ok": false}'],
            );
            loaded.add(g);
            return g;
          }),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    void install(LocalLlmModel m) {
      final dir = Directory(p.join(tmp.path, m.id))
        ..createSync(recursive: true);
      File(p.join(dir.path, m.fileName)).writeAsStringSync('GGUF');
      File(p.join(dir.path, kModelMarkerFile)).writeAsStringSync('{}');
    }

    test('no backend while the model is not downloaded', () async {
      final b = container.read(localMinutesBackendBuilderProvider)!;
      expect(await b.build(AppSettingsData.defaults), isNull);
      expect(b.unavailableMessageAr, isNotEmpty);
    });

    test('runs the recommended phone model from its file', () async {
      const m = LocalLlmCatalog.qwen3_4b;
      install(m);
      final b = container.read(localMinutesBackendBuilderProvider)!;
      final backend = (await b.build(AppSettingsData.defaults))!;
      expect(backend.engineId, AppSettingsData.engineLocal);
      expect(backend.sendsDataOffDevice, isFalse);
      expect(loaded, isEmpty, reason: 'loaded lazily');
      final out = await backend.generateStructured(_request);
      expect(out.text, '{"ok": false}');
      expect(out.model, m.modelLabel);
      expect(p.basename(loadedPaths.single), m.fileName);
      backend.close();
    });

    test('the chosen model is used when downloaded', () async {
      const m = LocalLlmCatalog.qwen3_1_7b;
      final b = container.read(localMinutesBackendBuilderProvider)!;
      final settings = AppSettingsData.defaults.copyWith(localLlmModelId: m.id);
      expect(await b.build(settings), isNull);
      install(m);
      await (await container.read(localLlmModelManagerProvider.future))
          .refresh();
      final backend = (await b.build(settings))!;
      await backend.generateStructured(_request);
      expect(p.basename(loadedPaths.single), m.fileName);
      backend.close();
    });
  });
}
