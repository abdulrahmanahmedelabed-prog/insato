// Shared HTTP helpers of the cloud clients (Gemini, Groq): an incremental
// Server-Sent Events parser, the retry-delay seam and `Retry-After` parsing.

import 'dart:async';
import 'dart:convert';

// ---------------------------------------------------------------------------
// Server-Sent Events parsing
// ---------------------------------------------------------------------------

/// One dispatched Server-Sent Event.
class SseEvent {
  /// Creates an event. [event] defaults to `message` per the SSE spec.
  const SseEvent({this.event = 'message', required this.data, this.id});

  /// The `event:` field (`message` when the server did not send one).
  final String event;

  /// The `data:` payload. Multiple `data:` lines are joined with `\n`.
  final String data;

  /// The last `id:` value seen, if any.
  final String? id;

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Incremental, spec-compliant Server-Sent Events parser.
///
/// Feed it decoded text in arbitrary chunks with [add]; it returns the events
/// completed by that chunk. It handles:
/// * `\n`, `\r\n` and bare `\r` line endings, including a `\r\n` pair split
///   across two chunks;
/// * lines split across chunks;
/// * multi-line `data:` fields (joined with `\n`);
/// * comment lines (starting with `:`), which are ignored;
/// * a leading byte-order mark;
/// * fields with no colon (`data` alone means an empty value).
///
/// Call [close] at end of stream to dispatch a final event that was not
/// followed by a blank line.
class SseParser {
  final StringBuffer _line = StringBuffer();
  final List<String> _data = <String>[];
  String? _eventType;
  String? _lastId;
  bool _pendingCr = false;
  bool _started = false;
  bool _hasData = false;

  /// Parses [chunk] and returns the events it completed (possibly none).
  List<SseEvent> add(String chunk) {
    final out = <SseEvent>[];
    var start = 0;
    if (!_started && chunk.isNotEmpty) {
      _started = true;
      if (chunk.codeUnitAt(0) == 0xFEFF) start = 1;
    }
    for (var i = start; i < chunk.length; i++) {
      final c = chunk.codeUnitAt(i);
      if (_pendingCr) {
        _pendingCr = false;
        if (c == 0x0A) continue; // second half of a CRLF split across chunks
      }
      if (c == 0x0D) {
        _pendingCr = true;
        _endLine(out);
      } else if (c == 0x0A) {
        _endLine(out);
      } else {
        _line.writeCharCode(c);
      }
    }
    return out;
  }

  /// Flushes a trailing line / event at end of stream.
  List<SseEvent> close() {
    final out = <SseEvent>[];
    if (_line.isNotEmpty) _endLine(out);
    _dispatch(out);
    _pendingCr = false;
    return out;
  }

  void _endLine(List<SseEvent> out) {
    final line = _line.toString();
    _line.clear();
    if (line.isEmpty) {
      _dispatch(out);
      return;
    }
    if (line.startsWith(':')) return; // comment
    final colon = line.indexOf(':');
    String field;
    String value;
    if (colon < 0) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, colon);
      value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
    }
    switch (field) {
      case 'data':
        _data.add(value);
        _hasData = true;
      case 'event':
        _eventType = value;
      case 'id':
        if (!value.contains('\u0000')) _lastId = value;
      default:
        // `retry` and unknown fields are ignored.
        break;
    }
  }

  void _dispatch(List<SseEvent> out) {
    if (_hasData) {
      out.add(
        SseEvent(
          event: (_eventType == null || _eventType!.isEmpty)
              ? 'message'
              : _eventType!,
          data: _data.join('\n'),
          id: _lastId,
        ),
      );
    }
    _data.clear();
    _hasData = false;
    _eventType = null;
  }

  /// Transforms a byte stream (UTF-8) into a stream of [SseEvent]s.
  static Stream<SseEvent> parseByteStream(Stream<List<int>> bytes) async* {
    final parser = SseParser();
    await for (final text in bytes.transform(utf8.decoder)) {
      for (final e in parser.add(text)) {
        yield e;
      }
    }
    for (final e in parser.close()) {
      yield e;
    }
  }
}


/// Signature of the delay used between retries (injectable for tests).
typedef RetryDelay = Future<void> Function(Duration duration);

/// Parses a `retry-after` header value: either delay-seconds (integer or
/// decimal) or an HTTP-date. Returns null when absent or unparseable.
Duration? parseRetryAfter(String? value, {DateTime? now}) {
  if (value == null) return null;
  final v = value.trim();
  if (v.isEmpty) return null;
  final seconds = double.tryParse(v);
  if (seconds != null) {
    if (seconds.isNaN || seconds < 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }
  try {
    final date = parseHttpDate(v);
    final diff = date.difference((now ?? DateTime.now()).toUtc());
    return diff.isNegative ? Duration.zero : diff;
  } on FormatException {
    return null;
  }
}

/// Parses an RFC 7231 IMF-fixdate such as `Wed, 21 Oct 2015 07:28:00 GMT`.
DateTime parseHttpDate(String value) {
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final m = RegExp(
    r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
  ).firstMatch(value);
  if (m == null) throw FormatException('Not an HTTP date', value);
  final month = months[m.group(2)!.toLowerCase()];
  if (month == null) throw FormatException('Bad month', value);
  return DateTime.utc(
    int.parse(m.group(3)!),
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}
