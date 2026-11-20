// Meeting links the bot can join (pure Dart, unit-tested).
//
// Accepted:
// * Google Meet: https://meet.google.com/abc-defg-hij (code of 3-4-3 latin
//   letters; dashes optional, any case, query dropped).
// * Microsoft Teams (work / school): https://teams.microsoft.com/l/meetup-join/…,
//   https://teams.microsoft.com/meet/<id>?p=<passcode>, the launcher page
//   (/dl/launcher/launcher.html?url=…) and the newer teams.cloud.microsoft
//   host with the same paths.
// * Microsoft Teams (personal): https://teams.live.com/meet/<id>?p=… and
//   https://teams.live.com/l/meetup-join/….
// * Zoom: https://[<sub>.]zoom.us/j/<id>?pwd=…, /w/<id> (webinars),
//   /wc/join/<id>, /wc/<id>/join, zoommtg://…/join?confno=<id>&pwd=…, the
//   same on zoom.com / zoomgov.com, or a meeting ID typed with its passcode
//   ("Meeting ID: 812 3456 7890  Passcode: 123456"). Converted to the Zoom
//   web client: https://app.zoom.us/wc/join/<id>?pwd=… (company vanity
//   hosts keep their host).
// * Cisco Webex: https://<site>.webex.com/meet/<name>, /join/<name>,
//   /<site>/j.php?MTID=…, /wbxmjs/joinservice/… (opened as given; the join
//   flow chooses "join from your browser").
//
// The link may be pasted inside a whole invitation text; the first
// http(s) link is used. Outlook "safe links" and Google redirect links are
// unwrapped.

/// Video-meeting service of a link.
enum MeetingPlatform {
  /// Google Meet.
  googleMeet,

  /// Microsoft Teams (work, school or personal).
  teams,

  /// Zoom (web client).
  zoom,

  /// Cisco Webex (web app).
  webex,
}

/// Id of the join-flow data of [p] in `kBotPlatformScripts`.
String platformScriptId(MeetingPlatform p) => switch (p) {
  MeetingPlatform.googleMeet => 'meet',
  MeetingPlatform.teams => 'teams',
  MeetingPlatform.zoom => 'zoom',
  MeetingPlatform.webex => 'webex',
};

/// Why a link was refused.
enum MeetingLinkError {
  /// Nothing was entered.
  empty,

  /// The text contains no web address (nor a Zoom meeting ID).
  notALink,

  /// Only https links are accepted.
  insecure,

  /// A host that is none of the supported services.
  unsupportedHost,

  /// meet.google.com without a valid meeting code.
  invalidMeetCode,

  /// A Teams address that is not a meeting link.
  invalidTeamsLink,

  /// A Zoom address without a meeting ID.
  invalidZoomLink,

  /// A Webex address that is not a meeting link.
  invalidWebexLink,
}

/// A link the bot can open.
class MeetingLink {
  /// Creates a link.
  const MeetingLink({
    required this.platform,
    required this.uri,
    required this.meetingId,
    this.passcode,
  });

  /// The service.
  final MeetingPlatform platform;

  /// The normalised address to open.
  final Uri uri;

  /// Short identifier for display (Meet code, Teams / Zoom meeting id …).
  final String meetingId;

  /// Passcode typed by the user (Zoom), entered by the join flow when the
  /// page asks for it. Links with `pwd=` carry it in [uri] instead.
  final String? passcode;

  /// A copy with [passcode] (empty clears it).
  MeetingLink withPasscode(String? passcode) {
    final p = passcode?.trim();
    return MeetingLink(
      platform: platform,
      uri: uri,
      meetingId: meetingId,
      passcode: (p == null || p.isEmpty) ? null : p,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MeetingLink &&
      other.platform == platform &&
      other.uri == uri &&
      other.meetingId == meetingId &&
      other.passcode == passcode;

  @override
  int get hashCode => Object.hash(platform, uri, meetingId, passcode);

  @override
  String toString() => 'MeetingLink(${platform.name}, $uri)';
}

/// Result of [parseMeetingLink]: exactly one of [link] / [error] is set.
class MeetingLinkResult {
  const MeetingLinkResult._(this.link, this.error, this.platform);

  /// A usable link.
  const MeetingLinkResult.ok(MeetingLink link) : this._(link, null, null);

  /// A refused link; [platform] is set when the service was recognised.
  const MeetingLinkResult.failed(
    MeetingLinkError error, {
    MeetingPlatform? platform,
  }) : this._(null, error, platform);

  /// The link when accepted.
  final MeetingLink? link;

  /// Why it was refused.
  final MeetingLinkError? error;

  /// The service of a refused link, when recognised.
  final MeetingPlatform? platform;

  /// True when [link] is set.
  bool get isValid => link != null;

  /// The recognised service.
  MeetingPlatform? get detectedPlatform => link?.platform ?? platform;
}

final RegExp _urlInText = RegExp(
  r'''(?:https?://|zoommtg://|www\.|meet\.google\.com/|teams\.(?:microsoft\.com|live\.com|cloud\.microsoft)/|[a-z0-9-]+\.zoom\.us/|zoom\.us/|[a-z0-9-]+\.webex\.com/)[^\s<>"'«»]+''',
  caseSensitive: false,
);

final RegExp _meetCode = RegExp(r'^([a-z]{3})-?([a-z]{4})-?([a-z]{3})$');

/// A Zoom meeting ID: 9 to 11 digits, spaces / dashes allowed.
final RegExp _zoomIdOnly = RegExp(r'^\d(?:[\s-]?\d){8,10}$');

final RegExp _zoomIdInText = RegExp(
  r'(?:meeting\s*id|معرّ?ف\s*الاجتماع|رقم\s*الاجتماع)\s*[:：]?\s*(\d(?:[\s-]?\d){8,10})',
  caseSensitive: false,
);

final RegExp _zoomPasscodeInText = RegExp(
  r'(?:passcode|password|رمز\s*المرور|كلمة\s*المرور)\s*[:：]?\s*(\S+)',
  caseSensitive: false,
);

const Set<String> _teamsWorkHosts = {
  'teams.microsoft.com',
  'teams.cloud.microsoft',
};

const String _teamsLiveHost = 'teams.live.com';

/// Parses [input] (a link, text containing one, or a Zoom meeting ID with
/// an optional passcode).
MeetingLinkResult parseMeetingLink(String input) =>
    _parse(input.trim(), unwrap: 2);

/// A Zoom web-client link for a typed meeting [id] and [passcode].
MeetingLinkResult zoomLinkFromId(String id, {String? passcode}) {
  final digits = id.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d{9,11}$').hasMatch(digits)) {
    return const MeetingLinkResult.failed(
      MeetingLinkError.invalidZoomLink,
      platform: MeetingPlatform.zoom,
    );
  }
  return MeetingLinkResult.ok(
    MeetingLink(
      platform: MeetingPlatform.zoom,
      uri: Uri.https('app.zoom.us', '/wc/join/$digits'),
      meetingId: _groupZoomId(digits),
    ).withPasscode(passcode),
  );
}

MeetingLinkResult _parse(String text, {required int unwrap}) {
  if (text.isEmpty) {
    return const MeetingLinkResult.failed(MeetingLinkError.empty);
  }
  final match = _urlInText.firstMatch(text);
  if (match == null) return _zoomFromText(text);
  var raw = match.group(0)!;
  // Trailing punctuation of the surrounding sentence.
  raw = raw.replaceFirst(RegExp(r'[.,;:!?)\]}،؛]+$'), '');
  if (!RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(raw)) {
    raw = 'https://$raw';
  }
  final Uri uri;
  try {
    uri = Uri.parse(raw);
  } on FormatException {
    return const MeetingLinkResult.failed(MeetingLinkError.notALink);
  }
  final host = uri.host.toLowerCase();
  if (host.isEmpty) {
    return const MeetingLinkResult.failed(MeetingLinkError.notALink);
  }

  // Wrappers: Outlook safe links, Google redirects.
  if (unwrap > 0) {
    String? inner;
    if (host.endsWith('safelinks.protection.outlook.com')) {
      inner = uri.queryParameters['url'];
    } else if ((host == 'www.google.com' || host == 'google.com') &&
        uri.path == '/url') {
      inner = uri.queryParameters['q'] ?? uri.queryParameters['url'];
    }
    if (inner != null && inner.isNotEmpty) {
      return _parse(inner, unwrap: unwrap - 1);
    }
  }

  final platform = _platformOf(host);
  if (platform == null) {
    return const MeetingLinkResult.failed(MeetingLinkError.unsupportedHost);
  }
  final scheme = uri.scheme.toLowerCase();
  final zoomApp = platform == MeetingPlatform.zoom && scheme == 'zoommtg';
  if (scheme != 'https' && !zoomApp) {
    return MeetingLinkResult.failed(
      MeetingLinkError.insecure,
      platform: platform,
    );
  }
  final result = switch (platform) {
    MeetingPlatform.googleMeet => _meet(uri),
    MeetingPlatform.teams => _teams(uri, host),
    MeetingPlatform.zoom => _zoom(uri, host),
    MeetingPlatform.webex => _webex(uri, host),
  };
  // A passcode written next to a Zoom link in the invitation.
  final link = result.link;
  if (link != null &&
      link.platform == MeetingPlatform.zoom &&
      !link.uri.queryParameters.containsKey('pwd')) {
    final pass = _zoomPasscodeInText.firstMatch(text)?.group(1);
    if (pass != null) return MeetingLinkResult.ok(link.withPasscode(pass));
  }
  return result;
}

/// A Zoom meeting ID (alone, or "Meeting ID: …" in a text) and passcode.
MeetingLinkResult _zoomFromText(String text) {
  final compact = text.trim();
  String? id;
  if (_zoomIdOnly.hasMatch(compact)) {
    id = compact;
  } else {
    id = _zoomIdInText.firstMatch(text)?.group(1);
  }
  if (id == null) {
    return const MeetingLinkResult.failed(MeetingLinkError.notALink);
  }
  return zoomLinkFromId(
    id,
    passcode: _zoomPasscodeInText.firstMatch(text)?.group(1),
  );
}

MeetingPlatform? _platformOf(String host) {
  if (host == 'meet.google.com') return MeetingPlatform.googleMeet;
  if (_teamsWorkHosts.contains(host) || host == _teamsLiveHost) {
    return MeetingPlatform.teams;
  }
  if (host == 'zoom.us' ||
      host.endsWith('.zoom.us') ||
      host == 'zoom.com' ||
      host.endsWith('.zoom.com') ||
      host == 'zoomgov.com' ||
      host.endsWith('.zoomgov.com')) {
    return MeetingPlatform.zoom;
  }
  if (host == 'webex.com' || host.endsWith('.webex.com')) {
    return MeetingPlatform.webex;
  }
  return null;
}

MeetingLinkResult _meet(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 1) {
    return const MeetingLinkResult.failed(
      MeetingLinkError.invalidMeetCode,
      platform: MeetingPlatform.googleMeet,
    );
  }
  final m = _meetCode.firstMatch(segments.single.toLowerCase());
  if (m == null) {
    return const MeetingLinkResult.failed(
      MeetingLinkError.invalidMeetCode,
      platform: MeetingPlatform.googleMeet,
    );
  }
  final code = '${m.group(1)}-${m.group(2)}-${m.group(3)}';
  return MeetingLinkResult.ok(
    MeetingLink(
      platform: MeetingPlatform.googleMeet,
      uri: Uri.https('meet.google.com', '/$code'),
      meetingId: code,
    ),
  );
}

MeetingLinkResult _teams(Uri uri, String host) {
  const invalid = MeetingLinkResult.failed(
    MeetingLinkError.invalidTeamsLink,
    platform: MeetingPlatform.teams,
  );
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  // Launcher page: the meeting path is in `url` (e.g. /_#/l/meetup-join/…).
  if (segments.length >= 2 &&
      segments[0] == 'dl' &&
      segments[1] == 'launcher') {
    final inner = uri.queryParameters['url'] ?? '';
    final path = inner.replaceFirst(RegExp(r'^/?_?#?'), '/');
    if (!path.contains('/l/meetup-join/') && !path.contains('/meet/')) {
      return invalid;
    }
    return _teams(Uri.parse('https://$host$path'), host);
  }
  if (segments.length >= 3 &&
      segments[0] == 'l' &&
      segments[1] == 'meetup-join') {
    final thread = segments[2];
    if (!thread.toLowerCase().contains('meeting_') &&
        !thread.toLowerCase().contains('@thread')) {
      return invalid;
    }
    return MeetingLinkResult.ok(
      MeetingLink(
        platform: MeetingPlatform.teams,
        uri: uri.replace(scheme: 'https', host: host),
        meetingId: _shortTeamsId(thread),
      ),
    );
  }
  if (segments.length == 2 && segments[0] == 'meet') {
    final id = segments[1];
    if (!RegExp(r'^[0-9A-Za-z]{6,}$').hasMatch(id)) return invalid;
    return MeetingLinkResult.ok(
      MeetingLink(
        platform: MeetingPlatform.teams,
        uri: uri.replace(scheme: 'https', host: host),
        meetingId: id,
      ),
    );
  }
  return invalid;
}

String _shortTeamsId(String thread) {
  final m = RegExp(r'meeting_([A-Za-z0-9]+)').firstMatch(thread);
  final id = m?.group(1) ?? thread;
  return id.length <= 12 ? id : '${id.substring(0, 12)}…';
}

MeetingLinkResult _zoom(Uri uri, String host) {
  const invalid = MeetingLinkResult.failed(
    MeetingLinkError.invalidZoomLink,
    platform: MeetingPlatform.zoom,
  );
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? id;
  if (uri.scheme.toLowerCase() == 'zoommtg') {
    id = uri.queryParameters['confno'];
  } else if (segments.length >= 2 &&
      (segments[0] == 'j' || segments[0] == 'w' || segments[0] == 's')) {
    id = segments[1];
  } else if (segments.length >= 3 &&
      segments[0] == 'wc' &&
      segments[1] == 'join') {
    id = segments[2];
  } else if (segments.length >= 3 &&
      segments[0] == 'wc' &&
      (segments[2] == 'join' || segments[2] == 'start')) {
    id = segments[1];
  }
  if (id == null || !RegExp(r'^\d{9,11}$').hasMatch(id)) return invalid;
  final pwd = uri.queryParameters['pwd'];
  // The web client lives on app.zoom.us for the shared hosts; company
  // vanity hosts (acme.zoom.us) and Zoom for Government keep theirs.
  final shared =
      host == 'zoom.us' ||
      host == 'zoom.com' ||
      host == 'app.zoom.us' ||
      RegExp(r'^us\d+web\.zoom\.us$').hasMatch(host) ||
      uri.scheme.toLowerCase() == 'zoommtg';
  final webHost = shared ? 'app.zoom.us' : host;
  return MeetingLinkResult.ok(
    MeetingLink(
      platform: MeetingPlatform.zoom,
      uri: Uri.https(
        webHost,
        '/wc/join/$id',
        (pwd != null && pwd.isNotEmpty) ? {'pwd': pwd} : null,
      ),
      meetingId: _groupZoomId(id),
    ),
  );
}

String _groupZoomId(String digits) {
  if (digits.length == 11) {
    return '${digits.substring(0, 3)} ${digits.substring(3, 7)} '
        '${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }
  return digits;
}

MeetingLinkResult _webex(Uri uri, String host) {
  const invalid = MeetingLinkResult.failed(
    MeetingLinkError.invalidWebexLink,
    platform: MeetingPlatform.webex,
  );
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? id;
  final meetAt = segments.indexWhere((s) => s == 'meet' || s == 'join');
  if (meetAt >= 0 && meetAt + 1 < segments.length) {
    id = segments[meetAt + 1];
  } else if (segments.isNotEmpty && segments.last == 'j.php') {
    id = uri.queryParameters['MTID'] ?? uri.queryParameters['mtid'];
  } else if (segments.contains('wbxmjs') || segments.contains('joinservice')) {
    id = segments.last;
  }
  if (id == null || id.isEmpty) return invalid;
  return MeetingLinkResult.ok(
    MeetingLink(
      platform: MeetingPlatform.webex,
      uri: uri.replace(scheme: 'https', host: host),
      meetingId: id.length <= 16 ? id : '${id.substring(0, 16)}…',
    ),
  );
}
