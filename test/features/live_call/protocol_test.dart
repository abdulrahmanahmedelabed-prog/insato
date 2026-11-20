// Live call: codes / invites / key derivation, relay frames, sealed call
// messages, SDP fingerprints, MACs, safety code, data-channel codec.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart' show SegmentKind;
import 'package:insato/features/live_call/call_code.dart';
import 'package:insato/features/live_call/call_settings.dart';
import 'package:insato/features/live_call/data_messages.dart';
import 'package:insato/features/live_call/peer_transport.dart';
import 'package:insato/features/live_call/signaling_client.dart';
import 'package:insato/features/live_call/signaling_protocol.dart';
import 'package:insato/features/live_call/webrtc_peer_transport.dart';

import 'fakes.dart';

void main() {
  group('call codes and invites', () {
    test('new codes are 12 Crockford characters and round-trip', () {
      final code = newCallCode();
      expect(code, hasLength(kCallCodeLength));
      expect(normalizePairingCode(formatPairingCode(code)), code);
      final invite = CallInvite(
        code: code,
        signalingUrl: 'wss://relay.example.com',
        callerName: 'هاتف أحمد',
      );
      final back = CallInvite.tryParse(invite.toUri())!;
      expect(back.code, code);
      expect(back.signalingUrl, 'wss://relay.example.com');
      expect(back.callerName, 'هاتف أحمد');
    });

    test('typed codes are accepted with separators and look-alikes', () {
      expect(CallInvite.tryParse('k7qm-2xpa-9dtr')!.code, 'K7QM2XPA9DTR');
      expect(CallInvite.tryParse('K7QM 2XPA 9DTO')!.code, 'K7QM2XPA9DT0');
      expect(CallInvite.tryParse('K7QM2XPA9DT'), isNull);
      expect(CallInvite.tryParse('insato://join?v=1&k=K7QM2XPA9DTR'), isNull);
      expect(CallInvite.tryParse('insato://call?v=2&k=K7QM2XPA9DTR'), isNull);
      expect(
        CallInvite.tryParse('insato://call?v=1&k=K7QM2XPA9DTR&u=ftp://x'),
        isNull,
      );
    });

    test('signaling URLs are normalised', () {
      expect(normalizeSignalingUrl('relay.example.com'), 'wss://relay.example.com');
      expect(normalizeSignalingUrl('https://r.example/ws'), 'wss://r.example/ws');
      expect(normalizeSignalingUrl('ws://127.0.0.1:8080'), 'ws://127.0.0.1:8080');
      expect(normalizeSignalingUrl(''), isNull);
      expect(normalizeSignalingUrl('ftp://x'), isNull);
      expect(normalizeSignalingUrl('wss://'), isNull);
      expect(
        relayUrlForRoom('wss://r.example/ws?x=1', 'ab'),
        'wss://r.example/ws?x=1&room=ab',
      );
    });

    test('keys: deterministic per code, distinct per code, room is hex', () async {
      final a = await deriveCallKeys('K7QM2XPA9DTR', iterations: 10);
      final b = await deriveCallKeys('K7QM2XPA9DTR', iterations: 10);
      final c = await deriveCallKeys('K7QM2XPA9DT0', iterations: 10);
      expect(a.roomId, b.roomId);
      expect(isValidRoomId(a.roomId), isTrue);
      expect(a.roomId, isNot(c.roomId));
      expect(a.callKey.bytes, b.callKey.bytes);
      expect(a.callKey.bytes, isNot(c.callKey.bytes));
      // The room id never reveals the key.
      expect(a.roomId, isNot(hexOf(a.callKey.bytes)));
    });
  });

  group('relay frames', () {
    test('round-trip', () {
      final room = 'a' * 64;
      final frames = <RelayFrame>[
        RelayJoin(room),
        const RelayJoined(1),
        const RelayPeerEvent(joined: true),
        const RelayPeerEvent(joined: false),
        RelayData(Uint8List.fromList([1, 2, 3])),
        const RelayPing(),
        const RelayPong(),
        const RelayError('full'),
      ];
      for (final f in frames) {
        final back = RelayFrame.decode(f.encode());
        expect(back.runtimeType, f.runtimeType);
        expect(back!.encode(), f.encode());
      }
    });

    test('malformed frames are rejected', () {
      expect(RelayFrame.decode('nope'), isNull);
      expect(RelayFrame.decode('{"t":"join","room":"xyz"}'), isNull);
      expect(RelayFrame.decode('{"t":"relay","d":"%%%"}'), isNull);
      expect(RelayFrame.decode('{"t":"what"}'), isNull);
      expect(RelayFrame.decode(42), isNull);
    });
  });

  group('call messages', () {
    test('hello / welcome / offer / ice / bye round-trip', () {
      final hello = CallMessage.decode(
        CallMessage.hello(
          clientNonce: List.filled(16, 7),
          name: 'ح',
          platform: 'android',
        ).encode(),
      )!;
      expect(hello.type, 'hello');
      expect(hello.bytes('cn'), List.filled(16, 7));
      expect(hello.str('name'), 'ح');
      final ice = CallMessage.decode(
        CallMessage.ice(
          const IceCandidateData(
            candidate: 'candidate:1 1 udp 1 1.2.3.4 5 typ relay',
            sdpMid: '0',
            sdpMLineIndex: 0,
          ),
        ).encode(),
      )!;
      expect(ice.candidate!.isRelay, isTrue);
      expect(ice.candidate!.sdpMid, '0');
      expect(CallMessage.decode(CallMessage.offer('x').encode())!.str('sdp'), 'x');
      expect(CallMessage.decode(CallMessage.bye('r').encode())!.str('reason'), 'r');
      expect(CallMessage.decode(utf8.encode('[1]')), isNull);
    });
  });

  group('fingerprints, MACs and the safety code', () {
    const fp1 = 'AB:CD';
    test('fingerprints are extracted and normalised', () {
      final sdp = fakeSdp('offer', 'ab:cd');
      expect(sdpFingerprints(sdp), ['sha-256 AB:CD']);
      expect(sdpFingerprint(sdp), 'sha-256 AB:CD');
      final two = '$sdp\r\na=fingerprint:sha-256 EE:FF\r\n';
      expect(sdpFingerprint(two), isNull);
      expect(sdpFingerprint('v=0'), isNull);
      // Same fingerprint at session and media level counts once.
      expect(sdpFingerprint('$sdp\r\na=fingerprint:SHA-256 AB:CD'), isNotNull);
    });

    test('MACs bind key, role and both fingerprints', () async {
      final k = (await deriveCallKeys('K7QM2XPA9DTR', iterations: 10)).callKey;
      final other =
          (await deriveCallKeys('K7QM2XPA9DT0', iterations: 10)).callKey;
      final m = await fingerprintMac(
        callKey: k,
        role: 'caller',
        own: fp1,
        peer: 'EF',
      );
      expect(
        bytesEqual(
          m,
          await fingerprintMac(callKey: k, role: 'caller', own: fp1, peer: 'EF'),
        ),
        isTrue,
      );
      for (final variant in [
        fingerprintMac(callKey: k, role: 'callee', own: fp1, peer: 'EF'),
        fingerprintMac(callKey: k, role: 'caller', own: 'EF', peer: fp1),
        fingerprintMac(callKey: other, role: 'caller', own: fp1, peer: 'EF'),
      ]) {
        expect(bytesEqual(m, await variant), isFalse);
      }
      expect(bytesEqual([1, 2], [1, 2, 3]), isFalse);
    });

    test('safety code is symmetric and changes with a certificate', () async {
      final k = (await deriveCallKeys('K7QM2XPA9DTR', iterations: 10)).callKey;
      final a = await safetyCode(callKey: k, fingerprintA: 'A', fingerprintB: 'B');
      final b = await safetyCode(callKey: k, fingerprintA: 'B', fingerprintB: 'A');
      final c = await safetyCode(callKey: k, fingerprintA: 'A', fingerprintB: 'C');
      expect(a, b);
      expect(a, matches(RegExp(r'^\d{3} \d{3}$')));
      expect(a, isNot(c));
    });
  });

  group('data-channel codec', () {
    test('every message round-trips', () {
      final msgs = <CallDataMessage>[
        AuthMessage(fingerprint: 'sha-256 AB', mac: Uint8List.fromList([1, 2])),
        const PingMessage(5),
        const PongMessage(t1: 1, t2: 2, t3: 3),
        const PendingLineMessage(id: 'p', atUs: 10, durMs: 20, sentUs: 30),
        const LineMessage(
          id: 'l',
          atUs: 10,
          durMs: 2000,
          sentUs: 30,
          text: 'نص عربي',
          speakerKey: 's1',
          speakerName: 'أحمد',
          language: 'ar',
          kind: SegmentKind.unintelligible,
          confidence: 0.4,
        ),
        const DropLineMessage('l'),
        const ActivityMessage(speaking: true, level: 0.5),
        const MuteMessage(true),
        const ByeMessage('hangup'),
      ];
      for (final m in msgs) {
        final back = CallDataMessage.decode(m.encode())!;
        expect(back.runtimeType, m.runtimeType);
        expect(back.encode(), m.encode());
      }
      final line = CallDataMessage.decode(msgs[4].encode()) as LineMessage;
      expect(line.kind, SegmentKind.unintelligible);
      expect(line.speakerName, 'أحمد');
    });

    test('malformed or oversized messages are rejected', () {
      expect(CallDataMessage.decode('{"t":"seg","id":"x"}'), isNull);
      expect(CallDataMessage.decode('{"t":"ping"}'), isNull);
      expect(CallDataMessage.decode('not json'), isNull);
      expect(CallDataMessage.decode('{"t":"zzz"}'), isNull);
      final long = jsonEncode({
        't': 'seg',
        'id': 'x',
        'at': 1,
        'dur': 1,
        'text': 'a' * (kMaxLineTextLength + 1),
      });
      expect(CallDataMessage.decode(long), isNull);
      // Levels are clamped.
      final act =
          CallDataMessage.decode('{"t":"act","on":true,"lvl":7}')
              as ActivityMessage;
      expect(act.level, 1.0);
    });
  });

  group('peer configuration and stats', () {
    test('STUN by default; TURN with credentials and relay-only', () {
      final plain = peerConfigFor(const LiveCallSettings());
      expect(plain.hasTurn, isFalse);
      expect(plain.toRtcConfiguration()['iceTransportPolicy'], 'all');
      final turn = peerConfigFor(
        const LiveCallSettings(
          turnUrl: 'turn:t.example:3478, turns:t.example:5349, junk',
          turnUsername: 'u',
          relayOnly: true,
        ),
        turnCredential: 'secret',
      );
      expect(turn.hasTurn, isTrue);
      final rtc = turn.toRtcConfiguration();
      expect(rtc['iceTransportPolicy'], 'relay');
      final servers = rtc['iceServers']! as List;
      expect(servers, hasLength(2));
      expect((servers[0] as Map)['urls'], [kDefaultStunUrl]);
      expect((servers[1] as Map)['urls'], [
        'turn:t.example:3478',
        'turns:t.example:5349',
      ]);
      expect((servers[1] as Map)['credential'], 'secret');
      // Relay-only without TURN would never connect: ignored.
      expect(
        peerConfigFor(const LiveCallSettings(relayOnly: true))
            .toRtcConfiguration()['iceTransportPolicy'],
        'all',
      );
    });

    test('W3C stats are parsed', () {
      final s = parseWebRtcStats([
        ('local-candidate', {'id': 'L', 'candidateType': 'relay'}),
        ('remote-candidate', {'id': 'R', 'candidateType': 'srflx'}),
        (
          'candidate-pair',
          {
            'id': 'P',
            'state': 'succeeded',
            'nominated': true,
            'currentRoundTripTime': 0.12,
            'localCandidateId': 'L',
            'remoteCandidateId': 'R',
          },
        ),
        (
          'inbound-rtp',
          {'kind': 'audio', 'packetsLost': 5, 'packetsReceived': 95, 'jitter': 0.01},
        ),
      ]);
      expect(s.rttMs, closeTo(120, 0.01));
      expect(s.relayed, isTrue);
      expect(s.packetLossPercent, closeTo(5, 0.01));
      expect(s.jitterMs, closeTo(10, 0.01));
      expect(parseWebRtcStats(const []).rttMs, isNull);
    });
  });

  test('settings JSON round-trips', () {
    const s = LiveCallSettings(
      signalingUrl: 'wss://a',
      turnUrl: 'turn:b',
      turnUsername: 'u',
      relayOnly: true,
      deviceName: 'ح',
      consentAcknowledged: true,
    );
    final back = LiveCallSettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(back.toJson(), s.toJson());
    expect(back.effectiveSignalingUrl, 'wss://a');
    expect(LiveCallSettings.fromJson('x').consentAcknowledged, isFalse);
  });
}
