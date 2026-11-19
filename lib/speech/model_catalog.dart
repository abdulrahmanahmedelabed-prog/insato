// Catalog of downloadable on-device models (VAD, Whisper ASR, speaker
// embedding) and the pure-Dart logic that locates model files inside an
// installed model directory.
//
// This file has no FFI / Flutter dependencies so it can be used from any
// isolate and from plain unit tests.

import 'dart:io';

import 'package:path/path.dart' as p;

/// What a model is used for in the pipeline.
enum ModelKind {
  /// Voice activity detection (silero VAD).
  vad,

  /// Speech recognition (multilingual Whisper).
  asr,

  /// Speaker embedding extraction (voiceprints).
  speaker,
}

/// Static description of one downloadable model.
class ModelSpec {
  /// Creates a model description. See the fields for semantics.
  const ModelSpec({
    required this.id,
    required this.displayNameAr,
    required this.descriptionAr,
    required this.kind,
    required this.url,
    required this.approxSizeMb,
    required this.archive,
    required this.requiredFiles,
    this.extractFiles,
    this.recommended = false,
  });

  /// Stable identifier, also used as the on-disk directory name.
  final String id;

  /// Arabic display name.
  final String displayNameAr;

  /// Arabic description (accuracy / speed / suitable devices).
  final String descriptionAr;

  /// Pipeline role.
  final ModelKind kind;

  /// Absolute download URL.
  final String url;

  /// Approximate download size in megabytes (shown before download and used
  /// for progress when the server sends no `Content-Length`).
  final int approxSizeMb;

  /// True when [url] points to a `.tar.bz2` archive that must be extracted.
  final bool archive;

  /// Basename glob patterns (`*` and `?` wildcards, case-insensitive). Every
  /// pattern must match at least one non-empty file of an installed model.
  final List<String> requiredFiles;

  /// Optional basename glob patterns restricting which archive entries are
  /// extracted (saves a lot of storage: Whisper archives also ship large
  /// fp32 weights that are not used). Null extracts everything.
  final List<String>? extractFiles;

  /// True for the default choice of its [kind].
  final bool recommended;

  /// File name of the downloaded artefact (last URL path segment).
  String get fileName => Uri.parse(url).pathSegments.last;

  @override
  String toString() => 'ModelSpec($id)';
}

/// Base URL of the upstream sherpa-onnx release assets.
const String kSherpaReleaseBase =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download';

const List<String> _whisperRequired = [
  '*-encoder*.onnx',
  '*-decoder*.onnx',
  '*-tokens.txt',
];

// Only the int8 weights (and the token table) are used on device; the fp32
// weights in the upstream archives are several times larger.
const List<String> _whisperExtract = [
  '*-encoder.int8.onnx',
  '*-decoder.int8.onnx',
  '*-tokens.txt',
];

/// All models the app knows about.
abstract final class ModelCatalog {
  /// Silero VAD.
  static const ModelSpec sileroVad = ModelSpec(
    id: 'silero-vad',
    displayNameAr: 'كاشف الكلام (Silero VAD)',
    descriptionAr:
        'نموذج صغير يكتشف مقاطع الكلام ويتجاهل الصمت والضوضاء. مطلوب دائماً.',
    kind: ModelKind.vad,
    url: '$kSherpaReleaseBase/asr-models/silero_vad.onnx',
    approxSizeMb: 2,
    archive: false,
    requiredFiles: ['*.onnx'],
    recommended: true,
  );

  /// Whisper large-v3-turbo (multilingual).
  static const ModelSpec whisperTurbo = ModelSpec(
    id: 'whisper-turbo',
    displayNameAr: 'Whisper Turbo (الأعلى دقة)',
    descriptionAr:
        'نموذج Whisper large-v3-turbo متعدد اللغات. أعلى دقة في التفريغ، '
        'ويُنصح به على Windows والهواتف الحديثة.',
    kind: ModelKind.asr,
    url: '$kSherpaReleaseBase/asr-models/sherpa-onnx-whisper-turbo.tar.bz2',
    approxSizeMb: 1000,
    archive: true,
    requiredFiles: _whisperRequired,
    extractFiles: _whisperExtract,
    recommended: true,
  );

  /// Whisper medium (multilingual).
  static const ModelSpec whisperMedium = ModelSpec(
    id: 'whisper-medium',
    displayNameAr: 'Whisper Medium (متوازن)',
    descriptionAr:
        'نموذج Whisper medium متعدد اللغات. دقة جيدة جداً وسرعة متوسطة.',
    kind: ModelKind.asr,
    url: '$kSherpaReleaseBase/asr-models/sherpa-onnx-whisper-medium.tar.bz2',
    approxSizeMb: 1800,
    archive: true,
    requiredFiles: _whisperRequired,
    extractFiles: _whisperExtract,
  );

  /// Whisper small (multilingual).
  static const ModelSpec whisperSmall = ModelSpec(
    id: 'whisper-small',
    displayNameAr: 'Whisper Small (سريع)',
    descriptionAr:
        'نموذج Whisper small متعدد اللغات. أسرع وأخف، مناسب للهواتف الأقدم '
        'مع دقة أقل.',
    kind: ModelKind.asr,
    url: '$kSherpaReleaseBase/asr-models/sherpa-onnx-whisper-small.tar.bz2',
    approxSizeMb: 610,
    archive: true,
    requiredFiles: _whisperRequired,
    extractFiles: _whisperExtract,
  );

  /// WeSpeaker ResNet34-LM speaker embedding model (default).
  static const ModelSpec wespeakerResnet34 = ModelSpec(
    id: 'wespeaker-resnet34',
    displayNameAr: 'بصمة الصوت (WeSpeaker ResNet34)',
    descriptionAr:
        'يستخرج بصمة صوتية لكل متحدث للتعرّف عليه في هذا الاجتماع '
        'والاجتماعات القادمة.',
    kind: ModelKind.speaker,
    // The upstream release tag really is spelled "recongition".
    url: '$kSherpaReleaseBase/speaker-recongition-models/'
        'wespeaker_en_voxceleb_resnet34_LM.onnx',
    approxSizeMb: 27,
    archive: false,
    requiredFiles: ['*.onnx'],
    recommended: true,
  );

  /// 3D-Speaker ERes2Net base speaker embedding model (alternative).
  static const ModelSpec eres2netBase = ModelSpec(
    id: '3dspeaker-eres2net-base',
    displayNameAr: 'بصمة الصوت (3D-Speaker ERes2Net)',
    descriptionAr: 'نموذج بديل لاستخراج البصمة الصوتية.',
    kind: ModelKind.speaker,
    url: '$kSherpaReleaseBase/speaker-recongition-models/'
        '3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx',
    approxSizeMb: 38,
    archive: false,
    requiredFiles: ['*.onnx'],
  );

  /// Every model, in display order.
  static const List<ModelSpec> all = [
    sileroVad,
    whisperTurbo,
    whisperMedium,
    whisperSmall,
    wespeakerResnet34,
    eres2netBase,
  ];

  /// Models of the given [kind].
  static List<ModelSpec> ofKind(ModelKind kind) =>
      all.where((m) => m.kind == kind).toList(growable: false);

  /// The model with [id], or null.
  static ModelSpec? tryById(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The model with [id]; throws [ArgumentError] when unknown.
  static ModelSpec byId(String id) =>
      tryById(id) ?? (throw ArgumentError.value(id, 'id', 'Unknown model'));

  /// The recommended model of [kind].
  static ModelSpec recommendedFor(ModelKind kind) =>
      all.firstWhere((m) => m.kind == kind && m.recommended);
}

// ---------------------------------------------------------------------------
// Resolved file locations.
// ---------------------------------------------------------------------------

/// Absolute file locations of an installed model.
sealed class ResolvedModel {
  const ResolvedModel();
}

/// Files of an installed Whisper model.
final class WhisperModelPaths extends ResolvedModel {
  /// Creates the path bundle.
  const WhisperModelPaths({
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  /// Encoder ONNX file.
  final String encoder;

  /// Decoder ONNX file.
  final String decoder;

  /// Token table.
  final String tokens;

  @override
  String toString() =>
      'WhisperModelPaths(encoder: $encoder, decoder: $decoder, tokens: $tokens)';
}

/// A model consisting of a single ONNX file (VAD, speaker embedding).
final class SingleFileModelPath extends ResolvedModel {
  /// Creates the path holder.
  const SingleFileModelPath(this.path);

  /// Absolute path of the model file.
  final String path;

  @override
  String toString() => 'SingleFileModelPath($path)';
}

// ---------------------------------------------------------------------------
// Glob matching and file resolution (pure).
// ---------------------------------------------------------------------------

final Map<String, RegExp> _globCache = {};

/// Converts a basename glob (`*` = any run of characters, `?` = exactly one
/// character) to a case-insensitive, fully anchored [RegExp].
RegExp globToRegExp(String glob) {
  return _globCache.putIfAbsent(glob, () {
    final b = StringBuffer('^');
    for (final rune in glob.runes) {
      final c = String.fromCharCode(rune);
      switch (c) {
        case '*':
          b.write('.*');
        case '?':
          b.write('.');
        default:
          b.write(RegExp.escape(c));
      }
    }
    b.write(r'$');
    return RegExp(b.toString(), caseSensitive: false);
  });
}

/// True when the basename of [filePath] matches [glob].
bool matchesGlob(String filePath, String glob) =>
    globToRegExp(glob).hasMatch(p.basename(filePath));

/// True when [filePath] looks like an int8-quantised model file.
bool isInt8File(String filePath) =>
    p.basename(filePath).toLowerCase().contains('.int8.');

int _depth(String path) =>
    p.split(path).where((s) => s.isNotEmpty && s != '.').length;

/// Picks the best of [paths] whose basename matches [glob], or null.
///
/// Ranking: int8 files first (when [preferInt8]), then the shallowest path,
/// then the shortest basename, then lexicographic order (deterministic).
String? pickBestMatch(
  Iterable<String> paths,
  String glob, {
  bool preferInt8 = true,
}) {
  final candidates = paths.where((f) => matchesGlob(f, glob)).toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    if (preferInt8) {
      final ia = isInt8File(a) ? 0 : 1;
      final ib = isInt8File(b) ? 0 : 1;
      if (ia != ib) return ia - ib;
    }
    final da = _depth(a);
    final db = _depth(b);
    if (da != db) return da - db;
    final la = p.basename(a).length;
    final lb = p.basename(b).length;
    if (la != lb) return la - lb;
    return a.compareTo(b);
  });
  return candidates.first;
}

/// Glob patterns of [spec.requiredFiles] that no entry of [paths] matches.
List<String> missingRequiredFiles(ModelSpec spec, Iterable<String> paths) {
  final list = paths.toList(growable: false);
  return [
    for (final g in spec.requiredFiles)
      if (!list.any((f) => matchesGlob(f, g))) g,
  ];
}

/// Resolves Whisper encoder / decoder / tokens among [paths] (int8
/// preferred). Returns null when any of the three is missing.
///
/// The decoder pattern never selects an encoder file and vice-versa because
/// the patterns anchor on `-encoder` / `-decoder`.
WhisperModelPaths? resolveWhisperFiles(Iterable<String> paths) {
  final list = paths.toList(growable: false);
  final encoder = pickBestMatch(list, '*-encoder*.onnx');
  final decoder = pickBestMatch(list, '*-decoder*.onnx');
  final tokens = pickBestMatch(list, '*-tokens.txt', preferInt8: false) ??
      pickBestMatch(list, '*tokens*.txt', preferInt8: false);
  if (encoder == null || decoder == null || tokens == null) return null;
  return WhisperModelPaths(encoder: encoder, decoder: decoder, tokens: tokens);
}

/// Resolves the model described by [spec] among [paths] (absolute paths of
/// the installed, non-empty files). Returns null when files are missing.
ResolvedModel? resolveModelFiles(ModelSpec spec, Iterable<String> paths) {
  final list = paths.toList(growable: false);
  if (missingRequiredFiles(spec, list).isNotEmpty) return null;
  switch (spec.kind) {
    case ModelKind.asr:
      return resolveWhisperFiles(list);
    case ModelKind.vad:
    case ModelKind.speaker:
      // Prefer the exact upstream file name, then any matching ONNX file.
      final exact = pickBestMatch(list, spec.fileName, preferInt8: false);
      final any = exact ?? pickBestMatch(list, spec.requiredFiles.first);
      return any == null ? null : SingleFileModelPath(any);
  }
}

/// Lists all non-empty regular files below [dir] (recursively, without
/// following links), as absolute paths. Hidden bookkeeping files (names
/// starting with `.`) are skipped. Returns an empty list when [dir] does not
/// exist.
List<String> listModelFilesSync(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  final out = <String>[];
  for (final e in d.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    if (p.basename(e.path).startsWith('.')) continue;
    try {
      if (e.lengthSync() > 0) out.add(p.absolute(e.path));
    } on FileSystemException {
      // Unreadable entry: treat as missing.
    }
  }
  out.sort();
  return out;
}
