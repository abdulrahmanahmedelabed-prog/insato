// On-device speech recognition with sherpa-onnx Whisper (multilingual).
//
// Besides the FFI engine this file holds the pure-Dart pre/post-processing
// (audio preparation, Whisper language tags, hallucination filter) which is
// unit-tested without the native library.

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'model_catalog.dart';

bool _bindingsReady = false;

/// Loads the sherpa-onnx native bindings for the current isolate (once).
///
/// Every isolate that touches sherpa objects must call this first; static
/// state is per isolate, so the guard is too.
void ensureSherpaBindings() {
  if (_bindingsReady) return;
  sherpa.initBindings();
  _bindingsReady = true;
}

/// Inference threads for one heavy model: `min(4, max(1, cores - 1))`.
int recommendedThreadCount([int? processors]) {
  final n = processors ?? Platform.numberOfProcessors;
  return math.min(4, math.max(1, n - 1));
}

/// [AsrEngine] running a multilingual Whisper model through sherpa-onnx.
///
/// Not thread-safe; use it from one isolate (normally the processing
/// isolate, see `processing_isolate.dart`).
class SherpaAsrEngine implements AsrEngine {
  /// Creates an engine for the Whisper files in [paths].
  ///
  /// [defaultLanguage] is an ISO-639-1 code forced on every call without a
  /// hint (null = auto-detect per segment).
  SherpaAsrEngine({
    required this.paths,
    this.defaultLanguage,
    int? numThreads,
    this.minRmsDbfs = -60,
  }) : numThreads = numThreads ?? recommendedThreadCount();

  /// Model files.
  final WhisperModelPaths paths;

  /// Language used when [transcribe] gets no hint (null = auto-detect).
  final String? defaultLanguage;

  /// ONNX Runtime intra-op threads.
  final int numThreads;

  /// Segments quieter than this (dBFS RMS) are treated as noise and not
  /// decoded at all.
  final double minRmsDbfs;

  sherpa.OfflineRecognizer? _recognizer;
  String _currentLanguage = '';

  @override
  String get name {
    final base = p.basename(paths.encoder);
    final i = base.toLowerCase().indexOf('-encoder');
    final variant = i > 0 ? base.substring(0, i) : 'whisper';
    final label = variant.startsWith('whisper') ? variant : 'whisper-$variant';
    return '$label (on-device)';
  }

  sherpa.OfflineRecognizerConfig _config(String language) {
    return sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: paths.encoder,
          decoder: paths.decoder,
          language: language,
          task: 'transcribe',
          // -1 = sherpa-onnx's default tail padding for Whisper, tuned
          // upstream; short segments are additionally padded here.
          tailPaddings: -1,
        ),
        tokens: paths.tokens,
        numThreads: numThreads,
        provider: 'cpu',
        debug: false,
      ),
      decodingMethod: 'greedy_search',
    );
  }

  @override
  Future<void> initialize() async {
    if (_recognizer != null) return;
    try {
      ensureSherpaBindings();
      _currentLanguage = normalizeLanguageCode(defaultLanguage) ?? '';
      _recognizer = sherpa.OfflineRecognizer(_config(_currentLanguage));
    } catch (e) {
      throw ModelException(
        'تعذّر تحميل نموذج التفريغ الصوتي. قد تكون الملفات تالفة أو أن '
        'ذاكرة الجهاز غير كافية لهذا النموذج؛ جرّب نموذجاً أصغر.',
        debugDetails: 'Whisper init ($paths): $e',
        cause: e,
      );
    }
  }

  void _useLanguage(String language) {
    if (language == _currentLanguage) return;
    final r = _recognizer!;
    try {
      r.setConfig(_config(language));
    } catch (_) {
      // Fallback: rebuild the recognizer with the new language.
      r.free();
      _recognizer = sherpa.OfflineRecognizer(_config(language));
    }
    _currentLanguage = language;
  }

  @override
  Future<AsrResult> transcribe(SpeechSegment segment,
      {String? languageHint}) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      throw const AsrException('محرك التفريغ الصوتي غير مهيّأ.');
    }
    final samples = segment.samples;
    if (samples.isEmpty || rmsDbfs(samples) < minRmsDbfs) {
      return const AsrResult(text: '');
    }
    final hint = normalizeLanguageCode(languageHint) ??
        normalizeLanguageCode(defaultLanguage);
    sherpa.OfflineStream? stream;
    try {
      _useLanguage(hint ?? '');
      final audio = prepareForWhisper(samples);
      stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: audio, sampleRate: kSampleRate);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      final text = WhisperOutputFilter.clean(result.text);
      if (text.isEmpty) return const AsrResult(text: '');
      return AsrResult(
        text: text,
        language: normalizeWhisperLanguage(result.lang) ?? hint,
      );
    } catch (e) {
      throw AsrException(
        'تعذّر تفريغ أحد المقاطع الصوتية.',
        debugDetails: 'segment ${segment.index}: $e',
        cause: e,
      );
    } finally {
      stream?.free();
    }
  }

  @override
  Future<void> dispose() async {
    _recognizer?.free();
    _recognizer = null;
  }
}

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested).
// ---------------------------------------------------------------------------

/// RMS level of [samples] in dBFS (-120 for silence).
double rmsDbfs(Float32List samples) {
  if (samples.isEmpty) return -120;
  var sum = 0.0;
  for (final v in samples) {
    sum += v * v;
  }
  final r = math.sqrt(sum / samples.length);
  if (!(r > 0) || !r.isFinite) return -120;
  return math.max(-120, 20 * math.log(r) / math.ln10);
}

/// Prepares a segment for Whisper:
///
/// * quiet recordings (peak below [quietPeak]) are amplified towards
///   [targetPeak], at most [maxGain]x (far-field meeting microphones are
///   often very quiet; Whisper is far more reliable on normal levels);
/// * segments shorter than [minSeconds] are centred in silence so that
///   Whisper sees at least that much audio (reduces hallucinations on very
///   short utterances).
///
/// Returns a new list; [samples] is never modified.
Float32List prepareForWhisper(
  Float32List samples, {
  double minSeconds = 1.0,
  double quietPeak = 0.25,
  double targetPeak = 0.7,
  double maxGain = 8.0,
}) {
  var peak = 0.0;
  for (final v in samples) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  var gain = 1.0;
  if (peak > 1e-4 && peak < quietPeak) {
    gain = math.min(maxGain, targetPeak / peak);
  }
  final minSamples = (minSeconds * kSampleRate).round();
  final total = math.max(minSamples, samples.length);
  final lead = (total - samples.length) ~/ 2;
  final out = Float32List(total);
  for (var i = 0; i < samples.length; i++) {
    out[lead + i] = (samples[i] * gain).clamp(-1.0, 1.0);
  }
  return out;
}

/// Lower-case primary subtag of a language code (`en-US` → `en`), or null
/// for null/empty/invalid input.
String? normalizeLanguageCode(String? code) {
  if (code == null) return null;
  final c = code.trim().toLowerCase().split(RegExp('[-_]')).first;
  if (!RegExp(r'^[a-z]{2,3}$').hasMatch(c)) return null;
  return c;
}

/// Converts Whisper's language tag (`<|ar|>`, `ar`, `Arabic`) to an
/// ISO-639-1 code, or null when unknown.
String? normalizeWhisperLanguage(String? lang) {
  if (lang == null) return null;
  var s = lang.trim();
  if (s.startsWith('<|') && s.endsWith('|>')) {
    s = s.substring(2, s.length - 2);
  }
  s = s.trim().toLowerCase();
  if (s.isEmpty) return null;
  final byName = _whisperLanguageNames[s];
  if (byName != null) return byName;
  return normalizeLanguageCode(s);
}

const Map<String, String> _whisperLanguageNames = {
  'arabic': 'ar',
  'english': 'en',
  'french': 'fr',
  'german': 'de',
  'spanish': 'es',
  'turkish': 'tr',
  'persian': 'fa',
  'urdu': 'ur',
  'hindi': 'hi',
  'chinese': 'zh',
  'japanese': 'ja',
  'russian': 'ru',
  'italian': 'it',
  'portuguese': 'pt',
  'indonesian': 'id',
  'malay': 'ms',
  'hebrew': 'he',
};

/// Conservative removal of well-known Whisper artefacts.
///
/// Removes non-speech annotations (`[موسيقى]`, `(applause)`, `♪`),
/// subtitle-credit / "thanks for watching" sentences that Whisper invents on
/// silence or noise, and collapses runaway repetition loops. Real speech is
/// left untouched as far as possible: phrases are only removed when they are
/// characteristic of training-data credits, never ordinary words.
abstract final class WhisperOutputFilter {
  static final RegExp _specialTokens = RegExp(r'<\|[^|>]*\|>');
  static final RegExp _brackets = RegExp(r'\[[^\]]*\]|【[^】]*】|\{[^}]*\}');
  static final RegExp _music = RegExp('[♪♫♬🎵🎶]+');
  static final RegExp _asterisk = RegExp(r'\*[^*\n]{1,40}\*');
  static final RegExp _parens = RegExp(r'[(（]([^()（）]{1,40})[)）]');

  static final RegExp _annotationWords = RegExp(
    r'^\s*(music|applause|laughter|laughs|laughing|silence|noise|inaudible|'
    r'background noise|blank_audio|no speech|cough|coughing|sighs?|'
    r'موسيقى|موسيقي|تصفيق|ضحك|ضحكات|صمت|ضوضاء|سعال|تنهد|غير مسموع)'
    r'[\s.!]*$',
    caseSensitive: false,
    unicode: true,
  );

  static final List<RegExp> _creditSentences = [
    RegExp(r'amara\.org', caseSensitive: false),
    RegExp(r'\bsubtitles?\s+(by|created\s+by|made\s+by|provided\s+by)\b',
        caseSensitive: false),
    RegExp(r'\bsous-titr(es|age|é)', caseSensitive: false),
    RegExp(r'\buntertitel\b', caseSensitive: false),
    RegExp(r'\bsubt[ií]tulos\s+(realizados\s+)?por\b', caseSensitive: false),
    RegExp(r'\bthanks?\s+(you\s+)?(so\s+much\s+)?for\s+watching\b',
        caseSensitive: false),
    RegExp(r'\bplease\s+(like\s+(and|&)\s+)?subscribe\b',
        caseSensitive: false),
    RegExp(r'\bsubscribe\s+to\s+(my|our|the)\s+channel\b',
        caseSensitive: false),
    RegExp(r"\bdon'?t\s+forget\s+to\s+(like\s+(and|&)\s+)?subscribe\b",
        caseSensitive: false),
    RegExp(r'\bmerci\s+d.avoir\s+regard[ée]', caseSensitive: false),
    RegExp(r'نانسي\s*قنقر'),
    RegExp(r'اشتركو?ا?\s+في\s+(ال)?قناة'),
    RegExp(r'لا\s+تنسو?ا?\s+(ال)?[اإ]شتراك'),
    RegExp(r'شكر[اًا]*\s+(لكم\s+)?(على\s*|ل)(ال|ل)?مشاهد[ةه]'),
    RegExp(r'ترجمة\s+(و\s*)?(تدقيق|سبتايتل)'),
    RegExp(r'ご視聴ありがとうございました'),
    RegExp(r'字幕(由|提供|志愿者)'),
    RegExp(r'请不吝点赞'),
    RegExp(r'Редактор\s+субтитров', caseSensitive: false),
    RegExp(r'Субтитры\s+(сделал|создавал|подогнал)', caseSensitive: false),
    RegExp(r'Продолжение\s+следует', caseSensitive: false),
  ];

  static final Set<String> _wholeOutputHallucinations = {
    'you',
    'bye',
    'bye.',
    'you.',
    '...',
    '.',
    'اشتركوا',
    'اشترك',
  };

  // Splits after sentence punctuation followed by whitespace (never inside
  // numbers such as `3.5` or domains).
  static final RegExp _sentenceSplit = RegExp(r'(?<=[.!?؟。！？])\s+|\n+');
  static final RegExp _hasContent = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _wordPunct = RegExp(r'[\p{P}\p{S}]', unicode: true);

  /// Returns the cleaned transcript, or an empty string when nothing but
  /// artefacts remains.
  static String clean(String raw) {
    var s = raw.replaceAll(_specialTokens, ' ');
    s = s.replaceAll(_brackets, ' ');
    s = s.replaceAll(_music, ' ');
    s = s.replaceAll(_asterisk, ' ');
    s = s.replaceAllMapped(_parens, (m) {
      return _annotationWords.hasMatch(m.group(1)!) ? ' ' : m.group(0)!;
    });
    s = _collapseWhitespace(s);
    if (s.isEmpty) return '';
    if (_annotationWords.hasMatch(s)) return '';

    final sentences = s.split(_sentenceSplit);
    final kept = sentences
        .where((x) => !_creditSentences.any((r) => r.hasMatch(x)))
        .toList();
    s = _collapseWhitespace(kept.join(' '));

    s = collapseRepetitions(s);
    s = s.replaceAllMapped(
        RegExp(r'([^\p{N}\s])\1{9,}', unicode: true), (m) => m.group(1)! * 3);
    s = _collapseWhitespace(s);

    if (_wholeOutputHallucinations.contains(s.toLowerCase())) return '';
    if (!_hasContent.hasMatch(s)) return '';
    return s;
  }

  /// Collapses runaway loops: an n-gram (1–8 words) repeated consecutively
  /// at least 4 times (single words) or 3 times (longer phrases) is reduced
  /// to one occurrence. Comparison ignores case and punctuation.
  static String collapseRepetitions(String text) {
    var words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 3) return words.join(' ');
    var changed = true;
    while (changed) {
      changed = false;
      final keys = words.map(_wordKey).toList();
      for (var n = 1; n <= 8 && !changed; n++) {
        final minRepeats = n == 1 ? 4 : 3;
        for (var i = 0; i + n * minRepeats <= words.length; i++) {
          if (keys[i].isEmpty) continue;
          var reps = 1;
          while (i + (reps + 1) * n <= words.length &&
              _sameGram(keys, i, i + reps * n, n)) {
            reps++;
          }
          if (reps >= minRepeats) {
            words = [
              ...words.sublist(0, i + n),
              ...words.sublist(i + reps * n),
            ];
            changed = true;
            break;
          }
        }
      }
    }
    return words.join(' ');
  }

  static String _wordKey(String w) =>
      w.replaceAll(_wordPunct, '').toLowerCase();

  static bool _sameGram(List<String> keys, int a, int b, int n) {
    for (var k = 0; k < n; k++) {
      if (keys[a + k] != keys[b + k]) return false;
    }
    return true;
  }

  static String _collapseWhitespace(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
