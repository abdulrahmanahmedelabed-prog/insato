// Shared domain fixtures for minutes tests.

import 'package:insato/core/models.dart';

final DateTime kCreated = DateTime(2026, 11, 19, 10, 30);

Speaker speaker(String id, String name, {bool named = false}) => Speaker(
  id: id,
  name: name,
  colorValue: 0xFF336699,
  isNamedByUser: named,
  createdAt: kCreated,
);

TranscriptSegment seg(
  int index,
  int startMs,
  int endMs,
  String text, {
  String? speakerId,
  String? language = 'ar',
}) => TranscriptSegment(
  id: 's$index',
  meetingId: 'm1',
  index: index,
  startMs: startMs,
  endMs: endMs,
  text: text,
  speakerId: speakerId,
  language: language,
);

Meeting meeting({
  int durationMs = 3723000,
  String title = 'اجتماع الميزانية',
}) => Meeting(
  id: 'm1',
  title: title,
  createdAt: kCreated,
  status: MeetingStatus.ready,
  durationMs: durationMs,
);

Minutes sampleMinutes() => Minutes(
  title: 'مراجعة ميزانية الربع الرابع',
  summary: 'ناقش الحضور الميزانية.\n\nواتُّفق على خفض النفقات بنسبة 10%.',
  attendees: const ['سارة', 'متحدث 2'],
  topics: const [
    MinutesTopic(
      title: 'النفقات التشغيلية',
      discussion: 'أوضحت سارة أن النفقات ارتفعت | بنسبة 12% (OPEX).',
      speakerNames: ['سارة', 'متحدث 2'],
    ),
  ],
  decisions: const [
    MinutesDecision(text: 'خفض النفقات بنسبة 10%', proposedBy: 'سارة'),
    MinutesDecision(text: 'تأجيل التوظيف'),
  ],
  actionItems: const [
    ActionItem(
      task: 'إعداد تقرير | النفقات',
      owner: 'متحدث 2',
      dueDate: 'الخميس القادم',
    ),
    ActionItem(task: 'مراجعة العقود'),
  ],
  openQuestions: const ['هل تشمل الخطة فرع جدة؟'],
  languagesDetected: const ['العربية', 'الإنجليزية'],
  nextMeeting: 'الأحد 2026-11-29',
  notes: 'بعض المقاطع غير واضحة.',
  generatedAt: DateTime(2026, 11, 19, 12),
  model: 'claude-opus-5-5',
);
