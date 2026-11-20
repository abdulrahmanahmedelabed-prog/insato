// Tolerant JSON extraction and repair for model output that was not
// produced under a strict schema (Gemini's plain JSON mode, local models):
// strips Markdown fences and surrounding prose, removes trailing commas and
// comments, escapes raw control characters inside strings, and closes
// strings / arrays / objects left open by a truncated answer.
//
// Pure Dart, unit-tested.

import 'dart:convert';

/// Decodes [text] into a JSON object, repairing common defects. Returns null
/// when no object can be recovered.
Map<String, dynamic>? decodeJsonObjectTolerant(String text) {
  Map<String, dynamic>? tryDecode(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  final trimmed = text.trim().replaceFirst('﻿', '');
  final direct = tryDecode(trimmed);
  if (direct != null) return direct;

  final candidates = <String>[];
  final fence = RegExp(r'```(?:json|JSON)?\s*([\s\S]*?)\s*(?:```|$)')
      .firstMatch(trimmed);
  if (fence != null) candidates.add(fence.group(1)!);
  final start = trimmed.indexOf('{');
  // Text after the last `}` that still looks like JSON (a key, a value
  // separator) means the answer was cut off inside an object: closing the
  // whole text keeps the last, partial item, which the text cut at the
  // last `}` would drop.
  var truncated = false;
  if (start >= 0) {
    final end = trimmed.lastIndexOf('}');
    if (end > start) {
      candidates.add(trimmed.substring(start, end + 1));
      truncated = RegExp(r'["\[:,]').hasMatch(trimmed.substring(end + 1));
    }
    candidates.add(trimmed.substring(start));
  }
  for (final c in candidates) {
    final d = tryDecode(c);
    if (d != null) return d;
  }
  for (final c in truncated ? candidates.reversed : candidates) {
    final repaired = repairJson(c);
    if (repaired == null) continue;
    final d = tryDecode(repaired);
    if (d != null) return d;
  }
  return null;
}

/// Best-effort repair of a JSON text that starts at its first `{` / `[`:
/// removes `//` and `/* */` comments outside strings and trailing commas,
/// escapes raw newlines / tabs inside strings, and closes an unterminated
/// string and any open containers (a dangling `"key":` or `,` at the cut is
/// dropped). Returns null when [s] holds no container.
String? repairJson(String s) {
  final begin = s.indexOf(RegExp(r'[{\[]'));
  if (begin < 0) return null;
  final src = s.substring(begin);
  final out = StringBuffer();
  final stack = <String>[];
  var inString = false;
  var escaped = false;
  var i = 0;
  while (i < src.length) {
    final ch = src[i];
    if (inString) {
      if (escaped) {
        escaped = false;
        out.write(ch);
      } else if (ch == r'\') {
        escaped = true;
        out.write(ch);
      } else if (ch == '"') {
        inString = false;
        out.write(ch);
      } else if (ch == '\n') {
        out.write(r'\n');
      } else if (ch == '\r') {
        out.write(r'\r');
      } else if (ch == '\t') {
        out.write(r'\t');
      } else {
        out.write(ch);
      }
      i++;
      continue;
    }
    if (ch == '/' && i + 1 < src.length && src[i + 1] == '/') {
      final nl = src.indexOf('\n', i);
      i = nl < 0 ? src.length : nl;
      continue;
    }
    if (ch == '/' && i + 1 < src.length && src[i + 1] == '*') {
      final close = src.indexOf('*/', i + 2);
      i = close < 0 ? src.length : close + 2;
      continue;
    }
    switch (ch) {
      case '"':
        inString = true;
        out.write(ch);
      case '{':
        stack.add('}');
        out.write(ch);
      case '[':
        stack.add(']');
        out.write(ch);
      case '}':
      case ']':
        _dropTrailingComma(out);
        if (stack.isNotEmpty && stack.last == ch) stack.removeLast();
        out.write(ch);
        if (stack.isEmpty) {
          return out.toString();
        }
      default:
        out.write(ch);
    }
    i++;
  }
  // Truncated: close the open string and containers.
  var text = out.toString();
  if (inString) {
    if (escaped) text = text.substring(0, text.length - 1);
    text = '$text"';
  }
  text = _trimDangling(text);
  final b = StringBuffer(text);
  for (final c in stack.reversed) {
    b.write(c);
  }
  return b.toString();
}

void _dropTrailingComma(StringBuffer out) {
  final s = out.toString();
  final t = s.trimRight();
  if (t.endsWith(',')) {
    out
      ..clear()
      ..write(t.substring(0, t.length - 1));
  }
}

/// Removes an incomplete trailing member (`, "key"`, `"key":`, `,`) left by
/// a cut so the closers can be appended.
String _trimDangling(String text) {
  var t = text.trimRight();
  while (true) {
    final before = t;
    if (t.endsWith(',')) t = t.substring(0, t.length - 1).trimRight();
    if (t.endsWith(':')) {
      t = t.substring(0, t.length - 1).trimRight();
      // Drop the key string as well.
      if (t.endsWith('"')) {
        final open = _openingQuote(t);
        if (open >= 0) t = t.substring(0, open).trimRight();
      }
    }
    // A key without a colon inside an object: `{"a": 1, "b"` → drop "b".
    if (t.endsWith('"')) {
      final open = _openingQuote(t);
      if (open > 0) {
        final prev = t.substring(0, open).trimRight();
        if (prev.endsWith(',') || prev.endsWith('{')) {
          if (_insideObject(prev)) t = prev;
        }
      }
    }
    if (t == before) return t;
  }
}

/// Index of the quote opening the string that ends at the last character.
int _openingQuote(String t) {
  for (var j = t.length - 2; j >= 0; j--) {
    if (t[j] == '"') {
      var backslashes = 0;
      for (var k = j - 1; k >= 0 && t[k] == r'\'; k--) {
        backslashes++;
      }
      if (backslashes.isEven) return j;
    }
  }
  return -1;
}

/// True when the innermost open container at the end of [t] is an object.
bool _insideObject(String t) {
  final stack = <String>[];
  var inString = false;
  var escaped = false;
  for (var i = 0; i < t.length; i++) {
    final ch = t[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{' || ch == '[') {
      stack.add(ch);
    } else if ((ch == '}' || ch == ']') && stack.isNotEmpty) {
      stack.removeLast();
    }
  }
  return stack.isNotEmpty && stack.last == '{';
}
