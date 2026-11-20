import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/phone_call/channel_attribution.dart';
import 'package:insato/features/phone_call/phone_call_models.dart';

import 'call_signals.dart';

void main() {
  const ms = 3000;
  final silence = Float32List(ms * 16);

  group('attributeCallSegment', () {
    test('remote speech heard through the PC speakers is the remote side '
        '(microphone bleed suppressed)', () {
      final remote = speechLike(ms, seed: 1);
      final mic = add([echo(remote, gain: 0.3, delayMs: 60), noise(ms)]);
      final a = attributeCallSegment(mic, remote);
      expect(a.side, CallSide.remote);
      expect(a.bleedSuppressed, isTrue);
      expect(a.overlap, isFalse);
      expect(a.micActiveMs, greaterThan(1000));
      expect(a.localActiveMs, lessThan(200));
      expect(a.echoCorrelation, greaterThan(0.8));
      expect(a.echoLagMs, inInclusiveRange(50, 70));
    });

    test('the echo may precede the loopback on the session timeline', () {
      // The loopback jitter buffer delays the remote channel more than the
      // acoustic path delays the echo.
      final remote = speechLike(ms, seed: 3);
      final mic = add([echo(remote, gain: 0.5, delayMs: -90), noise(ms)]);
      final a = attributeCallSegment(mic, remote);
      expect(a.side, CallSide.remote);
      expect(a.bleedSuppressed, isTrue);
      expect(a.echoLagMs, inInclusiveRange(-100, -80));
    });

    test('microphone speech with a silent line is the local side', () {
      final mic = add([speechLike(ms, seed: 2), noise(ms)]);
      final a = attributeCallSegment(mic, silence);
      expect(a.side, CallSide.local);
      expect(a.bleedSuppressed, isFalse);
      expect(a.remoteActiveMs, 0);
      expect(a.localActiveMs, greaterThan(1000));
    });

    test('headphones: remote speech and a quiet microphone is remote, '
        'without bleed', () {
      final remote = speechLike(ms, seed: 4);
      final a = attributeCallSegment(noise(ms), remote);
      expect(a.side, CallSide.remote);
      expect(a.bleedSuppressed, isFalse);
      expect(a.micActiveMs, 0);
    });

    test('local speech over the remote echo is detected (double talk)', () {
      final remote = speechLike(ms, seed: 5);
      final local = speechLike(ms, seed: 6, amp: 0.5);
      final mic = add([echo(remote, gain: 0.2, delayMs: 40), local, noise(ms)]);
      final a = attributeCallSegment(mic, remote);
      expect(a.overlap, isTrue);
      expect(a.localActiveMs, greaterThan(500));
      expect(a.remoteActiveMs, greaterThan(500));
      expect(
        a.side,
        a.remoteActiveMs >= a.localActiveMs ? CallSide.remote : CallSide.local,
      );
    });

    test('a short local interjection in a long remote turn stays remote', () {
      final remote = speechLike(ms, seed: 7);
      final local = Float32List(ms * 16)
        ..setAll(16000, speechLike(300, seed: 8, amp: 0.6));
      final mic = add([echo(remote, gain: 0.2, delayMs: 50), local, noise(ms)]);
      final a = attributeCallSegment(mic, remote);
      expect(a.side, CallSide.remote);
      expect(a.localActiveMs, lessThan(a.remoteActiveMs));
    });

    test('loud remote audio without correlation does not hide local '
        'speech', () {
      final mic = add([speechLike(ms, seed: 9), noise(ms)]);
      final remote = speechLike(600, seed: 10);
      final a = attributeCallSegment(
        mic,
        Float32List(ms * 16)..setAll(0, remote),
      );
      expect(a.side, CallSide.local);
      expect(a.bleedSuppressed, isFalse);
    });

    test('empty input is local and inactive', () {
      final a = attributeCallSegment(Float32List(0), Float32List(0));
      expect(a.side, CallSide.local);
      expect(a.localActiveMs, 0);
      expect(a.remoteActiveMs, 0);
    });
  });

  group('NoiseFloorTracker', () {
    test('follows quiet audio down and rises slowly during speech', () {
      final t = NoiseFloorTracker();
      t.add(noise(1000, amp: 0.001));
      final quiet = t.floorDbfs;
      expect(quiet, lessThan(-60));
      t.add(speechLike(2000, amp: 0.3));
      expect(t.floorDbfs, lessThan(quiet + 10));
      t.reset();
      expect(t.floorDbfs, t.initialDbfs);
    });
  });
}
