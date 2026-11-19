import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:katib/minutes/claude_client.dart';

void main() {
  group('SseParser', () {
    test('parses events split at every possible chunk boundary', () {
      const body =
          'event: a\ndata: {"x":1}\n\n'
          'event: b\r\ndata: line1\r\ndata: line2\r\n\r\n'
          ': comment\n'
          'data: plain\n\n';
      for (var split = 0; split <= body.length; split++) {
        final p = SseParser();
        final events = [
          ...p.add(body.substring(0, split)),
          ...p.add(body.substring(split)),
          ...p.close(),
        ];
        expect(events.map((e) => e.event), [
          'a',
          'b',
          'message',
        ], reason: 'split at $split');
        expect(events[0].data, '{"x":1}');
        expect(events[1].data, 'line1\nline2');
        expect(events[2].data, 'plain');
      }
    });

    test('handles one character at a time with CRLF and bare CR', () {
      const body =
          'event: x\r\ndata: 1\r\r'
          'data:no-space\n\n';
      final p = SseParser();
      final events = <SseEvent>[];
      for (final ch in body.split('')) {
        events.addAll(p.add(ch));
      }
      events.addAll(p.close());
      expect(events, hasLength(2));
      expect(events[0].event, 'x');
      expect(events[0].data, '1');
      expect(events[1].event, 'message');
      expect(events[1].data, 'no-space');
    });

    test(
      'ignores comments, unknown fields, events without data; strips BOM',
      () {
        final p = SseParser();
        final events = [
          ...p.add('﻿: keep-alive\nretry: 100\nfoo: bar\n\n'),
          ...p.add('event: only-type\n\n'),
          ...p.add('id: 7\ndata\n\n'),
        ];
        expect(events, hasLength(1));
        expect(events.single.data, '');
        expect(events.single.id, '7');
      },
    );

    test('close() flushes a final event without trailing blank line', () {
      final p = SseParser();
      expect(p.add('event: error\ndata: {"a":2}'), isEmpty);
      final events = p.close();
      expect(events.single.event, 'error');
      expect(events.single.data, '{"a":2}');
    });

    test(
      'parseByteStream decodes UTF-8 split inside multibyte chars',
      () async {
        final bytes = utf8.encode(
          'data: مرحبا بالعالم\n\nevent: error\n'
          'data: {"type":"error","error":{"type":"overloaded_error"}}\n\n',
        );
        final chunks = [
          for (final b in bytes) [b],
        ];
        final events = await SseParser.parseByteStream(
          Stream.fromIterable(chunks),
        ).toList();
        expect(events[0].data, 'مرحبا بالعالم');
        expect(events[1].event, 'error');
        expect(jsonDecode(events[1].data)['error']['type'], 'overloaded_error');
      },
    );
  });

  group('parseRetryAfter', () {
    test('seconds and decimals', () {
      expect(parseRetryAfter('3'), const Duration(seconds: 3));
      expect(parseRetryAfter('1.5'), const Duration(milliseconds: 1500));
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter('soon'), isNull);
      expect(parseRetryAfter('-1'), isNull);
    });

    test('HTTP date', () {
      final now = DateTime.utc(2015, 10, 21, 7, 27, 50);
      expect(
        parseRetryAfter('Wed, 21 Oct 2015 07:28:00 GMT', now: now),
        const Duration(seconds: 10),
      );
      expect(
        parseRetryAfter('Wed, 21 Oct 2015 07:20:00 GMT', now: now),
        Duration.zero,
      );
    });
  });
}
