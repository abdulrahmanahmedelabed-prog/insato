// Audio file formats accepted by the recording import, how they are
// recognised (magic bytes first, then the file extension) and the limits
// applied before anything is decoded. Pure Dart.

import 'dart:typed_data';

/// Largest file accepted (2 GiB).
const int kMaxImportBytes = 2 * 1024 * 1024 * 1024;

/// Longest recording accepted.
const Duration kMaxImportDuration = Duration(hours: 8);

/// Shortest recording accepted.
const Duration kMinImportDuration = Duration(seconds: 1);

/// Input device key stored in `Meeting.inputDevice` of imported meetings
/// (`<type>|<label>`, see `lib/features/voice/voice_devices.dart`). It marks
/// the meeting as imported, and voiceprints learned on the device
/// microphone are matched against a recording made elsewhere (phone call,
/// other recorder) with the relaxed cross-device threshold.
const String kImportedInputDevice = 'unknown|imported';

/// Container / codec family of an audio file.
enum AudioContainer {
  /// RIFF/WAVE (decoded in pure Dart when PCM or float).
  wav('WAV', ['wav', 'wave']),

  /// MPEG-1/2 layer III.
  mp3('MP3', ['mp3']),

  /// Raw AAC in ADTS frames.
  aac('AAC', ['aac']),

  /// MPEG-4 (M4A / MP4 / M4B), usually AAC or ALAC.
  mp4('M4A', ['m4a', 'mp4', 'm4b', 'mov']),

  /// 3GPP / 3GPP2 (Android call recorders: AMR or AAC inside).
  threeGp('3GP', ['3gp', '3gpp', '3g2']),

  /// AMR narrow-band (`#!AMR`).
  amrNb('AMR', ['amr']),

  /// AMR wide-band (`#!AMR-WB`).
  amrWb('AMR-WB', ['awb']),

  /// Ogg (Vorbis or Opus).
  ogg('OGG', ['ogg', 'oga']),

  /// Opus in Ogg.
  opus('OPUS', ['opus']),

  /// FLAC.
  flac('FLAC', ['flac']),

  /// Apple Core Audio Format.
  caf('CAF', ['caf']),

  /// AIFF / AIFC.
  aiff('AIFF', ['aif', 'aiff', 'aifc']),

  /// WebM / Matroska audio.
  webm('WEBM', ['webm', 'weba', 'mka']),

  /// Windows Media Audio.
  wma('WMA', ['wma']);

  const AudioContainer(this.label, this.extensions);

  /// Short display name (Latin, shown inside Arabic text).
  final String label;

  /// File extensions (lower case, without the dot).
  final List<String> extensions;
}

/// Every extension the import accepts.
final List<String> kImportExtensions = [
  for (final c in AudioContainer.values) ...c.extensions,
];

/// MIME types offered to the file chooser (Android) and claimed by the
/// share intent filter.
const List<String> kImportMimeTypes = [
  'audio/*',
  'video/mp4',
  'video/3gpp',
  'application/ogg',
];

/// Uniform type identifiers offered to the iOS document picker. Unknown
/// identifiers are ignored by the picker; `public.audio` covers the system
/// audio types.
const List<String> kImportUtis = [
  'public.audio',
  'public.mpeg-4-audio',
  'public.mp3',
  'com.apple.m4a-audio',
  'com.microsoft.waveform-audio',
  'com.apple.coreaudio-format',
  'public.aiff-audio',
  'public.aifc-audio',
  'org.3gpp.adaptive-multi-rate-audio',
  'public.3gpp',
  'public.3gpp2',
  'public.mpeg-4',
  'org.xiph.flac',
  'org.xiph.ogg',
  'org.xiph.ogg-audio',
  'org.xiph.opus',
];

/// Extension of [fileName] (lower case, without the dot), or ''.
String fileExtension(String fileName) {
  final base = fileName.split(RegExp(r'[\\/]')).last;
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

/// The container known by [extension] (see [fileExtension]), or null.
AudioContainer? containerForExtension(String extension) {
  final e = extension.toLowerCase();
  for (final c in AudioContainer.values) {
    if (c.extensions.contains(e)) return c;
  }
  return null;
}

/// Result of [sniffAudioHeader].
sealed class SniffResult {
  const SniffResult();
}

/// The header is a known audio container.
class SniffedAudio extends SniffResult {
  /// Creates a result.
  const SniffedAudio(this.container);

  /// The container.
  final AudioContainer container;
}

/// The header is a known non-audio file (document, image, archive).
class SniffedNotAudio extends SniffResult {
  /// Creates a result.
  const SniffedNotAudio(this.kind);

  /// What it is (for logs).
  final String kind;
}

/// The header is not recognised.
class SniffedUnknown extends SniffResult {
  /// Creates a result.
  const SniffedUnknown();
}

bool _ascii(Uint8List b, int offset, String s) {
  if (b.length < offset + s.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[offset + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

/// Recognises an audio container from the first bytes of a file ([head],
/// 64 bytes are enough).
SniffResult sniffAudioHeader(Uint8List head) {
  if (head.length < 4) return const SniffedUnknown();
  if (_ascii(head, 0, 'RIFF') && _ascii(head, 8, 'WAVE')) {
    return const SniffedAudio(AudioContainer.wav);
  }
  if (_ascii(head, 0, 'RF64') && _ascii(head, 8, 'WAVE')) {
    return const SniffedAudio(AudioContainer.wav);
  }
  if (_ascii(head, 0, 'FORM') &&
      (_ascii(head, 8, 'AIFF') || _ascii(head, 8, 'AIFC'))) {
    return const SniffedAudio(AudioContainer.aiff);
  }
  if (_ascii(head, 0, 'caff')) return const SniffedAudio(AudioContainer.caf);
  if (_ascii(head, 0, '#!AMR-WB')) {
    return const SniffedAudio(AudioContainer.amrWb);
  }
  if (_ascii(head, 0, '#!AMR')) return const SniffedAudio(AudioContainer.amrNb);
  if (_ascii(head, 0, 'OggS')) {
    return SniffedAudio(
      _ascii(head, 28, 'OpusHead') ? AudioContainer.opus : AudioContainer.ogg,
    );
  }
  if (_ascii(head, 0, 'fLaC')) return const SniffedAudio(AudioContainer.flac);
  if (_ascii(head, 4, 'ftyp')) {
    final brand = head.length >= 12
        ? String.fromCharCodes(head.sublist(8, 12))
        : '';
    if (brand.startsWith('3g')) {
      return const SniffedAudio(AudioContainer.threeGp);
    }
    return const SniffedAudio(AudioContainer.mp4);
  }
  if (head[0] == 0x1A && head[1] == 0x45 && head[2] == 0xDF && head[3] == 0xA3) {
    return const SniffedAudio(AudioContainer.webm);
  }
  if (head[0] == 0x30 && head[1] == 0x26 && head[2] == 0xB2 && head[3] == 0x75) {
    // ASF header GUID (WMA / WMV).
    return const SniffedAudio(AudioContainer.wma);
  }
  if (_ascii(head, 0, 'ID3')) return const SniffedAudio(AudioContainer.mp3);
  if (head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) {
    // MPEG audio frame sync. Layer bits 00 = AAC in ADTS.
    final layer = (head[1] >> 1) & 0x03;
    if ((head[1] & 0xF6) == 0xF0 && layer == 0) {
      return const SniffedAudio(AudioContainer.aac);
    }
    if (layer != 0) return const SniffedAudio(AudioContainer.mp3);
  }
  if (_ascii(head, 0, '%PDF')) return const SniffedNotAudio('pdf');
  if (_ascii(head, 0, 'PK')) return const SniffedNotAudio('zip');
  if (head[0] == 0x89 && _ascii(head, 1, 'PNG')) {
    return const SniffedNotAudio('png');
  }
  if (head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) {
    return const SniffedNotAudio('jpeg');
  }
  if (_ascii(head, 0, 'GIF8')) return const SniffedNotAudio('gif');
  if (head[0] == 0xD0 && head[1] == 0xCF && head[2] == 0x11) {
    return const SniffedNotAudio('ole');
  }
  return const SniffedUnknown();
}

/// The container of a file from its first bytes ([head]) and its
/// [fileName]: the magic bytes win, the extension decides when the header
/// is not recognised. Null when the file is not audio (or not recognised
/// at all).
AudioContainer? detectAudioContainer(Uint8List head, String fileName) {
  final sniffed = sniffAudioHeader(head);
  return switch (sniffed) {
    SniffedAudio(:final container) => container,
    SniffedNotAudio() => null,
    SniffedUnknown() => containerForExtension(fileExtension(fileName)),
  };
}
