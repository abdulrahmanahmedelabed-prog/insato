import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/phone_call/phone_call_models.dart';
import 'package:insato/features/phone_call/phone_call_providers.dart';
import 'package:insato/features/phone_call/telephone_profile.dart';
import 'package:insato/session/meeting_session_controller.dart';
import 'package:insato/speech/vad_segmenter.dart';

import 'call_signals.dart';

Speaker _sp(String? device) => Speaker(
  id: 'a',
  name: 'أحمد',
  colorValue: 0,
  isNamedByUser: true,
  createdAt: DateTime(2026),
  voiceDevice: device,
);

double _gainDb(double hz) {
  final x = tones(500, [hz], amp: 0.3);
  final y = const TelephoneBandLimiter().process(x);
  // Skip the start-up transient (100 ms).
  return 20 * _log10(rms(y, from: 1600) / rms(x, from: 1600));
}

double _log10(double v) => v <= 0 ? -99 : math.log(v) / math.ln10;

void main() {
  const p = TelephoneAudioProfile.standard;

  group('profile parameters', () {
    test('VAD is more sensitive than the default for both modes', () {
      const def = VadSegmenterConfig();
      for (final m in PhoneCallMode.values) {
        expect(p.vadFor(m).threshold, lessThan(def.threshold));
        expect(p.vadFor(m).minSpeechDuration, lessThan(def.minSpeechDuration));
      }
      // A phone on speaker is a distant source.
      expect(
        p.vadFor(PhoneCallMode.speakerphone).threshold,
        lessThan(p.vadFor(PhoneCallMode.phoneLink).threshold),
      );
      expect(p.bandLowHz, 300);
      expect(p.bandHighHz, 3400);
      expect(p.bandLimits(CallSide.remote), isTrue);
      expect(p.bandLimits(CallSide.local), isFalse);
    });

    test('voiceprint thresholds per call side and channel tag', () {
      double t(String? learnedOn, String? partition, {double base = 0.55}) =>
          p.knownSpeakerThreshold(
            _sp(learnedOn),
            partition: partition,
            sessionDeviceKey: 'builtIn|Mic',
            base: base,
          );
      // Wideband voiceprint heard on the telephone line: relaxed by 0.10.
      expect(t(null, 'remote'), closeTo(0.45, 1e-9));
      expect(t('builtIn|Mic', 'remote'), closeTo(0.45, 1e-9));
      // Telephone voiceprint on the telephone line: the base threshold.
      expect(t(kTelephoneVoiceDeviceKey, 'remote'), 0.55);
      // Telephone voiceprint heard in the room.
      expect(t(kTelephoneVoiceDeviceKey, 'local'), closeTo(0.45, 1e-9));
      // Same microphone: base; another microphone: the F18 relaxation.
      expect(t('builtIn|Mic', 'local'), 0.55);
      expect(t('usb|Jabra', 'local'), closeTo(0.50, 1e-9));
      expect(t('builtIn|Mic', null), 0.55);
      // Never below the floor.
      expect(t(null, 'remote', base: 0.42), closeTo(0.38, 1e-9));
      expect(t(null, 'remote', base: 0.30), 0.30);
    });

    test('call language hint', () {
      expect(resolveCallLanguageHint(null, 'ar'), 'ar');
      expect(resolveCallLanguageHint(null, null), isNull);
      expect(resolveCallLanguageHint(kCallLanguageAuto, 'ar'), isNull);
      expect(resolveCallLanguageHint('en', 'ar'), 'en');
    });

    test('session plan adjusts the engine request', () {
      const base = SessionEngineRequest(
        asrEngine: 'local',
        whisperModelId: 'w',
        languageHint: 'fr',
        farField: true,
      );
      final link = const PhoneCallSessionPlan(
        PhoneCallSetup(mode: PhoneCallMode.phoneLink, languageChoice: 'ar'),
      ).adjustRequest(base);
      expect(link.languageHint, 'ar');
      expect(link.vadConfig, same(p.phoneLinkVad));
      expect(link.farField, isTrue);
      expect(link.whisperModelId, 'w');
      final speaker = const PhoneCallSessionPlan(
        PhoneCallSetup(
          mode: PhoneCallMode.speakerphone,
          languageChoice: kCallLanguageAuto,
        ),
      ).adjustRequest(base);
      expect(speaker.languageHint, isNull);
      expect(speaker.vadConfig, same(p.speakerphoneVad));
      final keep = const PhoneCallSessionPlan(
        PhoneCallSetup(mode: PhoneCallMode.speakerphone),
      ).adjustRequest(base);
      expect(keep.languageHint, 'fr');
    });
  });

  group('band limiting', () {
    test('passes the telephone band and removes the rest', () {
      expect(_gainDb(1000), closeTo(0, 1.5));
      expect(_gainDb(2500), closeTo(0, 1.5));
      expect(_gainDb(60), lessThan(-30));
      expect(_gainDb(6000), lessThan(-25));
    });

    test('does not modify its input', () {
      final x = tones(100, [5000]);
      final copy = Float32List.fromList(x);
      p.bandLimit(x);
      expect(x, copy);
    });
  });

  group('bandwidth classification (speakerphone)', () {
    test('narrowband speech is the remote side', () {
      final nb = const TelephoneBandLimiter().process(
        speechLike(2000, seed: 3),
      );
      // A real codec leaves nothing above 4 kHz; the filter's skirt does.
      final lp = Float32List.fromList(nb);
      for (var k = 0; k < 2; k++) {
        for (final q in [0.5411961, 1.3065630]) {
          Biquad.lowPass(3400, q).processInPlace(lp);
        }
      }
      expect(p.classifyBandwidth(lp), CallSide.remote);
      expect(measureBandwidth(lp).highToBandDb, lessThan(-32));
    });

    test('wideband speech is the local side', () {
      final wb = speechLike(2000, seed: 4);
      expect(p.classifyBandwidth(wb), CallSide.local);
    });

    test('silence and in-between spectra stay unattributed', () {
      expect(p.classifyBandwidth(Float32List(32000)), isNull);
      final mid = add([
        tones(2000, [1000], amp: 0.3),
        tones(2000, [5000], amp: 0.01),
      ]);
      expect(measureBandwidth(mid).highToBandDb, inExclusiveRange(-32, -20));
      expect(p.classifyBandwidth(mid), isNull);
    });
  });
}
