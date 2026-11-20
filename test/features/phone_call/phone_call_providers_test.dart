import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart' show CapturePlatform;
import 'package:insato/data/database.dart';
import 'package:insato/features/phone_call/phone_call.dart';
import 'package:insato/features/system_audio/system_audio.dart';
import 'package:insato/features/voice/mic_capture.dart'
    show capturePlatformProvider;
import 'package:insato/session/providers.dart';

import '../system_audio/system_audio_fakes.dart';

class _Mic extends FakeSessionMic {}

void main() {
  test('the session source follows the armed call setup', () async {
    final mic = _Mic();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(
          AppDatabase.forExecutor(NativeDatabase.memory()),
        ),
        capturePlatformProvider.overrideWithValue(CapturePlatform.windows),
        systemAudioPlatformProvider.overrideWithValue(
          FakeSystemAudioPlatform(),
        ),
        // The mixed / multi-device chain is not built while a call is armed.
        sessionAudioSourceProvider.overrideWith(
          (ref) => phoneCallAwareSource(ref, () => mic),
        ),
        phoneCallMicSourceProvider.overrideWithValue(mic),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(sessionAudioSourceProvider), same(mic));
    expect(c.read(phoneCallSessionPlanProvider), isNull);

    final setup = c.read(phoneCallSetupProvider.notifier);
    setup.arm(const PhoneCallSetup(mode: PhoneCallMode.phoneLink));
    final link = c.read(sessionAudioSourceProvider);
    expect(link, isA<PhoneLinkSessionAudioSource>());
    expect(
      c.read(phoneCallSessionPlanProvider)?.setup.mode,
      PhoneCallMode.phoneLink,
    );

    setup.arm(const PhoneCallSetup(mode: PhoneCallMode.speakerphone));
    final speaker = c.read(sessionAudioSourceProvider);
    expect(speaker, isA<SpeakerphoneSessionAudioSource>());

    // A take that started and stopped uses the setup up.
    await speaker.start();
    await speaker.stop();
    expect(c.read(phoneCallSetupProvider), isNull);
    expect(c.read(sessionAudioSourceProvider), same(mic));
  });

  test('Phone Link is not used off Windows', () {
    final mic = _Mic();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(
          AppDatabase.forExecutor(NativeDatabase.memory()),
        ),
        capturePlatformProvider.overrideWithValue(CapturePlatform.android),
        sessionAudioSourceProvider.overrideWith(
          (ref) => phoneCallAwareSource(ref, () => mic),
        ),
        phoneCallMicSourceProvider.overrideWithValue(mic),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(phoneCallSetupProvider.notifier)
        .arm(const PhoneCallSetup(mode: PhoneCallMode.phoneLink));
    expect(c.read(phoneCallSessionPlanProvider), isNull);
    expect(c.read(sessionAudioSourceProvider), same(mic));
    expect(
      phoneCallModeAvailable(PhoneCallMode.speakerphone, CapturePlatform.ios),
      isTrue,
    );
  });
}
