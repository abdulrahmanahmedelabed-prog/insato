// The minutes engine: builds the prompt (minutes_prompt.dart), calls the
// selected [MinutesBackend] (Gemini by default, Groq, or a local engine),
// parses the structured answer tolerantly and validates it
// (minutes_validation.dart) before it is stored.

import 'dart:math' as math;

import '../core/errors.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import 'json_repair.dart';
import 'minutes_backend.dart';
import 'minutes_prompt.dart';
import 'minutes_validation.dart';

/// Generates Arabic minutes with any [MinutesBackend] (one structured
/// request per meeting).
class StructuredMinutesEngine implements MinutesEngine {
  /// Creates an engine over [backend].
  ///
  /// * [detailLevel] — detailed (default) or concise minutes.
  /// * [clock] — source of `generatedAt` (tests).
  StructuredMinutesEngine({
    required this.backend,
    this.detailLevel = MinutesDetailLevel.detailed,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The backend that writes the minutes.
  final MinutesBackend backend;
  final DateTime Function() _clock;

  /// Requested level of detail.
  final MinutesDetailLevel detailLevel;

  @override
  Future<Minutes> generate({
    required Meeting meeting,
    required List<TranscriptSegment> segments,
    required Map<String, Speaker> speakersById,
    void Function(double progress, String status)? onProgress,
    MinutesInputs inputs = MinutesInputs.none,
  }) async {
    void report(double p, String s) => onProgress?.call(p.clamp(0.0, 1.0), s);
    final name = backend.displayName;

    report(0.02, 'جارٍ تجهيز نص الاجتماع…');
    final spoken = segments.where((s) => s.hasContent).toList()
      ..sort((a, b) {
        final c = a.startMs.compareTo(b.startMs);
        return c != 0 ? c : a.index.compareTo(b.index);
      });
    if (spoken.isEmpty) {
      throw const InsatoException(
        'لا يوجد كلام مسجّل في هذا الاجتماع يمكن إعداد محضر منه.',
      );
    }

    final user = buildMinutesUserMessage(
      meeting: meeting,
      segments: spoken,
      speakersById: speakersById,
      detailLevel: detailLevel,
      inputs: inputs,
    );
    final transcriptChars = spoken.fold<int>(0, (n, s) => n + s.text.length);
    // Rough expected size of the JSON answer, used only for the progress bar.
    final expectedChars = detailLevel == MinutesDetailLevel.concise
        ? (transcriptChars * 0.3).clamp(2000, 18000).toDouble()
        : (transcriptChars * 0.6).clamp(4000, 48000).toDouble();

    report(0.05, 'جارٍ إرسال النص إلى $name…');
    final result = await backend.generateStructured(
      MinutesBackendRequest(
        system: kMinutesSystemPrompt,
        user: user,
        schema: minutesJsonSchema(),
        expectedChars: expectedChars.round(),
        context: MinutesPromptContext(
          meeting: meeting,
          segments: spoken,
          speakersById: speakersById,
          inputs: inputs,
          detailLevel: detailLevel,
        ),
      ),
      onProgress: (p) {
        switch (p.phase) {
          case MinutesBackendPhase.loadingModel:
            report(0.06, 'جارٍ تحميل النموذج المحلي…');
          case MinutesBackendPhase.connecting:
            report(
              0.08,
              p.attempt == 1
                  ? 'جارٍ الاتصال بخدمة $name…'
                  : 'جارٍ إعادة المحاولة (${p.attempt})…',
            );
          case MinutesBackendPhase.thinking:
            report(0.15, 'يحلّل $name مجريات الاجتماع…');
          case MinutesBackendPhase.writing:
            final chars = p.receivedChars;
            if (chars <= 0) {
              report(0.2, 'يكتب $name المحضر…');
            } else {
              final fraction = 1 - math.exp(-chars / expectedChars);
              report(
                0.2 + 0.75 * fraction,
                'يكتب $name المحضر… ($chars حرفاً)',
              );
            }
          case MinutesBackendPhase.retrying:
            report(0.05, 'الخدمة مشغولة، ستُعاد المحاولة بعد لحظات…');
          case MinutesBackendPhase.waitingForQuota:
            final s = p.wait == null
                ? null
                : math.max(1, (p.wait!.inMilliseconds / 1000).ceil());
            report(
              0.05,
              s == null
                  ? 'بلغت حدّ الطلبات المجاني، في انتظار السماح بطلب جديد…'
                  : 'بلغت حدّ الطلبات المجاني، ستُعاد المحاولة بعد $s ثانية…',
            );
          case MinutesBackendPhase.processingChunk:
            final f = (p.fraction ?? 0).clamp(0.0, 1.0);
            report(0.1 + 0.85 * f, 'يعالج النموذج أجزاء الاجتماع…');
        }
      },
    );

    report(0.97, 'جارٍ معالجة المحضر…');
    final json = parseMinutesJson(result.text);
    final raw = Minutes.fromJson(
      json,
      generatedAt: _clock(),
      model: result.model,
    );
    final minutes = sanitizeMinutes(
      raw,
      MinutesConstraints(
        segmentIds: {for (final s in spoken) s.index},
        agenda: meeting.context.agenda,
        openTaskIds: {
          for (final t in inputs.openTasks)
            if (t.status == TaskStatus.open) t.id,
        },
        optedInSpeakers: optedInSpeakerNames(spoken, speakersById).toSet(),
        fallbackTitle: meeting.title,
        speakerNames: {
          for (final s in speakerStats(spoken, speakersById))
            if (s.name != kUnknownSpeakerName) s.name,
        },
      ),
    );
    report(1.0, 'اكتمل المحضر');
    return minutes;
  }
}

/// Parses a model's answer text into a JSON object.
///
/// Structured outputs normally guarantee valid JSON, but this is defensive:
/// it tolerates surrounding whitespace or prose, a Markdown code fence,
/// trailing commas, comments and a truncated end (see json_repair.dart).
/// Throws [MinutesGenerationException] if no JSON object can be recovered.
Map<String, dynamic> parseMinutesJson(String text) {
  final decoded = decodeJsonObjectTolerant(text);
  if (decoded != null) return decoded;
  throw MinutesGenerationException(
    'تعذّرت قراءة المحضر الذي أعاده النموذج. حاول إعادة الإنشاء.',
    debugDetails:
        'unparseable model output (${text.length} chars): '
        '${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
  );
}
