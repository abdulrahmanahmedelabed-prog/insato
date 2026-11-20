import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/multi_device/secure_channel.dart';

Uint8List _b(List<int> x) => Uint8List.fromList(x);

void main() {
  late SecureChannel host;
  late SecureChannel guest;

  setUp(() async {
    final key = await derivePairingKey('K7QM2XPA9DTR', iterations: 10);
    host = SecureChannel(pairingKey: key, isHost: true);
    guest = SecureChannel(pairingKey: key, isHost: false);
  });

  test('pairing key depends on the code', () async {
    final a = await derivePairingKey('K7QM2XPA9DTR', iterations: 10);
    final b = await derivePairingKey('K7QM2XPA9DTS', iterations: 10);
    expect(a.bytes, isNot(b.bytes));
    expect(a.bytes.length, 32);
  });

  test('handshake frames authenticate and keep direction', () {
    final f = guest.sealHandshake(_b([1, 2, 3]));
    expect(host.openHandshake(f), [1, 2, 3]);
    // A guest frame reflected back to a guest does not open.
    expect(guest.openHandshake(f), isNull);
    final tampered = Uint8List.fromList(f)..[f.length - 1] ^= 1;
    expect(host.openHandshake(tampered), isNull);
  });

  test('wrong pairing code cannot open', () async {
    final other = SecureChannel(
      pairingKey: await derivePairingKey('AAAAAAAAAAAA', iterations: 10),
      isHost: false,
    );
    expect(host.openHandshake(other.sealHandshake(_b([1]))), isNull);
  });

  test('session frames: counters, replay and reorder rejected', () async {
    final cn = secureRandomBytes(16), sn = secureRandomBytes(16);
    await host.establish(cn, sn);
    await guest.establish(cn, sn);
    final a = guest.seal(_b([10]));
    final b = guest.seal(_b([11]));
    expect(host.open(a), [10]);
    expect(host.open(a), isNull, reason: 'replay');
    expect(host.open(b), [11]);
    final c = guest.seal(_b([12]));
    final d = guest.seal(_b([13]));
    expect(host.open(d), [13]);
    expect(host.open(c), isNull, reason: 'older counter');
    // Host → guest uses the other key.
    final h = host.seal(_b([20]));
    expect(guest.open(h), [20]);
    expect(host.open(h), isNull);
  });

  test('session frames are bound to the connection nonces', () async {
    await host.establish(secureRandomBytes(16), secureRandomBytes(16));
    await guest.establish(secureRandomBytes(16), secureRandomBytes(16));
    expect(host.open(guest.seal(_b([1]))), isNull);
  });

  test('session seal before keys throws; garbage never opens', () {
    expect(() => guest.seal(_b([1])), throwsStateError);
    expect(host.open(_b([1, 2, 3])), isNull);
    expect(host.openHandshake(_b([])), isNull);
  });
}
