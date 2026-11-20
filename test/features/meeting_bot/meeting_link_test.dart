// Meeting links the bot accepts or refuses.

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/meeting_bot/meeting_link.dart';
import 'package:insato/features/meeting_bot/strings.dart';

void main() {
  group('Google Meet', () {
    test('normalises the meeting code', () {
      for (final input in [
        'https://meet.google.com/abc-defg-hij',
        'https://meet.google.com/ABC-DEFG-HIJ?authuser=0&pli=1',
        'meet.google.com/abcdefghij',
        'http://meet.google.com/abc-defg-hij',
        '  https://meet.google.com/abc-defg-hij/  ',
      ]) {
        final r = parseMeetingLink(input);
        if (input.startsWith('http://')) {
          expect(r.error, MeetingLinkError.insecure, reason: input);
          continue;
        }
        expect(r.isValid, isTrue, reason: input);
        expect(r.link!.platform, MeetingPlatform.googleMeet);
        expect(r.link!.uri.toString(), 'https://meet.google.com/abc-defg-hij');
        expect(r.link!.meetingId, 'abc-defg-hij');
      }
    });

    test('finds the link inside an invitation text', () {
      final r = parseMeetingLink(
        'انضم إلى الاجتماع: https://meet.google.com/xyz-abcd-efg، شكراً.',
      );
      expect(r.link?.meetingId, 'xyz-abcd-efg');
    });

    test('refuses invalid codes', () {
      for (final input in [
        'https://meet.google.com/',
        'https://meet.google.com/abc-def-ghi',
        'https://meet.google.com/abc-defg-hij/extra',
        'https://meet.google.com/123-4567-890',
      ]) {
        final r = parseMeetingLink(input);
        expect(r.error, MeetingLinkError.invalidMeetCode, reason: input);
        expect(r.detectedPlatform, MeetingPlatform.googleMeet);
      }
    });
  });

  group('Microsoft Teams', () {
    const joinUrl =
        'https://teams.microsoft.com/l/meetup-join/'
        '19%3ameeting_NjQ5ZTY4ZjQtYWE1Mi00%40thread.v2/0'
        '?context=%7b%22Tid%22%3a%22x%22%7d';

    test('accepts meetup-join links and keeps the query', () {
      final r = parseMeetingLink(joinUrl);
      expect(r.isValid, isTrue);
      expect(r.link!.platform, MeetingPlatform.teams);
      expect(r.link!.uri.host, 'teams.microsoft.com');
      expect(r.link!.uri.query, contains('context='));
      expect(r.link!.meetingId, startsWith('NjQ5ZTY4ZjQt'));
    });

    test('accepts short /meet links (work and personal)', () {
      for (final input in [
        'https://teams.microsoft.com/meet/2345678901234?p=AbCdEf',
        'https://teams.live.com/meet/9876543210123?p=XyZ',
        'https://teams.cloud.microsoft/meet/2345678901234?p=AbC',
      ]) {
        final r = parseMeetingLink(input);
        expect(r.isValid, isTrue, reason: input);
        expect(r.link!.platform, MeetingPlatform.teams);
        expect(r.link!.uri.queryParameters['p'], isNotEmpty);
      }
    });

    test('unwraps the launcher page and Outlook safe links', () {
      final launcher = Uri.https(
        'teams.microsoft.com',
        '/dl/launcher/launcher.html',
        {
          'url': '/_#/l/meetup-join/19:meeting_ABC123@thread.v2/0',
          'type': 'meetup-join',
        },
      ).toString();
      final r = parseMeetingLink(launcher);
      expect(r.isValid, isTrue);
      expect(r.link!.uri.path, contains('/l/meetup-join/'));

      final safe = Uri.https('nam12.safelinks.protection.outlook.com', '/', {
        'url': joinUrl,
        'data': 'x',
      }).toString();
      final s = parseMeetingLink(safe);
      expect(s.isValid, isTrue);
      expect(s.link!.uri.host, 'teams.microsoft.com');
    });

    test('refuses Teams pages that are not meetings', () {
      for (final input in [
        'https://teams.microsoft.com/',
        'https://teams.microsoft.com/l/chat/0/0?users=a@b.c',
        'https://teams.live.com/meet/',
      ]) {
        expect(
          parseMeetingLink(input).error,
          MeetingLinkError.invalidTeamsLink,
          reason: input,
        );
      }
    });
  });

  group('Zoom', () {
    test('join links become the web client, pwd kept', () {
      for (final input in [
        'https://us02web.zoom.us/j/81234567890?pwd=AbC.1',
        'https://zoom.us/j/81234567890?pwd=AbC.1',
        'zoommtg://zoom.us/join?action=join&confno=81234567890&pwd=AbC.1',
        'https://app.zoom.us/wc/join/81234567890?pwd=AbC.1',
        'https://zoom.us/wc/81234567890/join?pwd=AbC.1',
      ]) {
        final r = parseMeetingLink(input);
        expect(r.isValid, isTrue, reason: input);
        expect(r.link!.platform, MeetingPlatform.zoom);
        expect(
          r.link!.uri.toString(),
          'https://app.zoom.us/wc/join/81234567890?pwd=AbC.1',
          reason: input,
        );
        expect(r.link!.meetingId, '812 3456 7890');
        expect(r.link!.passcode, isNull);
      }
    });

    test('company hosts keep their host; webinars accepted', () {
      final r = parseMeetingLink('https://acme.zoom.us/w/912345678?tk=x');
      expect(r.link!.uri.toString(), 'https://acme.zoom.us/wc/join/912345678');
    });

    test('meeting ID typed with its passcode', () {
      final a = parseMeetingLink('812 3456 7890');
      expect(a.link!.uri.path, '/wc/join/81234567890');
      expect(a.link!.passcode, isNull);
      final b = parseMeetingLink(
        'Join Zoom Meeting\nMeeting ID: 812 3456 7890\nPasscode: 4x7Kp9',
      );
      expect(b.link!.platform, MeetingPlatform.zoom);
      expect(b.link!.passcode, '4x7Kp9');
      final c = parseMeetingLink(
        'معرّف الاجتماع: 812-3456-7890 رمز المرور: 1234',
      );
      expect(c.link!.meetingId, '812 3456 7890');
      expect(c.link!.passcode, '1234');
      // A passcode next to a link without pwd.
      final d = parseMeetingLink(
        'https://zoom.us/j/81234567890 Passcode: 998877',
      );
      expect(d.link!.passcode, '998877');
      expect(
        zoomLinkFromId('12 34', passcode: 'x').error,
        MeetingLinkError.invalidZoomLink,
      );
      expect(
        zoomLinkFromId('81234567890', passcode: '  ').link!.passcode,
        isNull,
      );
    });

    test('Zoom addresses without a meeting', () {
      for (final input in [
        'https://zoom.us/',
        'https://zoom.us/j/abc',
        'https://zoom.us/signin',
      ]) {
        expect(
          parseMeetingLink(input).error,
          MeetingLinkError.invalidZoomLink,
          reason: input,
        );
      }
    });
  });

  group('Webex', () {
    test('meeting links are kept as given', () {
      for (final input in [
        'https://acme.webex.com/meet/jdoe',
        'https://acme.webex.com/acme/j.php?MTID=m1234abcd',
        'https://acme.my.webex.com/join/jdoe',
      ]) {
        final r = parseMeetingLink(input);
        expect(r.isValid, isTrue, reason: input);
        expect(r.link!.platform, MeetingPlatform.webex);
        expect(r.link!.uri.toString(), input);
      }
    });

    test('other Webex pages are refused', () {
      expect(
        parseMeetingLink('https://acme.webex.com/webappng/sites/acme').error,
        MeetingLinkError.invalidWebexLink,
      );
    });
  });

  test('every service has a join flow id', () {
    expect(MeetingPlatform.values.map(platformScriptId).toSet(), {
      'meet',
      'teams',
      'zoom',
      'webex',
    });
  });

  test('other inputs', () {
    expect(parseMeetingLink('').error, MeetingLinkError.empty);
    expect(parseMeetingLink('   ').error, MeetingLinkError.empty);
    expect(parseMeetingLink('اجتماع الغد').error, MeetingLinkError.notALink);
    expect(
      parseMeetingLink('https://example.com/meet/abc').error,
      MeetingLinkError.unsupportedHost,
    );
    expect(
      parseMeetingLink('https://meet.google.com.evil.example/abc-defg-hij')
          .error,
      MeetingLinkError.unsupportedHost,
    );
  });

  test('every error has an Arabic message', () {
    for (final e in MeetingLinkError.values) {
      expect(BotStrings.linkError(e), isNotEmpty);
    }
  });
}
