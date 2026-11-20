import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/fusion_engine.dart';
import 'package:insato/features/multi_device/protocol.dart';

import 'sim.dart';

void main() {
  group('pairing code', () {
    test('random codes are valid Crockford base32', () {
      for (var i = 0; i < 50; i++) {
        final c = randomBase32(kPairingCodeLength);
        expect(normalizePairingCode(c), c);
      }
    });

    test('normalisation tolerates separators, case and look-alikes', () {
      expect(normalizePairingCode('k7qm-2xpa-9dtr'), 'K7QM2XPA9DTR');
      expect(normalizePairingCode(' K7QM 2XPA 9DTR '), 'K7QM2XPA9DTR');
      expect(normalizePairingCode('OIL0-0000-0000'), '011000000000');
      expect(normalizePairingCode('K7QM-2XPA-9DT'), isNull);
      expect(normalizePairingCode('K7QM-2XPA-9DTU'), isNull);
      expect(normalizePairingCode('كود'), isNull);
    });

    test('display format', () {
      expect(formatPairingCode('K7QM2XPA9DTR'), 'K7QM-2XPA-9DTR');
    });
  });

  group('JoinInfo', () {
    const info = JoinInfo(
      sessionId: 'AB12CD34',
      addresses: ['192.168.1.5', '10.0.0.2'],
      port: 47800,
      code: 'K7QM2XPA9DTR',
      hostName: 'حاسوب الأمانة',
    );

    test('QR payload round-trips', () {
      final uri = info.toUri();
      expect(uri, startsWith('insato://join?'));
      final back = JoinInfo.tryParse(uri)!;
      expect(back.sessionId, info.sessionId);
      expect(back.addresses, info.addresses);
      expect(back.port, 47800);
      expect(back.code, info.code);
      expect(back.hostName, info.hostName);
      expect(info.displayAddress, '192.168.1.5:47800');
    });

    test('foreign or malformed payloads are rejected', () {
      expect(JoinInfo.tryParse('https://example.com'), isNull);
      expect(JoinInfo.tryParse('insato://join?v=2&s=a&a=1.2.3.4&p=1&k=K7QM2XPA9DTR'),
          isNull);
      expect(JoinInfo.tryParse('insato://join?v=1&s=a&a=1.2.3.4&p=0&k=K7QM2XPA9DTR'),
          isNull);
      expect(JoinInfo.tryParse('insato://join?v=1&s=a&a=1.2.3.4&p=5&k=short'),
          isNull);
      expect(JoinInfo.tryParse('insato://join?v=1&s=a&a=&p=5&k=K7QM2XPA9DTR'),
          isNull);
      expect(JoinInfo.tryParse('%%%'), isNull);
    });
  });

  test('host:port parsing', () {
    expect(parseHostPort('192.168.1.5:47800'), ('192.168.1.5', 47800));
    expect(parseHostPort('[fe80::1]:9'), ('fe80::1', 9));
    expect(parseHostPort('pc.local', defaultPort: 5), ('pc.local', 5));
    expect(parseHostPort('pc.local'), isNull);
    expect(parseHostPort('1.2.3.4:99999'), isNull);
    expect(parseHostPort(''), isNull);
    expect(formatHostPort('fe80::1', 9), '[fe80::1]:9');
  });

  test('audio message round-trip', () {
    final samples = syntheticSpeech(1600);
    final m = encodeAudioMessage(
      GuestAudioFrame(
        seq: 7,
        startIndex: 123456789012,
        captureUs: -5,
        samples: samples,
      ),
    );
    final f = decodeAudioMessage(m);
    expect(f.seq, 7);
    expect(f.startIndex, 123456789012);
    expect(f.captureUs, -5);
    expect(f.samples.length, 1600);
    for (var i = 0; i < 1600; i++) {
      expect(f.samples[i], closeTo(samples[i], 1 / 16000));
    }
    expect(() => decodeAudioMessage(Uint8List(3)), throwsFormatException);
  });

  test('JSON messages and status', () {
    final m = encodeJsonMessage(MsgType.control, {'t': 'ping', 'id': 1});
    expect(m[0], MsgType.control);
    expect(decodeJsonBody(m), {'t': 'ping', 'id': 1});
    final s = GuestStatus.fromJson(
      const GuestStatus(battery: 54, charging: true, level: 0.25).toJson(),
    );
    expect(s.battery, 54);
    expect(s.charging, isTrue);
    expect(s.level, 0.25);
    final bad = GuestStatus.fromJson({'battery': 400, 'level': 'x'});
    expect(bad.battery, isNull);
    expect(bad.level, 0);
  });
}
