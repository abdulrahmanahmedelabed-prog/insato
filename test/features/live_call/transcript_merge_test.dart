// Live call: ordering of the combined transcript, pending → final, time
// correction, echo detection and remote speaker names.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/live_call/call_meeting_writer.dart'
    show remoteSpeakerName;
import 'package:insato/features/live_call/transcript_merge.dart';

LiveLine _l(
  String id,
  LineOrigin o,
  int atMs, {
  String text = '',
  bool pending = false,
  int? peerAtMs,
  bool provisional = false,
}) => LiveLine(
  id: id,
  origin: o,
  atUs: atMs * 1000,
  durMs: 1500,
  text: text,
  pending: pending,
  peerAtUs: peerAtMs == null ? null : peerAtMs * 1000,
  provisionalTime: provisional,
);

void main() {
  test('lines are ordered by synchronised time, local first on ties', () {
    final b = LiveTranscriptBook()
      ..upsert(_l('r1', LineOrigin.remote, 3000, text: 'ج'))
      ..upsert(_l('l1', LineOrigin.local, 1000, text: 'أ'))
      ..upsert(_l('r0', LineOrigin.remote, 1000, text: 'ب'))
      ..upsert(_l('l2', LineOrigin.local, 5000, text: 'د'));
    expect(b.lines.map((l) => l.id), ['l1', 'r0', 'r1', 'l2']);
  });

  test('a final line replaces its pending placeholder, never the reverse', () {
    final b = LiveTranscriptBook()
      ..upsert(_l('x', LineOrigin.local, 0, pending: true));
    expect(b.lines.single.pending, isTrue);
    b.upsert(_l('x', LineOrigin.local, 0, text: 'نص'));
    expect(b.lines.single.text, 'نص');
    b.upsert(_l('x', LineOrigin.local, 0, pending: true));
    expect(b.lines.single.pending, isFalse);
    expect(b.remove(LineOrigin.local, 'x'), isTrue);
    expect(b.length, 0);
    // Same id on both origins are different lines.
    b
      ..upsert(_l('y', LineOrigin.local, 0, text: 'a'))
      ..upsert(_l('y', LineOrigin.remote, 0, text: 'b'));
    expect(b.length, 2);
  });

  test('provisional remote times are corrected with the clock estimate', () {
    final b = LiveTranscriptBook()
      ..upsert(
        _l(
          'r',
          LineOrigin.remote,
          9000,
          text: 'x',
          peerAtMs: 15000,
          provisional: true,
        ),
      )
      ..upsert(_l('l', LineOrigin.local, 9500, text: 'y'));
    expect(b.lines.first.id, 'r');
    // Peer clock is 5 s ahead: 15 s there = 10 s here.
    final fixed = b.fixProvisional((peerUs) => peerUs - 5000000);
    expect(fixed.single.atUs, 10000000);
    expect(fixed.single.provisionalTime, isFalse);
    expect(b.lines.map((l) => l.id), ['l', 'r']);
    expect(b.fixProvisional((u) => u), isEmpty);
  });

  test('the book keeps at most maxLines lines', () {
    final b = LiveTranscriptBook(maxLines: 3);
    for (var i = 0; i < 5; i++) {
      b.upsert(_l('$i', LineOrigin.local, i * 1000, text: 't'));
    }
    expect(b.lines.map((l) => l.id), ['2', '3', '4']);
  });

  group('echo', () {
    test('normalisation ignores diacritics, hamza forms and punctuation', () {
      expect(
        normalizeForEcho('إِنَّ الاجتماعَ، مؤجّلٌ!'),
        normalizeForEcho('ان الاجتماع مؤجل'),
      );
      expect(textSimilarity('اتفقنا على الموعد', 'اتفقنا علي الموعد'), 1.0);
      expect(
        textSimilarity('سنرسل التقرير غدا', 'سنرسل التقرير غدًا صباحًا'),
        greaterThan(0.6),
      );
      expect(
        textSimilarity('سنرسل التقرير غدا', 'الميزانية لم تعتمد بعد'),
        lessThan(0.3),
      );
      expect(textSimilarity('', 'x'), 0);
      // One differing word in a short sentence is not an echo.
      expect(
        isEchoOf(
          _l('l', LineOrigin.local, 10400, text: 'كلام رقم واحد'),
          _l('r', LineOrigin.remote, 10000, text: 'كلام رقم اثنان'),
          localIsCallee: true,
        ),
        isFalse,
      );
    });

    final remote = _l(
      'r',
      LineOrigin.remote,
      10000,
      text: 'سنرسل التقرير إلى اللجنة غدا',
    );

    test('a later similar local line is an echo', () {
      final local = _l(
        'l',
        LineOrigin.local,
        10400,
        text: 'سنرسل التقرير الى اللجنه غدا',
      );
      expect(isEchoOf(local, remote, localIsCallee: false), isTrue);
      // The remote original is never an echo of the later local copy.
      final asRemote = _l('l', LineOrigin.remote, 10400, text: local.text);
      final asLocal = _l('r', LineOrigin.local, 10000, text: remote.text);
      expect(isEchoOf(asLocal, asRemote, localIsCallee: true), isFalse);
    });

    test('ties are decided by role, so only one side drops', () {
      final local = _l('l', LineOrigin.local, 10050, text: remote.text);
      expect(isEchoOf(local, remote, localIsCallee: true), isTrue);
      expect(isEchoOf(local, remote, localIsCallee: false), isFalse);
    });

    test('different words, far times, short or pending lines are kept', () {
      expect(
        isEchoOf(
          _l('l', LineOrigin.local, 10400, text: 'نعم أوافق على ذلك تماما'),
          remote,
          localIsCallee: true,
        ),
        isFalse,
      );
      expect(
        isEchoOf(
          _l('l', LineOrigin.local, 16000, text: remote.text),
          remote,
          localIsCallee: true,
        ),
        isFalse,
      );
      expect(
        isEchoOf(
          _l('l', LineOrigin.local, 10400, text: 'نعم أوافق'),
          _l('r', LineOrigin.remote, 10000, text: 'نعم أوافق'),
          localIsCallee: true,
        ),
        isFalse,
      );
      expect(
        isEchoOf(
          _l('l', LineOrigin.local, 10400, pending: true),
          remote,
          localIsCallee: true,
        ),
        isFalse,
      );
    });
  });

  test('remote speaker names are namespaced unless the peer knows them', () {
    expect(remoteSpeakerName('أحمد', 'هاتف سارة'), 'أحمد');
    expect(remoteSpeakerName('متحدث 2', 'هاتف سارة'), 'متحدث 2 (هاتف سارة)');
    expect(remoteSpeakerName('', 'هاتف سارة'), 'متحدث (هاتف سارة)');
    expect(remoteSpeakerName('متحدث 1', ''), 'متحدث 1 (الطرف الآخر)');
  });
}
