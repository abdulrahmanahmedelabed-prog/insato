// Arabic (MSA) UI strings of the evidence feature (F5): ▶ chips on minutes
// items, the clip player bar and the transcript highlight. Shared words
// (close, …) come from `S` in lib/ui/strings_ar.dart.

import '../../core/time_format.dart';

/// Arabic strings of the evidence feature.
abstract final class ES {
  /// Heading-free label read by screen readers before a row of chips.
  static const String evidenceGroupLabel = 'الأدلة من التسجيل';

  /// Tooltip of a chip when the meeting audio is available.
  static String playFrom(int startMs) =>
      'تشغيل التسجيل من ${formatTimestamp(startMs)}';

  /// Tooltip of a chip when only the transcript line can be shown.
  static String showLineAt(int startMs) =>
      'عرض السطر ${formatTimestamp(startMs)} في النص الكامل';

  /// Semantics label of one chip.
  static String chipSemantics(int segmentIndex, int startMs, String? speaker) =>
      [
        'دليل: المقطع $segmentIndex عند ${formatTimestamp(startMs)}',
        if (speaker != null && speaker.trim().isNotEmpty) 'المتحدث $speaker',
      ].join('، ');

  /// "+N" chip that expands a long list of evidence chips.
  static String moreEvidence(int n) => '+$n';

  /// Tooltip of the "+N" chip.
  static const String showAllEvidence = 'عرض كل الأدلة';

  /// Player bar: play.
  static const String play = 'تشغيل';

  /// Player bar: pause.
  static const String pause = 'إيقاف مؤقت';

  /// Player bar: replay the evidence clip from its pre-roll.
  static const String replayClip = 'إعادة المقطع من بدايته';

  /// Player bar: close the player.
  static const String closePlayer = 'إغلاق المشغّل';

  /// Player bar: scrub slider label.
  static const String seekLabel = 'موضع التشغيل';

  /// Player bar: speed button tooltip.
  static const String speedTooltip = 'سرعة التشغيل';

  /// Speed value label (always LTR digits, e.g. "1.5×").
  static String speedLabel(double rate) {
    final text = rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(1);
    return '$text×';
  }

  /// Semantics of the speed button.
  static String speedSemantics(double rate) =>
      'سرعة التشغيل ${speedLabel(rate)}، اضغط للتبديل';

  /// Player bar: jump to the line in the full transcript.
  static const String showInTranscript = 'عرض في النص الكامل';

  /// Player bar while the recording is being opened.
  static const String loadingAudio = 'جارٍ فتح التسجيل…';

  /// Player bar title: the evidence segment being played.
  static String clipTitle(int segmentIndex) => 'دليل المقطع #$segmentIndex';

  /// Notice when a chip falls back to the transcript line.
  static const String audioNotKept =
      'لم يُحتفظ بتسجيل هذا الاجتماع، فعُرض السطر المقابل في النص الكامل.';

  /// Notice while the meeting is still being recorded.
  static const String audioStillRecording =
      'التسجيل ما زال جارياً؛ عُرض السطر المقابل في النص الكامل.';

  /// The evidence segment no longer exists (deleted or merged).
  static const String segmentMissing =
      'لم يعد هذا المقطع موجوداً في النص (ربما حُذف أو عُدّل).';

  /// The recording file could not be opened or played.
  static const String playbackFailed =
      'تعذّر تشغيل التسجيل. عُرض السطر المقابل في النص الكامل بدلاً منه.';

  /// Semantics label of the highlighted transcript line.
  static const String highlightedLine = 'السطر المحدد';
}
