// The versioned join flows: shape of the data and parsing of the page
// script's answers. (The script itself was exercised against mock Meet /
// Teams pages in headless Chrome during development; on real pages it is
// verified on Windows — see docs/SETUP.md.)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/meeting_bot/bot_scripts.dart';

void main() {
  test('version is set', () {
    expect(kBotScriptsVersion, matches(RegExp(r'^\d{4}\.\d{2}\.\d{2}-\d+$')));
  });

  for (final entry in kBotPlatformScripts.entries) {
    group(entry.key, () {
      final cfg = entry.value;

      test('every state has a known name and at least one matcher', () {
        final states = cfg['states']! as List;
        expect(states, isNotEmpty);
        for (final s in states.cast<Map<String, Object?>>()) {
          final name = s['state'];
          expect(
            botPageStateOf(name),
            isNot(BotPageState.unknown),
            reason: '$name',
          );
          expect(
            [
              'text',
              'css',
              'label',
            ].any((k) => (s[k] as List?)?.isNotEmpty ?? false),
            isTrue,
            reason: '$name',
          );
        }
        // Final states are checked before "in call" so a leaving page is
        // never read as still in the meeting.
        final order = [for (final s in states) (s as Map)['state']];
        expect(order.indexOf('ended'), lessThan(order.indexOf('in_call')));
        expect(order.indexOf('removed'), lessThan(order.indexOf('in_call')));
        expect(order.indexOf('in_call'), lessThan(order.indexOf('lobby')));
      });

      test('action groups: prejoin, in call, leave; no "end for all"', () {
        final actions = cfg['actions']! as Map;
        for (final g in [
          BotActions.prejoin,
          BotActions.inCall,
          BotActions.leave,
        ]) {
          expect(actions[g], isA<List<Object?>>(), reason: g);
        }
        final prejoin = (actions[BotActions.prejoin] as List)
            .cast<Map<String, Object?>>();
        // The name is filled and both devices turned off before joining.
        final names = [for (final s in prejoin) s['name']];
        expect(names.indexOf('name'), lessThan(names.length - 1));
        expect(names, containsAll(['microphone_off', 'camera_off']));
        expect(prejoin.last['do'], 'click');
        expect(prejoin.last['required'], isTrue);
        final text = jsonEncode(cfg).toLowerCase();
        expect(text, isNot(contains('end meeting')));
        expect(text, isNot(contains('end for everyone')));
        expect(text, isNot(contains('unmute')));
      });

      test('the expression embeds the data and the variables', () {
        final e = botPageExpression(
          entry.key,
          'probe',
          vars: {'name': 'إنصاتو — كاتب المحضر'},
        );
        expect(e, startsWith('(function (cfg, mode, vars)'));
        expect(e, endsWith('"probe", {"name":"إنصاتو — كاتب المحضر"})'));
        expect(e, contains(jsonEncode(cfg)));
      });
    });
  }

  test('Meet, Teams, Zoom and Webex have flows', () {
    expect(
      kBotPlatformScripts.keys,
      unorderedEquals(['meet', 'teams', 'zoom', 'webex']),
    );
    expect(() => botPageExpression('skype', 'probe'), throwsArgumentError);
  });

  test('the page script is plain ES5 without template literals', () {
    expect(kBotPageScript, isNot(contains('`')));
    expect(kBotPageScript, isNot(contains('=>')));
    expect(kBotPageScript, isNot(contains('let ')));
    expect(kBotPageScript, isNot(contains('const ')));
  });

  test('probe answers', () {
    final p = BotProbe.fromJson(
      '{"state":"in_call","alone":true,"participants":2,"url":"u"}',
    );
    expect(p.state, BotPageState.inCall);
    expect(p.alone, isTrue);
    expect(p.participants, 2);
    expect(p.url, 'u');
    expect(BotProbe.fromJson({'state': 'lobby'}).state, BotPageState.lobby);
    expect(BotProbe.fromJson('{"state":"weird"}').state, BotPageState.unknown);
    expect(BotProbe.fromJson('garbage').error, 'unreadable');
    expect(BotProbe.fromJson(null).error, 'unreadable');
    expect(BotProbe.fromJson('{"error":"x"}').error, 'x');
    for (final s in BotPageState.values) {
      expect(botPageStateOf(kBotPageStateNames[s]), s);
    }
  });

  test('action answers', () {
    final r = BotActionResult.fromJson(
      '{"done":["name","ask_to_join"],"missing":["x",1]}',
    );
    expect(r.done, ['name', 'ask_to_join']);
    expect(r.missing, ['x']);
    expect(BotActionResult.fromJson('nope').done, isEmpty);
  });
}
