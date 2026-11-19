// Catalog of the GGUF language models the on-device minutes engine (F14)
// can download and run through llama.cpp (llamadart).
//
// Sizes are the exact byte sizes of the files on Hugging Face (checked
// 2026-11); RAM figures are the practical minimum for the model weights plus
// the KV cache of [LocalLlmModel.contextTokens] tokens plus the app itself.
//
// The files are downloaded by a dedicated `ModelManager` (see
// local_llm_providers.dart) whose catalog is [LocalLlmCatalog.modelSpecs];
// each entry becomes a single-file model (`*.gguf`).

import '../../speech/model_catalog.dart';

/// Base of Hugging Face file downloads.
const String kHuggingFaceBase = 'https://huggingface.co';

/// Which devices a model is meant for.
enum LocalLlmTarget {
  /// Phones (Android / iOS).
  phone,

  /// Windows PCs.
  desktop,
}

/// One downloadable GGUF model.
class LocalLlmModel {
  /// Creates a catalog entry.
  const LocalLlmModel({
    required this.id,
    required this.displayNameAr,
    required this.descriptionAr,
    required this.repo,
    required this.fileName,
    required this.sizeBytes,
    required this.minRamGb,
    required this.contextTokens,
    required this.target,
    this.recommended = false,
    this.hybridThinking = false,
  });

  /// Stable id (also the directory name and the `localLlmModelId` setting).
  final String id;

  /// Arabic display name.
  final String displayNameAr;

  /// Arabic description (quality, speed, suitable devices).
  final String descriptionAr;

  /// Hugging Face repository (`owner/name`).
  final String repo;

  /// GGUF file name inside [repo].
  final String fileName;

  /// Exact download size in bytes.
  final int sizeBytes;

  /// Minimum device RAM in GB.
  final int minRamGb;

  /// Context window the engine allocates (prompt + answer, in tokens).
  final int contextTokens;

  /// Device class the model is meant for.
  final LocalLlmTarget target;

  /// True for the recommended default of [target].
  final bool recommended;

  /// True for models that "think" before answering unless told not to
  /// (Qwen3 hybrid models); the engine disables thinking.
  final bool hybridThinking;

  /// Direct download URL.
  String get url => '$kHuggingFaceBase/$repo/resolve/main/$fileName';

  /// Download size in MiB (rounded up).
  int get sizeMb => (sizeBytes / (1024 * 1024)).ceil();

  /// Download size in GB with one decimal, e.g. `2.5`.
  String get sizeGbText => (sizeBytes / 1e9).toStringAsFixed(1);

  /// The model name recorded on minutes (`Minutes.model`).
  String get modelLabel => fileName.endsWith('.gguf')
      ? fileName.substring(0, fileName.length - 5)
      : fileName;

  /// The [ModelSpec] used to download / resolve it with `ModelManager`.
  ///
  /// `ModelKind` has no "language model" kind (it is a shared enum); a
  /// single-file kind is used, which makes `ModelManager.filePath` resolve
  /// the `.gguf` file.
  ModelSpec toModelSpec() => ModelSpec(
    id: id,
    displayNameAr: displayNameAr,
    descriptionAr: descriptionAr,
    kind: ModelKind.speaker,
    url: url,
    approxSizeMb: sizeMb,
    archive: false,
    requiredFiles: const ['*.gguf'],
    recommended: recommended,
  );

  @override
  String toString() => 'LocalLlmModel($id)';
}

/// The GGUF models offered by the on-device engine.
abstract final class LocalLlmCatalog {
  /// Qwen3 4B Instruct 2507, Q4_K_M — recommended for phones.
  static const LocalLlmModel qwen3_4b = LocalLlmModel(
    id: 'qwen3-4b-instruct-2507-q4km',
    displayNameAr: 'Qwen3 4B (موصى به للهواتف)',
    descriptionAr:
        'نموذج متوازن يجيد العربية ويكتب محضراً مقبولاً على الهواتف الحديثة. '
        'أبطأ وأقل دقة من المحركات السحابية.',
    repo: 'unsloth/Qwen3-4B-Instruct-2507-GGUF',
    fileName: 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
    sizeBytes: 2497281120,
    minRamGb: 8,
    contextTokens: 12288,
    target: LocalLlmTarget.phone,
    recommended: true,
  );

  /// Qwen3 1.7B, Q4_K_M — for phones with little memory.
  static const LocalLlmModel qwen3_1_7b = LocalLlmModel(
    id: 'qwen3-1.7b-q4km',
    displayNameAr: 'Qwen3 1.7B (خفيف)',
    descriptionAr:
        'نموذج صغير للهواتف ذات الذاكرة المحدودة. أسرع، لكن جودة المحضر '
        'أقل بوضوح وقد يفوته بعض التفاصيل.',
    repo: 'unsloth/Qwen3-1.7B-GGUF',
    fileName: 'Qwen3-1.7B-Q4_K_M.gguf',
    sizeBytes: 1107409472,
    minRamGb: 6,
    contextTokens: 12288,
    target: LocalLlmTarget.phone,
    hybridThinking: true,
  );

  /// Qwen3 8B, Q4_K_M — recommended for Windows PCs with ≥ 16 GB RAM.
  static const LocalLlmModel qwen3_8b = LocalLlmModel(
    id: 'qwen3-8b-q4km',
    displayNameAr: 'Qwen3 8B (موصى به لأجهزة Windows)',
    descriptionAr:
        'جودة أعلى في العربية وفي استخراج القرارات والمهام. يناسب أجهزة '
        'الحاسوب ذات 16 غ.ب ذاكرة أو أكثر.',
    repo: 'Qwen/Qwen3-8B-GGUF',
    fileName: 'Qwen3-8B-Q4_K_M.gguf',
    sizeBytes: 5027783488,
    minRamGb: 16,
    contextTokens: 16384,
    target: LocalLlmTarget.desktop,
    recommended: true,
    hybridThinking: true,
  );

  /// Qwen3 14B, Q4_K_M — best local quality, powerful PCs only.
  static const LocalLlmModel qwen3_14b = LocalLlmModel(
    id: 'qwen3-14b-q4km',
    displayNameAr: 'Qwen3 14B (أعلى جودة محلية)',
    descriptionAr:
        'أفضل جودة متاحة دون إنترنت، لكنه بطيء ويحتاج إلى حاسوب قوي '
        '(32 غ.ب ذاكرة، ويُفضَّل معالج رسوميات).',
    repo: 'Qwen/Qwen3-14B-GGUF',
    fileName: 'Qwen3-14B-Q4_K_M.gguf',
    sizeBytes: 9001752960,
    minRamGb: 32,
    contextTokens: 16384,
    target: LocalLlmTarget.desktop,
    hybridThinking: true,
  );

  /// Every model.
  static const List<LocalLlmModel> all = [
    qwen3_4b,
    qwen3_1_7b,
    qwen3_8b,
    qwen3_14b,
  ];

  /// The models shown on a device: phones see phone models only (desktop
  /// models need more memory than phones have); PCs see all.
  static List<LocalLlmModel> forDevice({required bool desktop}) => desktop
      ? all
      : all.where((m) => m.target == LocalLlmTarget.phone).toList();

  /// The model by [id], or null.
  static LocalLlmModel? tryById(String? id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The recommended model of the device class.
  static LocalLlmModel recommended({required bool desktop}) => all.firstWhere(
    (m) =>
        m.recommended &&
        m.target == (desktop ? LocalLlmTarget.desktop : LocalLlmTarget.phone),
  );

  /// The model to use for the `localLlmModelId` setting [id] (null or
  /// unknown = the recommended model of the device class).
  static LocalLlmModel resolve(String? id, {required bool desktop}) =>
      tryById(id) ?? recommended(desktop: desktop);

  /// `ModelManager` catalog of every model.
  static List<ModelSpec> get modelSpecs =>
      [for (final m in all) m.toModelSpec()];
}
