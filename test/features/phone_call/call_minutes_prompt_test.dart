import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/minutes/minutes_prompt.dart';

import '../../minutes/fixtures.dart';

void main() {
  final speakers = {
    'a': speaker('a', 'سارة', named: true),
    'b': speaker('b', 'متحدث 2'),
  };
  final segments = [
    seg(0, 0, 4000, 'مرحباً بكم', speakerId: 'a'),
    seg(1, 4000, 9000, 'نسمعكم بوضوح من المكتب الإقليمي', speakerId: 'b'),
    seg(2, 9000, 12000, 'نبدأ بالبند الأول', speakerId: 'a'),
  ];

  test('a phone-call meeting is described and remote speakers marked', () {
    final msg = buildMinutesUserMessage(
      meeting: meeting(),
      segments: segments,
      speakersById: speakers,
      inputs: const MinutesInputs(
        call: MinutesCallHint(
          mode: MinutesCallHint.modePhoneLink,
          remoteSegmentIds: {'s1'},
        ),
      ),
    );
    expect(
      msg,
      contains(
        'Phone call: part of this meeting was a regular '
        'cellular phone call',
      ),
    );
    expect(msg, contains('Microsoft Phone Link'));
    final lines = msg.split('\n');
    expect(
      lines.firstWhere((l) => l.startsWith('- متحدث 2')),
      contains('remote side of the phone call (الطرف البعيد)'),
    );
    expect(
      lines.firstWhere((l) => l.startsWith('- سارة')),
      isNot(contains('remote side')),
    );
  });

  test('speakerphone wording and ordinary meetings', () {
    final speakerphone = buildMinutesUserMessage(
      meeting: meeting(),
      segments: segments,
      speakersById: speakers,
      inputs: const MinutesInputs(
        call: MinutesCallHint(mode: MinutesCallHint.modeSpeakerphone),
      ),
    );
    expect(speakerphone, contains('phone loudspeaker'));
    expect(speakerphone, isNot(contains('(الطرف البعيد)')));
    final plain = buildMinutesUserMessage(
      meeting: meeting(),
      segments: segments,
      speakersById: speakers,
    );
    expect(plain, isNot(contains('Phone call:')));
  });

  test('remote speakers are those who spoke mostly on the line', () {
    final names = remoteCallSpeakerNames(
      [...segments, seg(3, 12000, 13000, 'نعم', speakerId: 'a')],
      speakers,
      {'s1', 's3'},
    );
    expect(names, {'متحدث 2'});
  });
}
