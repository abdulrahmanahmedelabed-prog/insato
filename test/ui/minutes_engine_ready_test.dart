// Readiness of the on-device and local-server minutes engines (the banner of
// the minutes tab): model downloaded / server model chosen, with an
// engine-specific message.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/interfaces.dart' show ModelState, ModelStatus;
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/local_llm/llm_catalog.dart';
import 'package:insato/features/local_llm/local_llm_providers.dart';
import 'package:insato/features/local_llm/local_minutes_backends.dart';
import 'package:insato/features/local_llm/strings.dart';
import 'package:insato/ui/ui_providers.dart';

LocalMinutesBackendBuilder _builder() => LocalMinutesBackendBuilder(
  build: (_) async => null,
  unavailableMessageAr: 'x',
);

ProviderContainer _container(
  AppSettingsData settings, {
  Map<String, ModelState> states = const {},
}) {
  final c = ProviderContainer(
    overrides: [
      appSettingsDataProvider.overrideWith((_) => Stream.value(settings)),
      localLlmIsDesktopProvider.overrideWithValue(true),
      localMinutesBackendBuilderProvider.overrideWithValue(_builder()),
      serverMinutesBackendBuilderProvider.overrideWithValue(_builder()),
      localLlmModelStatesProvider.overrideWith((_) => Stream.value(states)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<MinutesEngineReadiness?> _read(ProviderContainer c) async {
  final sub = c.listen(minutesEngineReadinessProvider, (_, _) {});
  final states = c.listen(localLlmModelStatesProvider, (_, _) {});
  addTearDown(sub.close);
  addTearDown(states.close);
  await c.read(appSettingsDataProvider.future);
  await c.read(localLlmModelStatesProvider.future);
  await Future<void>.delayed(Duration.zero);
  return c.read(minutesEngineReadinessProvider);
}

void main() {
  test('server engine without a model is not ready', () async {
    final r = await _read(
      _container(
        const AppSettingsData(minutesEngine: AppSettingsData.engineServer),
      ),
    );
    expect(r?.ready, isFalse);
    expect(r?.messageAr, LS.serverUnavailable);
  });

  test('server engine with a model is ready', () async {
    final r = await _read(
      _container(
        const AppSettingsData(
          minutesEngine: AppSettingsData.engineServer,
          serverModel: 'qwen3:8b',
        ),
      ),
    );
    expect(r?.ready, isTrue);
    expect(r?.messageAr, isNull);
  });

  test('on-device engine is ready only once its model is installed', () async {
    const settings = AppSettingsData(
      minutesEngine: AppSettingsData.engineLocal,
    );
    final model = LocalLlmCatalog.resolve(null, desktop: true);
    final missing = await _read(
      _container(
        settings,
        states: {model.id: const ModelState(ModelStatus.notDownloaded)},
      ),
    );
    expect(missing?.ready, isFalse);
    expect(missing?.messageAr, LS.localUnavailable);

    final installed = await _read(
      _container(
        settings,
        states: {model.id: const ModelState(ModelStatus.ready)},
      ),
    );
    expect(installed?.ready, isTrue);
  });
}
