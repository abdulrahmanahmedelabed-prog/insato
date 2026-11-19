import 'package:insato/core/models.dart';
import 'package:insato/features/ask/ask_corpus.dart';

/// A transcript line: (speaker, text) at 10 s intervals from index [first].
List<AskSegment> lines(List<(String, String)> rows, {int first = 0}) => [
  for (var i = 0; i < rows.length; i++)
    AskSegment(
      index: first + i,
      startMs: (first + i) * 10000,
      endMs: (first + i) * 10000 + 9000,
      speakerName: rows[i].$1,
      text: rows[i].$2,
    ),
];

Minutes minutesOf({
  String summary = 'ملخص',
  List<MinutesTopic> topics = const [],
  List<MinutesDecision> decisions = const [],
  List<ActionItem> actionItems = const [],
}) => Minutes(
  title: 'محضر',
  summary: summary,
  attendees: const ['سارة', 'أحمد'],
  topics: topics,
  decisions: decisions,
  actionItems: actionItems,
  openQuestions: const [],
  languagesDetected: const ['العربية'],
  generatedAt: DateTime(2026, 11, 1),
  model: 'test',
);

AskMeetingSource source(
  String id,
  String title,
  DateTime date,
  List<AskSegment> segments, {
  Minutes? minutes,
  MeetingContext context = MeetingContext.empty,
}) => AskMeetingSource(
  id: id,
  title: title,
  createdAt: date,
  durationMs: segments.isEmpty ? 0 : segments.last.endMs,
  segments: segments,
  minutes: minutes,
  context: context,
);

/// Three meetings, newest first: launch (Nov 10), budget (Nov 5), hiring
/// (Oct 20, minutes only).
List<AskMeetingSource> corpus() => [
  source(
    'm-launch',
    'اجتماع إطلاق التطبيق',
    DateTime(2026, 11, 10, 9),
    lines([
      ('سارة', 'صباح الخير جميعاً'),
      ('أحمد', 'نحتاج إلى تحديد موعد إطلاق التطبيق الجديد'),
      ('سارة', 'أقترح أن يكون الإطلاق في الأول من ديسمبر'),
      ('أحمد', 'موافق، وستتولى ليلى مسؤولية الحملة التسويقية'),
      ('ليلى', 'سأجهز خطة الحملة قبل نهاية الأسبوع'),
      ('سارة', 'شكراً للجميع'),
    ]),
  ),
  source(
    'm-budget',
    'مراجعة الميزانية',
    DateTime(2026, 11, 5, 14),
    lines([
      ('خالد', 'لنبدأ بمراجعة ميزانية الربع الرابع'),
      ('مها', 'تجاوزنا ميزانية التسويق بعشرة بالمئة'),
      ('خالد', 'قررنا تخفيض نفقات السفر'),
      ('مها', 'The cloud hosting costs doubled this quarter'),
      ('خالد', 'سنراجع العقود مع المزودين'),
    ]),
    minutes: minutesOf(
      summary: 'نوقشت ميزانية الربع الرابع وتجاوز نفقات التسويق.',
      decisions: const [
        MinutesDecision(text: 'تخفيض نفقات السفر', evidence: [2]),
      ],
      actionItems: const [
        ActionItem(task: 'مراجعة عقود المزودين', owner: 'خالد', evidence: [4]),
      ],
    ),
  ),
  source(
    'm-hiring',
    'خطة التوظيف',
    DateTime(2026, 10, 20, 11),
    const [],
    minutes: minutesOf(
      summary: 'اتُّفق على توظيف مهندسَين اثنين للواجهة الخلفية.',
      topics: const [
        MinutesTopic(
          title: 'التوظيف',
          discussion: 'نوقشت حاجة الفريق إلى مهندسين في الواجهة الخلفية.',
        ),
      ],
    ),
  ),
];
