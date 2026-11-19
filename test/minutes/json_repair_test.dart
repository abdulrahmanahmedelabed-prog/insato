import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/minutes/json_repair.dart';
import 'package:insato/minutes/minutes_generator.dart';

void main() {
  test('valid JSON, fences and prose', () {
    expect(decodeJsonObjectTolerant('{"a": 1}'), {'a': 1});
    expect(decodeJsonObjectTolerant('﻿ {"a": 1} '), {'a': 1});
    expect(decodeJsonObjectTolerant('```json\n{"a": [1, 2]}\n```'), {
      'a': [1, 2],
    });
    expect(decodeJsonObjectTolerant('Here you go: {"a": "b"} Thanks'), {
      'a': 'b',
    });
  });

  test('trailing commas, comments and raw newlines', () {
    expect(
      decodeJsonObjectTolerant(
        '{"a": [1, 2,], // note\n "b": "x\ny", /* c */}',
      ),
      {
        'a': [1, 2],
        'b': 'x\ny',
      },
    );
  });

  test('truncated output is closed', () {
    expect(decodeJsonObjectTolerant('{"a": [1, 2'), {
      'a': [1, 2],
    });
    expect(decodeJsonObjectTolerant('{"a": "unterminated'), {
      'a': 'unterminated',
    });
    expect(decodeJsonObjectTolerant('{"a": 1, "b":'), {'a': 1});
    expect(decodeJsonObjectTolerant('{"a": 1, "b"'), {'a': 1});
    expect(decodeJsonObjectTolerant('```json\n{"a": {"b": [true,'), {
      'a': {
        'b': [true],
      },
    });
    expect(decodeJsonObjectTolerant(r'{"a": "x\'), {'a': 'x'});
  });

  test('strings containing brackets and escaped quotes are untouched', () {
    expect(decodeJsonObjectTolerant(r'{"code": "f(x) { return \"}\"; }",}'), {
      'code': 'f(x) { return "}"; }',
    });
  });

  test('nothing recoverable', () {
    expect(decodeJsonObjectTolerant('no json here'), isNull);
    expect(decodeJsonObjectTolerant('[1, 2]'), isNull);
    expect(repairJson('plain'), isNull);
    expect(
      () => parseMinutesJson('sorry'),
      throwsA(isA<MinutesGenerationException>()),
    );
  });
}
