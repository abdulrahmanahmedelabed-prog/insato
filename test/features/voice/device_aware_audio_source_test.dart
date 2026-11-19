import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/audio/audio_capture_service.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/data/secure_settings.dart';
import 'package:insato/features/voice/device_aware_audio_source.dart';
import 'package:insato/features/voice/mic_capture.dart';
import 'package:insato/features/voice/voice_devices.dart';

import 'voice_fakes.dart';

const usb = InputDevice(id: '17', label: 'Jabra', type: InputDeviceType.usb);
const usb2 = InputDevice(id: '23', label: 'Jabra', type: InputDeviceType.usb);
const builtIn = InputDevice(
  id: '1',
  label: 'Built-in',
  type: InputDeviceType.builtIn,
);
const bt = InputDevice(
  id: 'bt',
  label: 'Buds',
  type: InputDeviceType.bluetoothSco,
);

void main() {
  late FakeMicFactory factory;
  late AppSettingsData settings;
  late RememberedInputDevice remembered;
  late DeviceAwareSessionAudioSource source;
  late List<AudioCaptureException> errors;
  late List<MicDeviceEvent> events;
  late List<StreamSubscription<Object?>> subs;

  DeviceAwareSessionAudioSource make({
    CapturePlatform platform = CapturePlatform.android,
  }) {
    final s = DeviceAwareSessionAudioSource(
      captureFactory: factory.call,
      loadSettings: () async => settings,
      loadRemembered: () async => remembered,
      platform: platform,
      pollInterval: const Duration(milliseconds: 20),
    );
    subs = [s.errors.listen(errors.add), s.deviceEvents.listen(events.add)];
    return s;
  }

  setUp(() {
    factory = FakeMicFactory(devices: const [builtIn, usb]);
    settings = const AppSettingsData();
    remembered = RememberedInputDevice.systemDefault;
    errors = [];
    events = [];
  });

  tearDown(() async {
    for (final s in subs) {
      await s.cancel();
    }
    await source.dispose();
  });

  test('default device: no selection, near-field options', () async {
    source = make();
    await source.start(archivePath: null);
    await Future<void>.delayed(Duration.zero);
    final mic = factory.recording!;
    expect(mic.startedWith, isNull);
    expect(source.activeDeviceKey, isNull);
    expect(factory.options.last.autoGainOnAndroid, isFalse);
    expect(events.single.kind, MicDeviceEventKind.started);
    expect(errors, isEmpty);
    await source.stop();
  });

  test('remembered device is selected (found again by key) and far field '
      'rebuilds the capture with AGC + NS', () async {
    factory.devices = const [builtIn, usb2];
    remembered = RememberedInputDevice(id: '17', key: voiceDeviceKey(usb));
    settings = const AppSettingsData(farFieldMode: true);
    source = make();
    await source.start(archivePath: '/tmp/x.wav');
    final mic = factory.recording!;
    expect(mic.startedWith, usb2);
    expect(mic.archivePath, '/tmp/x.wav');
    expect(source.activeDeviceKey, 'usb|Jabra');
    expect(source.farField, isTrue);
    expect(factory.options.last.autoGainOnAndroid, isTrue);
    expect(factory.options.last.noiseSuppress, isTrue);
    // The listing capture (near-field options) was replaced and released.
    expect(factory.made.first.disposed, isTrue);
    await source.stop();
  });

  test('frames, levels and states are forwarded across rebuilds', () async {
    source = make();
    final frames = <int>[];
    final sub = source.frames.listen((f) => frames.add(f.length));
    await source.start(archivePath: null);
    factory.recording!.emit(tone(100));
    await source.stop();
    settings = const AppSettingsData(farFieldMode: true);
    await source.start(archivePath: null);
    factory.recording!.emit(tone(50));
    await Future<void>.delayed(Duration.zero);
    expect(frames, [1600, 800]);
    expect(source.elapsed, const Duration(milliseconds: 50));
    await source.stop();
    await sub.cancel();
  });

  test('missing remembered device → default plus a warning', () async {
    remembered = RememberedInputDevice(id: '99', key: voiceDeviceKey(bt));
    source = make();
    await source.start(archivePath: null);
    await Future<void>.delayed(Duration.zero);
    expect(factory.recording!.startedWith, isNull);
    expect(errors.single.messageAr, contains('Buds'));
    expect(events.single.kind, MicDeviceEventKind.missingAtStart);
    await source.stop();
  });

  test('a device lost mid-take is reported once; capture goes on', () async {
    remembered = RememberedInputDevice(id: '17', key: voiceDeviceKey(usb));
    source = make();
    await source.start(archivePath: null);
    final mic = factory.recording!;
    await source.checkDevice();
    expect(source.fellBack, isFalse);
    mic.devices = const [builtIn];
    await source.checkDevice();
    await source.checkDevice();
    await Future<void>.delayed(Duration.zero);
    expect(source.fellBack, isTrue);
    expect(source.activeDeviceKey, isNull);
    expect(mic.started, isTrue);
    expect(errors, hasLength(1));
    expect(errors.single.messageAr, contains('Jabra'));
    expect(events.last.kind, MicDeviceEventKind.fellBack);
    await source.stop();
  });

  test('polling detects the loss on its own and stops on stop()', () async {
    remembered = RememberedInputDevice(id: '17', key: voiceDeviceKey(usb));
    source = make();
    await source.start(archivePath: null);
    final mic = factory.recording!;
    mic.devices = const [builtIn];
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(source.fellBack, isTrue);
    final calls = mic.listCalls;
    await source.stop();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(mic.listCalls, calls);
  });

  test('a failing device list is ignored while recording', () async {
    remembered = RememberedInputDevice(id: '17', key: voiceDeviceKey(usb));
    source = make();
    await source.start(archivePath: null);
    factory.recording!.listError = StateError('busy');
    await source.checkDevice();
    expect(source.fellBack, isFalse);
    expect(errors, isEmpty);
    await source.stop();
  });

  test('listing failure at start falls back to the remembered id', () async {
    remembered = RememberedInputDevice(id: '17', key: voiceDeviceKey(usb));
    source = make();
    final res = await source.resolveConfiguredDevice();
    expect(res.device!.id, '17');
    // Now the device list fails: the remembered id is still tried.
    factory.made.first.listError = StateError('x');
    final res2 = await source.resolveConfiguredDevice();
    expect(res2.device!.id, '17');
    expect(res2.device!.type, InputDeviceType.usb);
  });

  test('Bluetooth headset → Android SCO management', () async {
    factory.devices = const [builtIn, bt];
    remembered = RememberedInputDevice(id: 'bt', key: voiceDeviceKey(bt));
    source = make();
    await source.start(archivePath: null);
    expect(factory.options.last.androidManageBluetooth, isTrue);
    expect(factory.recording!.startedWith, bt);
    await source.stop();
  });

  test('permission and pause/resume delegate', () async {
    factory.permission = false;
    source = make();
    expect(await source.hasPermission(), isFalse);
    await source.pause();
    await source.resume();
    expect(await source.stop(), Duration.zero);
  });
}
