// Helpers that build Claude-style SSE streams for tests.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Encodes one SSE event.
String sseEvent(String type, Map<String, dynamic> data) =>
    'event: $type\ndata: ${jsonEncode({'type': type, ...data})}\n\n';

/// A complete successful stream whose text answer is [text], split into
/// several deltas, preceded by a thinking block.
String successStream(
  String text, {
  String model = 'claude-opus-5-5',
  String stopReason = 'end_turn',
  String? fallbackTo,
}) {
  final b = StringBuffer()
    ..write(
      sseEvent('message_start', {
        'message': {
          'id': 'msg_1',
          'model': model,
          'usage': {'input_tokens': 1200, 'cache_read_input_tokens': 800},
        },
      }),
    )
    ..write(sseEvent('ping', {}));
  var index = 0;
  if (fallbackTo != null) {
    b
      ..write(
        sseEvent('content_block_start', {
          'index': index,
          'content_block': {
            'type': 'fallback',
            'from': {'model': model},
            'to': {'model': fallbackTo},
          },
        }),
      )
      ..write(sseEvent('content_block_stop', {'index': index}));
    index++;
  }
  b
    ..write(
      sseEvent('content_block_start', {
        'index': index,
        'content_block': {'type': 'thinking', 'thinking': ''},
      }),
    )
    ..write(
      sseEvent('content_block_delta', {
        'index': index,
        'delta': {'type': 'thinking_delta', 'thinking': 'IGNORED'},
      }),
    )
    ..write(
      sseEvent('content_block_delta', {
        'index': index,
        'delta': {'type': 'signature_delta', 'signature': 'sig'},
      }),
    )
    ..write(sseEvent('content_block_stop', {'index': index}));
  index++;
  b.write(
    sseEvent('content_block_start', {
      'index': index,
      'content_block': {'type': 'text', 'text': ''},
    }),
  );
  const step = 7;
  for (var i = 0; i < text.length; i += step) {
    final end = i + step > text.length ? text.length : i + step;
    b.write(
      sseEvent('content_block_delta', {
        'index': index,
        'delta': {'type': 'text_delta', 'text': text.substring(i, end)},
      }),
    );
  }
  b
    ..write(sseEvent('content_block_stop', {'index': index}))
    ..write(
      sseEvent('message_delta', {
        'delta': {'stop_reason': stopReason},
        'usage': {'output_tokens': 345},
      }),
    )
    ..write(sseEvent('message_stop', {}));
  return b.toString();
}

/// Streams [body] in chunks of [chunkSize] bytes (to exercise chunk
/// boundaries, including splits inside multi-byte UTF-8 sequences).
http.StreamedResponse chunkedResponse(
  String body, {
  int status = 200,
  int chunkSize = 13,
  Map<String, String> headers = const {'content-type': 'text/event-stream'},
}) {
  final bytes = utf8.encode(body);
  final chunks = <List<int>>[
    for (var i = 0; i < bytes.length; i += chunkSize)
      bytes.sublist(
        i,
        i + chunkSize > bytes.length ? bytes.length : i + chunkSize,
      ),
  ];
  return http.StreamedResponse(
    Stream.fromIterable(chunks),
    status,
    headers: headers,
  );
}

/// A [MockClient] that returns the queued responses in order and records the
/// requests it received.
class QueueClient {
  QueueClient(this.responses);

  final List<http.StreamedResponse Function()> responses;
  final List<http.BaseRequest> requests = [];
  final List<String> bodies = [];

  late final MockClient client = MockClient.streaming((request, body) async {
    requests.add(request);
    bodies.add(await body.bytesToString());
    if (responses.isEmpty) throw StateError('no more responses');
    return responses.removeAt(0)();
  });
}
