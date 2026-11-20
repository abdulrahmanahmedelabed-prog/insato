// Join flows of the meeting bot, as data (one versioned file).
//
// Google, Microsoft, Zoom and Cisco change their web pages without notice. Everything
// that depends on their markup lives here: how a page state is recognised
// (texts, CSS selectors, button labels) and which buttons the bot presses
// in each state. A small, fixed JavaScript interpreter ([kBotPageScript])
// evaluates this data inside the page through the Chrome DevTools
// Protocol; when a service changes its UI, update the lists below and bump
// [kBotScriptsVersion]. The browser is started with `--lang=en-US`, so the
// English texts are the primary ones; Arabic variants are kept as a
// fallback. Verification status of each flow: [kBotFlowVerification].
//
// Matching rules (see [kBotPageScript]):
// * `text`  – the visible page text contains one of the phrases
//             (case-insensitive, whitespace collapsed).
// * `css`   – a visible element matches one of the selectors.
// * `label` – a visible button-like element whose aria-label, title,
//             tooltip or text contains the phrase; a leading `^` means
//             "starts with" (so `^mute` never matches "Unmute").
//
// Never add steps that get around a meeting's security: the bot only fills
// its (disclosed) name, keeps its microphone and camera off, asks to join,
// waits for the organiser and leaves.

import 'dart:convert';

/// Version of the join flows (date + revision). Shown in the bot screen and
/// stored in the meeting notes so problems can be traced to a revision.
const String kBotScriptsVersion = '2026.11.20-2';

/// What the bot sees in the meeting page.
enum BotPageState {
  /// Nothing recognised yet (page loading or unknown layout).
  unknown,

  /// Teams "how do you want to join" page (app or browser).
  launcher,

  /// The pre-join screen: name field, device toggles, join button.
  prejoin,

  /// Waiting in the lobby for the organiser to admit the bot.
  lobby,

  /// Waiting for the host to start the meeting (Zoom, Webex).
  notStarted,

  /// The site asks for a human check (CAPTCHA). The bot never solves it:
  /// it shows its window so the user can, or gives up after the timeout.
  verification,

  /// In the meeting.
  inCall,

  /// Nobody answered the request to join in time.
  lobbyTimeout,

  /// The organiser declined the request to join.
  denied,

  /// The bot was removed from the meeting.
  removed,

  /// The meeting ended (or the bot left).
  ended,

  /// The meeting link is invalid or expired.
  invalid,

  /// The meeting does not accept guests without an account.
  blocked,
}

/// Wire name of each [BotPageState] in the page script.
const Map<BotPageState, String> kBotPageStateNames = {
  BotPageState.unknown: 'unknown',
  BotPageState.launcher: 'launcher',
  BotPageState.prejoin: 'prejoin',
  BotPageState.lobby: 'lobby',
  BotPageState.notStarted: 'not_started',
  BotPageState.verification: 'verification',
  BotPageState.inCall: 'in_call',
  BotPageState.lobbyTimeout: 'lobby_timeout',
  BotPageState.denied: 'denied',
  BotPageState.removed: 'removed',
  BotPageState.ended: 'ended',
  BotPageState.invalid: 'invalid',
  BotPageState.blocked: 'blocked',
};

/// Parses a state name of the page script ([BotPageState.unknown] when not
/// understood).
BotPageState botPageStateOf(Object? name) {
  for (final e in kBotPageStateNames.entries) {
    if (e.value == name) return e.key;
  }
  return BotPageState.unknown;
}

/// Action groups the bot runs.
abstract final class BotActions {
  /// Teams launcher: continue in the browser.
  static const String launcher = 'launcher';

  /// Pre-join: name, microphone / camera off, ask to join.
  static const String prejoin = 'prejoin';

  /// In the meeting: keep microphone / camera off, dismiss tips.
  static const String inCall = 'in_call';

  /// Leave the meeting (never "end for everyone").
  static const String leave = 'leave';
}

// ---------------------------------------------------------------------------
// Google Meet
// ---------------------------------------------------------------------------

const Map<String, Object?> _meet = {
  'states': [
    {
      'state': 'lobby_timeout',
      'text': [
        'no one responded to your request',
        'nobody responded to your request',
        'لم يستجب أحد لطلبك',
      ],
    },
    {
      'state': 'denied',
      'text': [
        'someone in the call denied your request',
        'denied your request to join',
        'your request to join was denied',
        'you can\'t join this call',
        'تم رفض طلب الانضمام',
      ],
    },
    {
      'state': 'removed',
      'text': [
        'you\'ve been removed from the meeting',
        'you have been removed from the meeting',
        'removed you from the meeting',
        'تمت إزالتك من الاجتماع',
      ],
    },
    {
      'state': 'ended',
      'text': [
        'you left the meeting',
        'you\'ve left the meeting',
        'the call has ended',
        'this call has ended',
        'ended the call for everyone',
        'the meeting has ended',
        'لقد غادرت الاجتماع',
        'انتهت المكالمة',
      ],
    },
    {
      'state': 'invalid',
      'text': [
        'check your meeting code',
        'invalid video call name',
        'meeting code isn\'t valid',
        'this video call link is invalid',
      ],
    },
    {
      'state': 'blocked',
      'text': [
        'you can\'t join this video call',
        'sign in to join this call',
        'to join this call, sign in',
        'only invited participants can join',
      ],
    },
    {
      'state': 'in_call',
      'css': ['[aria-label^="Leave call" i]', '[data-tooltip^="Leave call" i]'],
      'label': ['^leave call', 'مغادرة المكالمة'],
    },
    {
      'state': 'lobby',
      'text': [
        'asking to be let in',
        'you\'ll join the call when someone lets you in',
        'please wait until a meeting host brings you into the call',
        'someone will let you in soon',
        'جارٍ طلب السماح بالدخول',
      ],
    },
    {
      'state': 'prejoin',
      'css': [
        'input[aria-label="Your name" i]',
        'input[placeholder="Your name" i]',
      ],
      'label': ['^ask to join', '^join now', 'طلب الانضمام', 'الانضمام الآن'],
    },
  ],
  'alone': {
    'text': [
      'you\'re the only one here',
      'you are the only one here',
      'no one else is here',
      'أنت الشخص الوحيد هنا',
    ],
  },
  'participants': [
    r'(\d+)\s+(?:participants?|people|joined)',
    r'(?:participants?|people)\s*\(?(\d+)\)?',
  ],
  'actions': {
    'prejoin': [
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': [
          '^continue without microphone and camera',
          '^continue without camera',
          '^got it',
          '^dismiss',
        ],
      },
      {
        'do': 'fill',
        'name': 'name',
        'value': 'name',
        'required': true,
        'css': [
          'input[aria-label="Your name" i]',
          'input[placeholder="Your name" i]',
        ],
        'label': ['your name', 'اسمك'],
      },
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^turn off microphone'],
        'css': [
          '[role="button"][data-is-muted="false"][aria-label*="microphone" i]',
        ],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^turn off camera'],
        'css': [
          '[role="button"][data-is-muted="false"][aria-label*="camera" i]',
        ],
      },
      {
        'do': 'click',
        'name': 'ask_to_join',
        'required': true,
        'label': ['^ask to join', '^join now', 'طلب الانضمام', 'الانضمام الآن'],
      },
    ],
    'in_call': [
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^turn off microphone'],
        'css': [
          '[role="button"][data-is-muted="false"][aria-label*="microphone" i]',
        ],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^turn off camera'],
        'css': [
          '[role="button"][data-is-muted="false"][aria-label*="camera" i]',
        ],
      },
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^got it', '^dismiss'],
      },
    ],
    'leave': [
      {
        'do': 'click',
        'name': 'leave',
        'css': ['[aria-label^="Leave call" i]'],
        'label': ['^leave call', 'مغادرة المكالمة'],
      },
    ],
  },
};

// ---------------------------------------------------------------------------
// Microsoft Teams (web)
// ---------------------------------------------------------------------------

const List<String> _teamsLeaveCss = [
  '#hangup-button',
  '[data-tid="hangup-main-btn"]',
  '[data-tid="call-hangup"]',
  'button[aria-label^="Leave" i]',
];

const Map<String, Object?> _teams = {
  'states': [
    {
      'state': 'lobby_timeout',
      'text': [
        'no one responded to your request',
        'nobody responded to your request',
      ],
    },
    {
      'state': 'denied',
      'text': [
        'you were denied access to the meeting',
        'denied access to the meeting',
        'your request to join was declined',
        'someone in the meeting declined your request',
      ],
    },
    {
      'state': 'removed',
      'text': [
        'removed you from the meeting',
        'you\'ve been removed from this meeting',
        'you have been removed from this meeting',
      ],
    },
    {
      'state': 'ended',
      'text': [
        'the meeting has ended',
        'this meeting has ended',
        'you left the meeting',
        'you\'ve left the meeting',
        'thanks for joining',
      ],
    },
    {
      'state': 'invalid',
      'text': [
        'we couldn\'t find this meeting',
        'this link is invalid',
        'meeting id or passcode is incorrect',
        'meeting not found',
      ],
    },
    {
      'state': 'blocked',
      'text': [
        'anonymous users can\'t join',
        'sign in to join this meeting',
        'you need to sign in to join',
      ],
    },
    {
      'state': 'in_call',
      'css': _teamsLeaveCss,
      'label': ['^leave', '^hang up'],
    },
    {
      'state': 'lobby',
      'text': [
        'someone in the meeting should let you in soon',
        'we\'ve let people in the meeting know you\'re waiting',
        'we\'ll let people know you\'re waiting',
        'waiting for someone to let you in',
        'someone will let you in soon',
      ],
    },
    {
      'state': 'prejoin',
      'css': [
        '[data-tid="prejoin-join-button"]',
        'input[data-tid="prejoin-display-name-input"]',
      ],
      'label': ['^join now'],
    },
    {
      'state': 'launcher',
      'css': ['[data-tid="joinOnWeb"]'],
      'label': [
        '^continue on this browser',
        '^join on the web instead',
        '^use the web app instead',
      ],
      'text': ['how do you want to join'],
    },
  ],
  'alone': {
    'text': [
      'waiting for others to join',
      'you\'re the only one here',
      'no one else is here',
    ],
  },
  'participants': [
    r'participants?\s*\((\d+)\)',
    r'people\s*\((\d+)\)',
    r'(\d+)\s+participants?',
  ],
  'actions': {
    'launcher': [
      {
        'do': 'click',
        'name': 'continue_in_browser',
        'required': true,
        'css': ['[data-tid="joinOnWeb"]'],
        'label': [
          '^continue on this browser',
          '^join on the web instead',
          '^use the web app instead',
        ],
      },
    ],
    'prejoin': [
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^continue without audio or video', '^got it', '^dismiss'],
      },
      {
        'do': 'fill',
        'name': 'name',
        'value': 'name',
        'required': true,
        'css': ['input[data-tid="prejoin-display-name-input"]'],
        'label': [
          'type your name',
          'enter your name',
          'enter name',
          'your name',
        ],
      },
      {
        'do': 'off',
        'name': 'microphone_off',
        'css': [
          '[data-tid="toggle-mute"]',
          '[role="switch"][title*="microphone" i]',
          '[role="switch"][aria-label*="microphone" i]',
        ],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'css': [
          '[data-tid="toggle-video"]',
          '[role="switch"][title*="camera" i]',
          '[role="switch"][aria-label*="camera" i]',
        ],
      },
      {
        'do': 'click',
        'name': 'join_now',
        'required': true,
        'css': ['[data-tid="prejoin-join-button"]'],
        'label': ['^join now'],
      },
    ],
    'in_call': [
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^mute'],
        'css': ['#microphone-button[aria-pressed="true"]'],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^turn camera off'],
        'css': ['#video-button[aria-pressed="true"]'],
      },
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^got it', '^dismiss'],
      },
    ],
    'leave': [
      {
        'do': 'click',
        'name': 'leave',
        'css': _teamsLeaveCss,
        'label': ['^leave', '^hang up'],
      },
    ],
  },
};

// ---------------------------------------------------------------------------
// Zoom (web client, app.zoom.us/wc/join/<id>)
// ---------------------------------------------------------------------------

const List<String> _verificationText = [
  'i\'m not a robot',
  'verify you are human',
  'verify that you are human',
  'complete the captcha',
];

const List<String> _verificationCss = [
  'iframe[src*="recaptcha"]',
  'iframe[src*="hcaptcha"]',
  'iframe[title*="captcha" i]',
];

const Map<String, Object?> _zoom = {
  'states': [
    {
      'state': 'denied',
      'text': [
        'host has removed you from the waiting room',
        'you have been removed from the waiting room',
        'your request to join was declined',
      ],
    },
    {
      'state': 'removed',
      'text': [
        'you have been removed from this meeting',
        'you have been removed from the meeting',
        'host has removed you',
      ],
    },
    {
      'state': 'ended',
      'text': [
        'this meeting has been ended by host',
        'this meeting has been ended by the host',
        'the meeting has ended',
        'meeting has ended',
        'you have left the meeting',
      ],
    },
    {
      'state': 'invalid',
      'text': [
        'invalid meeting id',
        'meeting id is not valid',
        'this meeting id is not valid',
        'wrong meeting passcode',
        'incorrect passcode',
        'this meeting link is invalid',
      ],
    },
    {
      'state': 'blocked',
      'text': [
        'this meeting is for authorized attendees only',
        'only authenticated users can join',
        'sign in to join',
        'the host has disabled joining from the browser',
      ],
    },
    {
      'state': 'verification',
      'text': _verificationText,
      'css': _verificationCss,
    },
    {
      'state': 'in_call',
      'css': [
        '.footer__leave-btn',
        'button[aria-label="Leave" i]',
        'button[aria-label^="Leave meeting" i]',
      ],
      'label': ['^join audio by computer', '^join with computer audio'],
    },
    {
      'state': 'not_started',
      'text': [
        'waiting for the host to start this meeting',
        'waiting for the host to start the meeting',
        'the meeting has not started',
        'host has not started this meeting',
      ],
    },
    {
      'state': 'lobby',
      'text': [
        'please wait, the meeting host will let you in soon',
        'the meeting host will let you in soon',
        'you are in the waiting room',
        'host will let you in soon',
      ],
    },
    {
      'state': 'prejoin',
      'css': [
        '#input-for-name',
        '#input-for-pwd',
        'button.preview-join-button',
        'input[placeholder="Your Name" i]',
      ],
    },
    {
      'state': 'launcher',
      'label': ['^join from your browser', '^join from browser'],
      'text': ['click launch meeting below'],
    },
  ],
  'alone': {
    'text': ['you are the only one here', 'you\'re the only one here'],
  },
  'participants': [r'participants?\s*\(?(\d+)\)?', r'(\d+)\s+participants?'],
  'actions': {
    'launcher': [
      {
        'do': 'click',
        'name': 'join_from_browser',
        'required': true,
        'label': ['^join from your browser', '^join from browser'],
      },
    ],
    'prejoin': [
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^accept cookies', '^i agree', '^got it'],
      },
      {
        'do': 'fill',
        'name': 'name',
        'value': 'name',
        'required': true,
        'css': ['#input-for-name', 'input[placeholder="Your Name" i]'],
        'label': ['your name'],
      },
      {
        'do': 'fill',
        'name': 'passcode',
        'value': 'passcode',
        'css': ['#input-for-pwd', 'input[placeholder*="passcode" i]'],
      },
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^mute'],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^stop video', '^turn off camera'],
      },
      {
        'do': 'click',
        'name': 'join',
        'required': true,
        'css': ['button.preview-join-button', 'button.joinWindowBtn'],
        'label': ['^join'],
      },
    ],
    'in_call': [
      {
        // The meeting is silent until the web client joins its audio.
        'do': 'dismiss',
        'name': 'join_audio',
        'label': [
          '^join audio by computer',
          '^join with computer audio',
          '^computer audio',
        ],
      },
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^mute my microphone', '^mute'],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^stop my video', '^stop video'],
      },
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^got it', '^dismiss'],
      },
    ],
    'leave': [
      {
        'do': 'click',
        'name': 'leave',
        'css': ['.footer__leave-btn', 'button[aria-label="Leave" i]'],
        'label': ['^leave'],
      },
      {
        // The confirmation; never "End meeting for all".
        'do': 'dismiss',
        'name': 'leave_confirm',
        'label': ['^leave meeting'],
      },
    ],
  },
};

// ---------------------------------------------------------------------------
// Cisco Webex (web app) - experimental
// ---------------------------------------------------------------------------

const Map<String, Object?> _webex = {
  'states': [
    {
      'state': 'denied',
      'text': [
        'the host denied your request',
        'you were not admitted',
        'your request to join was declined',
      ],
    },
    {
      'state': 'removed',
      'text': [
        'you\'ve been removed from the meeting',
        'the host removed you from the meeting',
        'you have been expelled',
      ],
    },
    {
      'state': 'ended',
      'text': [
        'the meeting has ended',
        'this meeting has ended',
        'the host ended the meeting',
        'you\'ve left the meeting',
      ],
    },
    {
      'state': 'invalid',
      'text': [
        'meeting not found',
        'this meeting link is not valid',
        'incorrect meeting password',
      ],
    },
    {
      'state': 'blocked',
      'text': [
        'only users with an account can join',
        'sign in to join this meeting',
        'guests can\'t join',
      ],
    },
    {
      'state': 'verification',
      'text': _verificationText,
      'css': _verificationCss,
    },
    {
      'state': 'in_call',
      'css': [
        'button[aria-label^="Leave meeting" i]',
        '[data-test="call-leave"]',
      ],
      'label': ['^leave meeting'],
    },
    {
      'state': 'not_started',
      'text': [
        'waiting for the host to start the meeting',
        'the meeting hasn\'t started yet',
        'meeting has not started',
      ],
    },
    {
      'state': 'lobby',
      'text': [
        'you\'re in the lobby',
        'the host will let you in soon',
        'waiting for the host to let you in',
      ],
    },
    {
      'state': 'prejoin',
      'label': ['^join meeting', '^next'],
      'css': ['input[placeholder*="your name" i]'],
    },
    {
      'state': 'launcher',
      'css': ['#push_download_join_by_browser'],
      'label': ['^join from your browser', '^join from browser'],
    },
  ],
  'alone': {
    'text': ['you\'re the only one here', 'you are the only one here'],
  },
  'participants': [r'participants?\s*\((\d+)\)', r'(\d+)\s+participants?'],
  'actions': {
    'launcher': [
      {
        'do': 'click',
        'name': 'join_from_browser',
        'required': true,
        'css': ['#push_download_join_by_browser'],
        'label': ['^join from your browser', '^join from browser'],
      },
    ],
    'prejoin': [
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^accept', '^got it'],
      },
      {
        'do': 'fill',
        'name': 'name',
        'value': 'name',
        'required': true,
        'css': ['input[placeholder*="your name" i]', 'input[name="name"]'],
        'label': ['your name'],
      },
      {
        'do': 'dismiss',
        'name': 'next',
        'label': ['^next'],
      },
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^mute'],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^stop video', '^turn off video'],
      },
      {
        'do': 'dismiss',
        'name': 'computer_audio',
        'label': ['^use computer for audio', '^computer audio'],
      },
      {
        'do': 'click',
        'name': 'join',
        'required': true,
        'label': ['^join meeting'],
      },
    ],
    'in_call': [
      {
        'do': 'dismiss',
        'name': 'computer_audio',
        'label': ['^use computer for audio', '^connect audio'],
      },
      {
        'do': 'off',
        'name': 'microphone_off',
        'label': ['^mute'],
      },
      {
        'do': 'off',
        'name': 'camera_off',
        'label': ['^stop video'],
      },
      {
        'do': 'dismiss',
        'name': 'dismiss',
        'label': ['^got it', '^dismiss'],
      },
    ],
    'leave': [
      {
        'do': 'click',
        'name': 'leave',
        'css': ['button[aria-label^="Leave meeting" i]'],
        'label': ['^leave meeting'],
      },
      {
        'do': 'dismiss',
        'name': 'leave_confirm',
        'label': ['^leave meeting'],
      },
    ],
  },
};

/// Join-flow data per service id (`meet`, `teams`, `zoom`, `webex`; see
/// `platformScriptId`).
const Map<String, Map<String, Object?>> kBotPlatformScripts = {
  'meet': _meet,
  'teams': _teams,
  'zoom': _zoom,
  'webex': _webex,
};

/// How each flow has been checked (also in docs/SETUP.md): none has been
/// run against the live service from Windows yet.
const Map<String, String> kBotFlowVerification = {
  'meet': 'code review + mock page in headless Chrome',
  'teams': 'code review + mock page in headless Chrome',
  'zoom': 'code review + mock page in headless Chrome',
  'webex': 'code review only (experimental)',
};

// ---------------------------------------------------------------------------
// Page script
// ---------------------------------------------------------------------------

/// The interpreter evaluated in the meeting page: `(cfg, mode, vars)`.
/// `mode` is `probe` (returns the page state) or an action group of
/// [BotActions]. Returns a JSON string:
/// * probe: `{state, alone, participants, url, ready}`;
/// * actions: `{done: [step names], missing: [required step names]}`.
///
/// ES5 only, no dependencies, never throws (errors are returned as
/// `{error: message}`).
const String kBotPageScript = r'''
(function (cfg, mode, vars) {
  'use strict';
  var BUTTONS = 'button, [role="button"], [role="switch"], [role="menuitem"], ' +
      '[role="checkbox"], a[href], input[type="button"], input[type="submit"]';
  var INPUTS = 'input[type="text"], input:not([type]), textarea';
  function norm(s) {
    return String(s || '').replace(/\s+/g, ' ').trim().toLowerCase();
  }
  function docs() {
    var out = [document];
    var frames = document.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      try {
        var d = frames[i].contentDocument;
        if (d && d.body) out.push(d);
      } catch (e) { /* cross-origin frame */ }
    }
    return out;
  }
  function all(sel) {
    var out = [];
    var ds = docs();
    for (var i = 0; i < ds.length; i++) {
      try {
        var found = ds[i].querySelectorAll(sel);
        for (var j = 0; j < found.length; j++) out.push(found[j]);
      } catch (e) { /* invalid selector in this engine */ }
    }
    return out;
  }
  function visible(el) {
    if (!el || !el.isConnected) return false;
    var rects = el.getClientRects();
    if (!rects || rects.length === 0) return false;
    var view = el.ownerDocument.defaultView || window;
    var st = view.getComputedStyle(el);
    return st.visibility !== 'hidden' && st.display !== 'none';
  }
  function labelOf(el) {
    var parts = [el.getAttribute('aria-label'), el.getAttribute('title'),
      el.getAttribute('data-tooltip'), el.getAttribute('placeholder'),
      el.innerText || el.textContent || el.value];
    var out = [];
    for (var i = 0; i < parts.length; i++) if (parts[i]) out.push(norm(parts[i]));
    return out;
  }
  function labelMatches(labels, pattern) {
    var p = norm(pattern);
    var prefix = p.charAt(0) === '^';
    if (prefix) p = p.substring(1);
    for (var i = 0; i < labels.length; i++) {
      if (prefix ? labels[i].indexOf(p) === 0 : labels[i].indexOf(p) >= 0) {
        return true;
      }
    }
    return false;
  }
  function byCss(list) {
    list = list || [];
    for (var i = 0; i < list.length; i++) {
      var els = all(list[i]);
      for (var j = 0; j < els.length; j++) if (visible(els[j])) return els[j];
    }
    return null;
  }
  function byLabel(list, sel) {
    list = list || [];
    if (list.length === 0) return null;
    var cands = all(sel || BUTTONS);
    for (var i = 0; i < list.length; i++) {
      for (var j = 0; j < cands.length; j++) {
        var el = cands[j];
        if (visible(el) && labelMatches(labelOf(el), list[i])) return el;
      }
    }
    return null;
  }
  function find(spec, sel) {
    return byCss(spec.css) || byLabel(spec.label, sel);
  }
  var pageTextCache = null;
  function pageText() {
    if (pageTextCache !== null) return pageTextCache;
    var ds = docs();
    var parts = [];
    for (var i = 0; i < ds.length; i++) {
      if (ds[i].body) parts.push(ds[i].body.innerText || '');
    }
    pageTextCache = norm(parts.join('\n'));
    return pageTextCache;
  }
  function textMatches(list) {
    list = list || [];
    if (list.length === 0) return false;
    var t = pageText();
    for (var i = 0; i < list.length; i++) {
      if (t.indexOf(norm(list[i])) >= 0) return true;
    }
    return false;
  }
  function matches(spec) {
    if (!spec) return false;
    return textMatches(spec.text) || !!find(spec);
  }
  function disabled(el) {
    return !!el.disabled || el.getAttribute('aria-disabled') === 'true';
  }
  function isOn(el) {
    return el.getAttribute('aria-checked') === 'true' ||
        el.getAttribute('aria-pressed') === 'true' ||
        el.getAttribute('data-is-muted') === 'false';
  }
  function setValue(el, value) {
    var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype
        : HTMLInputElement.prototype;
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    el.focus();
    if (desc && desc.set) desc.set.call(el, value); else el.value = value;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function participants() {
    var res = cfg.participants || [];
    var labels = [];
    var els = all('[aria-label], [title], [data-tooltip]');
    for (var i = 0; i < els.length && i < 2000; i++) {
      var l = labelOf(els[i]);
      for (var k = 0; k < l.length; k++) labels.push(l[k]);
    }
    for (var r = 0; r < res.length; r++) {
      var re = new RegExp(res[r], 'i');
      for (var j = 0; j < labels.length; j++) {
        var m = re.exec(labels[j]);
        if (m && m[1]) return parseInt(m[1], 10);
      }
    }
    return null;
  }
  function probe() {
    var state = 'unknown';
    var states = cfg.states || [];
    for (var i = 0; i < states.length; i++) {
      if (matches(states[i])) { state = states[i].state; break; }
    }
    return {
      state: state,
      alone: state === 'in_call' && matches(cfg.alone),
      participants: state === 'in_call' ? participants() : null,
      url: String(location.href),
      ready: document.readyState
    };
  }
  function act(group) {
    var steps = (cfg.actions || {})[group] || [];
    var done = [];
    var missing = [];
    for (var i = 0; i < steps.length; i++) {
      var s = steps[i];
      if (s['do'] === 'fill') {
        var input = byCss(s.css) || byLabel(s.label, INPUTS);
        var v = String((vars || {})[s.value] || '');
        if (!input || !v) { if (s.required) { missing.push(s.name); break; } continue; }
        if (input.value !== v) setValue(input, v);
        done.push(s.name);
      } else if (s['do'] === 'off') {
        var labelled = byLabel(s.label);
        if (labelled && !disabled(labelled)) { labelled.click(); done.push(s.name); continue; }
        var css = s.css || [];
        for (var c = 0; c < css.length; c++) {
          var els = all(css[c]);
          for (var e = 0; e < els.length; e++) {
            if (visible(els[e]) && isOn(els[e]) && !disabled(els[e])) {
              els[e].click();
              done.push(s.name);
            }
          }
        }
      } else {
        var el = find(s);
        if (el && !disabled(el)) { el.click(); done.push(s.name); }
        else if (s.required) { missing.push(s.name); break; }
      }
    }
    return { done: done, missing: missing };
  }
  try {
    return JSON.stringify(mode === 'probe' ? probe() : act(mode));
  } catch (err) {
    return JSON.stringify({ error: String(err && err.message || err) });
  }
})
''';

/// The JavaScript expression running [mode] (`probe` or a [BotActions]
/// group) of the service [platformId] with [vars] (e.g. `{name: …}`).
String botPageExpression(
  String platformId,
  String mode, {
  Map<String, String> vars = const {},
}) {
  final cfg = kBotPlatformScripts[platformId];
  if (cfg == null) throw ArgumentError.value(platformId, 'platformId');
  return '${kBotPageScript.trim()}'
      '(${jsonEncode(cfg)}, ${jsonEncode(mode)}, ${jsonEncode(vars)})';
}

/// What a probe saw.
class BotProbe {
  /// Creates a probe result.
  const BotProbe({
    this.state = BotPageState.unknown,
    this.alone = false,
    this.participants,
    this.url,
    this.error,
  });

  /// Parses the JSON string returned by the page script.
  factory BotProbe.fromJson(Object? raw) {
    final map = _decode(raw);
    if (map == null) return const BotProbe(error: 'unreadable');
    final p = map['participants'];
    return BotProbe(
      state: botPageStateOf(map['state']),
      alone: map['alone'] == true,
      participants: p is num ? p.toInt() : null,
      url: map['url'] is String ? map['url'] as String : null,
      error: map['error'] is String ? map['error'] as String : null,
    );
  }

  /// Recognised state.
  final BotPageState state;

  /// The page says the bot is alone in the meeting.
  final bool alone;

  /// Participant count shown by the page, when readable.
  final int? participants;

  /// Current address.
  final String? url;

  /// Script error, if any.
  final String? error;

  @override
  String toString() =>
      'BotProbe(${state.name}, alone: $alone, participants: $participants'
      '${error == null ? '' : ', error: $error'})';
}

/// Result of an action group.
class BotActionResult {
  /// Creates a result.
  const BotActionResult({this.done = const [], this.missing = const []});

  /// Parses the JSON string returned by the page script.
  factory BotActionResult.fromJson(Object? raw) {
    final map = _decode(raw);
    if (map == null) return const BotActionResult();
    List<String> list(Object? v) => v is List
        ? [
            for (final x in v)
              if (x is String) x,
          ]
        : const [];
    return BotActionResult(
      done: list(map['done']),
      missing: list(map['missing']),
    );
  }

  /// Steps that did something.
  final List<String> done;

  /// Required steps whose element was not found (or disabled).
  final List<String> missing;
}

Map<String, Object?>? _decode(Object? raw) {
  Object? v = raw;
  if (v is String) {
    try {
      v = jsonDecode(v);
    } on FormatException {
      return null;
    }
  }
  if (v is Map) return v.cast<String, Object?>();
  return null;
}
