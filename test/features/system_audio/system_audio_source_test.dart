import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/features/system_audio/system_audio.dart';

import 'system_audio_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseSystemAudioEvent', () {
    test('audio packets', () {
      final e = parseSystemAudioEvent({
        'type': 'audio',
        'rate': 48000,
        'channels': 2,
        'samples': Float32List.fromList([0.5, -0.5]),
      });
      expect(e, isA<SystemAudioPacket>());
      final p = e! as SystemAudioPacket;
      expect(p.sampleRate, 48000);
      expect(p.channels, 2);
      expect(p.samples, [0.5, -0.5]);
      final fromList = parseSystemAudioEvent({
        'type': 'audio',
        'rate': 44100,
        'channels': 1,
        'samples': [0.25, 1],
      });
      expect((fromList! as SystemAudioPacket).samples, [0.25, 1.0]);
    });

    test('status events', () {
      expect(
        (parseSystemAudioEvent({'type': 'started'})! as SystemAudioStatus).kind,
        SystemAudioStatusKind.started,
      );
      expect(
        (parseSystemAudioEvent({'type': 'restarted'})! as SystemAudioStatus)
            .kind,
        SystemAudioStatusKind.restarted,
      );
      final err =
          parseSystemAudioEvent({'type': 'error', 'code': 'no_device'})!
              as SystemAudioStatus;
      expect(err.kind, SystemAudioStatusKind.error);
      expect(err.code, 'no_device');
    });

    test('garbage is ignored', () {
      expect(parseSystemAudioEvent(null), isNull);
      expect(parseSystemAudioEvent('audio'), isNull);
      expect(parseSystemAudioEvent({'type': 'other'}), isNull);
      expect(
        parseSystemAudioEvent({'type': 'audio', 'rate': 0, 'channels': 2}),
        isNull,
      );
      expect(
        parseSystemAudioEvent({
          'type': 'audio',
          'rate': 48000,
          'channels': 2,
          'samples': 'x',
        }),
        isNull,
      );
    });

    test('error codes map to Arabic messages', () {
      expect(systemAudioErrorMessage('no_device'), SystemAudioStrings.noDevice);
      expect(
        systemAudioErrorMessage('format'),
        SystemAudioStrings.unsupportedFormat,
      );
      expect(systemAudioErrorMessage('x'), SystemAudioStrings.captureProblem);
    });
  });

  group('MethodChannelSystemAudioPlatform', () {
    const control = MethodChannel(
      MethodChannelSystemAudioPlatform.controlChannelName,
    );
    const events = EventChannel(
      MethodChannelSystemAudioPlatform.eventChannelName,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(control, null);
      messenger.setMockStreamHandler(events, null);
    });

    test('calls the native methods', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(control, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'isSupported' => true,
          'start' => true,
          _ => null,
        };
      });
      final p = MethodChannelSystemAudioPlatform();
      expect(await p.isSupported(), isTrue);
      expect(await p.start(), isTrue);
      await p.stop();
      expect(calls, ['isSupported', 'start', 'stop']);
    });

    test('a missing plugin reads as unsupported', () async {
      final p = MethodChannelSystemAudioPlatform();
      expect(await p.isSupported(), isFalse);
      expect(await p.start(), isFalse);
      await p.stop();
    });

    test('platform errors read as failure', () async {
      messenger.setMockMethodCallHandler(control, (call) async {
        throw PlatformException(code: 'x');
      });
      final p = MethodChannelSystemAudioPlatform();
      expect(await p.isSupported(), isFalse);
      expect(await p.start(), isFalse);
      await p.stop();
    });

    test('decodes the event stream', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            sink
              ..success({'type': 'started'})
              ..success({'type': 'bogus'})
              ..success({
                'type': 'audio',
                'rate': 48000,
                'channels': 2,
                'samples': Float32List.fromList([0.5, 0.5]),
              })
              ..endOfStream();
          },
        ),
      );
      final got = await MethodChannelSystemAudioPlatform().events.toList();
      expect(got.length, 2);
      expect(got.first, isA<SystemAudioStatus>());
      expect(got.last, isA<SystemAudioPacket>());
    });
  });

  group('SystemAudioSource', () {
    test('converts packets to 16 kHz mono in the buffer', () async {
      final platform = FakeSystemAudioPlatform();
      final source = SystemAudioSource(platform: platform);
      await source.start();
      expect(source.isCapturing, isTrue);
      expect(platform.hasListener, isTrue);
      platform.emitAudio(sine(100, rate: 48000));
      await flushEvents();
      expect(source.packets, 1);
      // 100 ms at 16 kHz, minus what the resampler still holds.
      expect(source.buffer.length, inInclusiveRange(1500, 1600));
      await source.stop();
      expect(platform.stops, 1);
      expect(platform.hasListener, isFalse);
      expect(source.buffer.length, closeTo(1600, 2));
      await source.dispose();
    });

    test('start failure throws an Arabic error and stops listening', () async {
      final platform = FakeSystemAudioPlatform(startResult: false);
      final source = SystemAudioSource(platform: platform);
      await expectLater(
        source.start(),
        throwsA(
          isA<AudioCaptureException>().having(
            (e) => e.messageAr,
            'messageAr',
            SystemAudioStrings.startFailed,
          ),
        ),
      );
      expect(source.isCapturing, isFalse);
      expect(platform.hasListener, isFalse);

      platform
        ..startResult = true
        ..startError = StateError('boom');
      await expectLater(source.start(), throwsA(isA<AudioCaptureException>()));
      await source.dispose();
    });

    test('device change and errors become warnings, once each', () async {
      final platform = FakeSystemAudioPlatform();
      final source = SystemAudioSource(platform: platform);
      final warnings = <String>[];
      source.warnings.listen((e) => warnings.add(e.messageAr));
      await source.start();
      platform
        ..emit(const SystemAudioStatus(SystemAudioStatusKind.started))
        ..emit(
          const SystemAudioStatus(
            SystemAudioStatusKind.error,
            code: 'no_device',
          ),
        )
        ..emit(
          const SystemAudioStatus(
            SystemAudioStatusKind.error,
            code: 'no_device',
          ),
        )
        ..emit(const SystemAudioStatus(SystemAudioStatusKind.restarted))
        ..emit(
          const SystemAudioStatus(
            SystemAudioStatusKind.error,
            code: 'no_device',
          ),
        );
      await flushEvents();
      expect(warnings, [
        SystemAudioStrings.noDevice,
        SystemAudioStrings.deviceChanged,
        SystemAudioStrings.noDevice,
      ]);
      await source.dispose();
    });

    test('a device change with a new format keeps converting', () async {
      final platform = FakeSystemAudioPlatform();
      final source = SystemAudioSource(platform: platform);
      await source.start();
      platform
        ..emitAudio(sine(100, rate: 48000))
        ..emit(const SystemAudioStatus(SystemAudioStatusKind.restarted))
        ..emitAudio(sine(100, rate: 44100), rate: 44100, channels: 1);
      await flushEvents();
      await source.stop();
      expect(source.buffer.length, closeTo(3200, 4));
      await source.dispose();
    });

    test('isSupported is false when the platform throws', () async {
      final source = SystemAudioSource(platform: _ThrowingPlatform());
      expect(await source.isSupported(), isFalse);
      await source.dispose();
    });
  });
}

class _ThrowingPlatform extends FakeSystemAudioPlatform {
  @override
  Future<bool> isSupported() => Future.error(StateError('x'));
}
