import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/voice/voice_devices.dart';
import 'package:record/record.dart' show AndroidAudioSource;

Speaker speaker({String? device}) => Speaker(
  id: 's1',
  name: 'سارة',
  colorValue: 0xFF000000,
  isNamedByUser: true,
  createdAt: DateTime(2026),
  voiceDevice: device,
);

const usb = InputDevice(
  id: '17',
  label: 'Jabra Speak 510',
  type: InputDeviceType.usb,
);
const usbReconnected = InputDevice(
  id: '23',
  label: 'Jabra Speak 510',
  type: InputDeviceType.usb,
);
const builtIn = InputDevice(
  id: '1',
  label: 'Built-in Microphone',
  type: InputDeviceType.builtIn,
);
const headset = InputDevice(
  id: 'bt:1',
  label: 'AirPods',
  type: InputDeviceType.bluetoothSco,
);

void main() {
  group('device keys', () {
    test('type and label, null for the default', () {
      expect(voiceDeviceKey(usb), 'usb|Jabra Speak 510');
      expect(voiceDeviceKey(null), isNull);
      expect(
        voiceDeviceKey(const InputDevice(id: 'x', label: '  ')),
        'unknown|x',
      );
      expect(voiceDeviceKey(const InputDevice(id: ' ', label: '')), isNull);
    });

    test('parse round trip and legacy labels', () {
      final parts = parseVoiceDeviceKey(voiceDeviceKey(headset))!;
      expect(parts.type, InputDeviceType.bluetoothSco);
      expect(parts.label, 'AirPods');
      final legacy = parseVoiceDeviceKey('Some Mic|with bar')!;
      expect(legacy.type, InputDeviceType.unknown);
      expect(legacy.label, 'Some Mic|with bar');
      expect(parseVoiceDeviceKey(null), isNull);
      expect(parseVoiceDeviceKey('  '), isNull);
    });
  });

  test('bluetooth / narrow-band / external classification', () {
    expect(isBluetoothInput(InputDeviceType.bluetoothSco), isTrue);
    expect(isBluetoothInput(InputDeviceType.bluetoothA2dp), isTrue);
    expect(isBluetoothInput(InputDeviceType.usb), isFalse);
    expect(isNarrowBandInput(InputDeviceType.bluetoothSco), isTrue);
    expect(isNarrowBandInput(InputDeviceType.bluetoothLe), isTrue);
    expect(isNarrowBandInput(InputDeviceType.wiredHeadset), isFalse);
    expect(isExternalInput(InputDeviceType.builtIn), isFalse);
    expect(isExternalInput(InputDeviceType.unknown), isFalse);
    expect(isExternalInput(InputDeviceType.usb), isTrue);
  });

  group('resolveInputDevice', () {
    test('nothing remembered → default, not missing', () {
      final r = resolveInputDevice(const [usb, builtIn]);
      expect(r.device, isNull);
      expect(r.missing, isFalse);
    });

    test('finds by id first', () {
      final r = resolveInputDevice(
        const [builtIn, usb],
        storedId: '17',
        storedKey: 'usb|Other',
      );
      expect(r.device, usb);
    });

    test('finds a reconnected device by key', () {
      final r = resolveInputDevice(
        const [builtIn, usbReconnected],
        storedId: '17',
        storedKey: voiceDeviceKey(usb),
      );
      expect(r.device, usbReconnected);
      expect(r.missing, isFalse);
    });

    test('absent device → default with missing', () {
      final r = resolveInputDevice(
        const [builtIn],
        storedId: '17',
        storedKey: voiceDeviceKey(usb),
      );
      expect(r.device, isNull);
      expect(r.missing, isTrue);
    });

    test('presence check accepts id or key', () {
      expect(isDevicePresent(const [usbReconnected], usb), isTrue);
      expect(isDevicePresent(const [builtIn], usb), isFalse);
    });
  });

  group('capture options', () {
    test('far field enables AGC + NS on Android only', () {
      final android = micCaptureOptions(
        farField: true,
        platform: CapturePlatform.android,
      );
      expect(android.autoGainOnAndroid, isTrue);
      expect(android.noiseSuppress, isTrue);
      expect(android.androidAudioSource, AndroidAudioSource.voiceRecognition);
      for (final p in [CapturePlatform.ios, CapturePlatform.windows]) {
        final o = micCaptureOptions(farField: true, platform: p);
        expect(o.autoGainOnAndroid, isFalse);
        expect(o.noiseSuppress, isFalse);
      }
      final near = micCaptureOptions(
        farField: false,
        platform: CapturePlatform.android,
      );
      expect(near.autoGainOnAndroid, isFalse);
      expect(near.noiseSuppress, isFalse);
    });

    test('a Bluetooth headset lets Android manage SCO', () {
      expect(
        micCaptureOptions(
          farField: false,
          device: headset,
          platform: CapturePlatform.android,
        ).androidManageBluetooth,
        isTrue,
      );
      expect(
        micCaptureOptions(
          farField: false,
          device: usb,
          platform: CapturePlatform.android,
        ).androidManageBluetooth,
        isFalse,
      );
    });

    test('options key tells configurations apart', () {
      final a = micCaptureOptions(
        farField: true,
        platform: CapturePlatform.android,
      );
      final b = micCaptureOptions(
        farField: false,
        platform: CapturePlatform.android,
      );
      expect(micCaptureOptionsKey(a), isNot(micCaptureOptionsKey(b)));
      expect(
        micCaptureOptionsKey(a),
        micCaptureOptionsKey(
          micCaptureOptions(farField: true, platform: CapturePlatform.android),
        ),
      );
    });

    test('far-field VAD is more sensitive', () {
      final near = vadConfigFor(farField: false);
      final far = vadConfigFor(farField: true);
      expect(far.threshold, lessThan(near.threshold));
      expect(far.minSpeechDuration, lessThan(near.minSpeechDuration));
      expect(far.minSilenceDuration, greaterThan(near.minSilenceDuration));
    });
  });

  group('voiceprint device matching', () {
    test('same device keeps the threshold, another relaxes it', () {
      final key = voiceDeviceKey(usb);
      expect(
        knownSpeakerThresholdFor(
          speaker(device: key),
          sessionDeviceKey: key,
          base: 0.55,
        ),
        0.55,
      );
      expect(
        knownSpeakerThresholdFor(speaker(), sessionDeviceKey: null, base: 0.55),
        0.55,
      );
      expect(
        knownSpeakerThresholdFor(speaker(), sessionDeviceKey: key, base: 0.55),
        closeTo(0.50, 1e-9),
      );
      expect(
        knownSpeakerThresholdFor(
          speaker(device: key),
          sessionDeviceKey: null,
          base: 0.55,
        ),
        closeTo(0.50, 1e-9),
      );
    });

    test('relaxation never goes below the floor (or raises a low base)', () {
      expect(
        knownSpeakerThresholdFor(
          speaker(),
          sessionDeviceKey: 'usb|X',
          base: 0.42,
        ),
        0.4,
      );
      expect(
        knownSpeakerThresholdFor(
          speaker(),
          sessionDeviceKey: 'usb|X',
          base: 0.38,
        ),
        0.38,
      );
    });

    test('blank keys count as the default microphone', () {
      expect(isVoiceDeviceMismatch(speaker(device: ' '), null), isFalse);
      expect(isVoiceDeviceMismatch(speaker(device: 'usb|A'), 'usb|A'), isFalse);
    });

    test('device tag follows the microphone once it dominates', () {
      expect(
        voiceDeviceAfterLearning(
          currentDevice: null,
          sessionDeviceKey: 'usb|A',
          previousCount: 0,
          learnedCount: 3,
        ),
        'usb|A',
      );
      expect(
        voiceDeviceAfterLearning(
          currentDevice: 'builtIn|Mic',
          sessionDeviceKey: 'usb|A',
          previousCount: 40,
          learnedCount: 10,
        ),
        'builtIn|Mic',
      );
      expect(
        voiceDeviceAfterLearning(
          currentDevice: 'builtIn|Mic',
          sessionDeviceKey: 'usb|A',
          previousCount: 10,
          learnedCount: 10,
        ),
        'usb|A',
      );
      // Old evidence counts at most up to the cap.
      expect(
        voiceDeviceAfterLearning(
          currentDevice: 'builtIn|Mic',
          sessionDeviceKey: 'usb|A',
          previousCount: 5000,
          learnedCount: 200,
        ),
        'usb|A',
      );
      expect(
        voiceDeviceAfterLearning(
          currentDevice: 'usb|A',
          sessionDeviceKey: 'usb|A',
          previousCount: 10,
          learnedCount: 0,
        ),
        'usb|A',
      );
      expect(
        voiceDeviceAfterLearning(
          currentDevice: 'builtIn|Mic',
          sessionDeviceKey: 'usb|A',
          previousCount: 10,
          learnedCount: 0,
        ),
        'builtIn|Mic',
      );
    });
  });
}
