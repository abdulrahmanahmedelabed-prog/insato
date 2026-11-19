// MinutesEngine implementation backed by the Claude Messages API.

import 'dart:convert';
import 'dart:math' as math;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'claude_client.dart';
import 'minutes_prompt.dart';

/// Generates Arabic minutes with Claude (structured JSON output, adaptive
/// thinking, streaming).
class ClaudeMinutesEngine implements MinutesEngine {
  /// Creates an engine using [client].
  ///
  /// * [detailLevel] — detailed (default) or concise minutes.
  /// * [effort] — `output_config.effort` (default `high`).
  /// * [maxTokens] — output cap (default 64000).
  /// * [clock] — source of `generatedAt` (tests).
  ClaudeMinutesEngine({
    required this._client,
    this.detailLevel = MinutesDetailLevel.detailed,
    this.effort = 'high',
    this.maxTokens = 64000,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Convenience constructor creating its own [ClaudeClient].
  factory ClaudeMinutesEngine.withApiKey(
    String apiKey, {
    String model = kDefaultClaudeModel,
    MinutesDetailLevel detailLevel = MinutesDetailLevel.detailed,
  }) => ClaudeMinutesEngine(
    client: ClaudeClient(apiKey: apiKey, model: model),
    detailLevel: detailLevel,
  );

  final ClaudeClient _client;
  final DateTime Function() _clock;

  /// Requested level of detail.
  final MinutesDetailLevel detailLevel;

  /// Effort level sent to the API.
  final String effort;

  /// Maximum output tokens.
  final int maxTokens;

  @override
  Future<Minutes> generate({
    required Meeting meeting,
    required List<TranscriptSegment> segments,
    required Map<String, Speaker> speakersById,
    void Function(double progress, String status)? onProgress,
  }) async {
    void report(double p, String s) => onProgress?.call(p.clamp(0.0, 1.0), s);

    report(0.02, 'جارٍ تجهيز نص الاجتماع…');
    final spoken = segments.where((s) => s.text.trim().isNotEmpty).toList();
    if (spoken.isEmpty) {
      throw const KatibException(
        'لا يوجد كلام مسجّل في هذا الاجتماع يمكن إعداد محضر منه.',
      );
    }

    final user = buildMinutesUserMessage(
      meeting: meeting,
      segments: spoken,
      speakersById: speakersById,
      detailLevel: detailLevel,
    );
    final transcriptChars = spoken.fold<int>(0, (n, s) => n + s.text.length);
    // Rough expected size of the JSON answer, used only for the progress bar.
    final expectedChars = detailLevel == MinutesDetailLevel.concise
        ? (transcriptChars * 0.25).clamp(1500, 15000).toDouble()
        : (transcriptChars * 0.5).clamp(3000, 40000).toDouble();

    report(0.05, 'جارٍ إرسال النص إلى Claude…');
    final result = await _client.createStructured(
      system: kMinutesSystemPrompt,
      user: user,
      schema: minutesJsonSchema(),
      effort: effort,
      maxTokens: maxTokens,
      onPhase: (phase, attempt) {
        switch (phase) {
          case ClaudeStreamPhase.connecting:
            report(
              0.08,
              attempt == 1
                  ? 'جارٍ الاتصال بخدمة Claude…'
                  : 'جارٍ إعادة المحاولة ($attempt)…',
            );
          case ClaudeStreamPhase.thinking:
            report(0.15, 'يحلّل Claude مجريات الاجتماع…');
          case ClaudeStreamPhase.writing:
            report(0.2, 'يكتب Claude المحضر…');
          case ClaudeStreamPhase.retrying:
            report(0.05, 'الخدمة مشغولة، ستُعاد المحاولة بعد لحظات…');
        }
      },
      onDelta: (chars) {
        final fraction = 1 - math.exp(-chars / expectedChars);
        report(0.2 + 0.75 * fraction, 'يكتب Claude المحضر… ($chars حرفاً)');
      },
    );

    report(0.97, 'جارٍ معالجة المحضر…');
    final json = parseMinutesJson(result.text);
    var minutes = Minutes.fromJson(
      json,
      generatedAt: _clock(),
      model: result.model,
    );
    if (minutes.title.trim().isEmpty) {
      minutes = Minutes(
        title: meeting.title,
        summary: minutes.summary,
        attendees: minutes.attendees,
        topics: minutes.topics,
        decisions: minutes.decisions,
        actionItems: minutes.actionItems,
        openQuestions: minutes.openQuestions,
        languagesDetected: minutes.languagesDetected,
        generatedAt: minutes.generatedAt,
        model: minutes.model,
        nextMeeting: minutes.nextMeeting,
        notes: minutes.notes,
      );
    }
    report(1.0, 'اكتمل المحضر');
    return minutes;
  }
}

/// Parses Claude's answer text into a JSON object.
///
/// Structured outputs guarantee valid JSON, but this is defensive: it
/// tolerates surrounding whitespace, a Markdown code fence, or stray text
/// around a single top-level object. Throws [MinutesGenerationException] if
/// no JSON object can be recovered.
Map<String, dynamic> parseMinutesJson(String text) {
  Map<String, dynamic>? tryDecode(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  final trimmed = text.trim();
  final direct = tryDecode(trimmed);
  if (direct != null) return direct;

  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(trimmed);
  if (fence != null) {
    final fenced = tryDecode(fence.group(1)!);
    if (fenced != null) return fenced;
  }

  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start >= 0 && end > start) {
    final sliced = tryDecode(trimmed.substring(start, end + 1));
    if (sliced != null) return sliced;
  }

  throw MinutesGenerationException(
    'تعذّرت قراءة المحضر الذي أعاده النموذج. حاول إعادة الإنشاء.',
    debugDetails:
        'unparseable model output (${text.length} chars): '
        '${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
  );
}
