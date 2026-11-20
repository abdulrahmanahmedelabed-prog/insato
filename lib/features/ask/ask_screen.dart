// "Ask your meetings" chat screen (F8): question composer, in-memory
// conversation, answers with numbered inline citations and a list of
// sources that open the meeting at the cited moment, progress, stop, retry
// and an honest note of where the question is sent.

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/secure_settings.dart';
import '../../session/minutes_engines.dart' show minutesEngineDisplayNameAr;
import '../../ui/format.dart' show ltrIsolate;
import '../../ui/navigation.dart' show openMeeting, openSettingsScreen;
import '../../ui/services/share_gateway.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import 'ask_answer.dart';
import 'ask_controller.dart';
import 'ask_prompt.dart' show kAskMaxQuestionChars;
import 'ask_source_sheet.dart';
import 'strings.dart';

/// Opens the meeting of a citation (at its segment when it has one).
typedef AskCitationOpener = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
  AskCitation citation,
);

/// How a citation is opened. The default ([openAskCitation]) shows the cited
/// moment in a sheet (excerpt, playback from that line, open the meeting) and
/// opens a meeting-level citation directly.
final askCitationOpenerProvider = Provider<AskCitationOpener>(
  (ref) => openAskCitation,
);

/// Default [AskCitationOpener]: a citation of a segment shows
/// [showAskSourceSheet] (which may then open the meeting); a citation of a
/// whole meeting opens it.
Future<void> openAskCitation(
  BuildContext context,
  WidgetRef ref,
  AskCitation citation,
) async {
  if (citation.segmentIndex != null) {
    final open = await showAskSourceSheet(context, citation);
    if (!open || !context.mounted) return;
  }
  await openMeeting(context, ref, citation.meetingId);
}

/// Opens the settings page (engine not ready).
final askSettingsOpenerProvider = Provider<Future<void> Function(BuildContext)>(
  (ref) => openSettingsScreen,
);

/// The chat screen.
class AskMeetingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AskMeetingsScreen({super.key, this.embedded = false});

  /// True when shown as a top-level tab / pane (no back button).
  final bool embedded;

  @override
  ConsumerState<AskMeetingsScreen> createState() => _AskMeetingsScreenState();
}

class _AskMeetingsScreenState extends ConsumerState<AskMeetingsScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _field.addListener(_onText);
  }

  @override
  void dispose() {
    _field
      ..removeListener(_onText)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  Future<void> _send() async {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    final controller = ref.read(askControllerProvider.notifier);
    if (ref.read(askControllerProvider).busy) return;
    _field.clear();
    await controller.ask(text);
  }

  Future<void> _clear() async {
    final ok = await showConfirmDialog(
      context,
      title: AS.clearTitle,
      body: AS.clearBody,
      confirmLabel: AS.clear,
      icon: Icons.add_comment_outlined,
    );
    if (ok) ref.read(askControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(askControllerProvider);
    final messages = state.messages;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text(AS.title),
        actions: [
          IconButton(
            tooltip: AS.clear,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: messages.isEmpty && !state.busy ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? _EmptyAsk(
                      onExample: (q) {
                        _field.text = q;
                        _field.selection = TextSelection.collapsed(
                          offset: q.length,
                        );
                        _focus.requestFocus();
                      },
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[messages.length - 1 - i];
                        return ReadableWidth(
                          key: ValueKey(m.id),
                          child: m.role == AskRole.user
                              ? _QuestionBubble(message: m)
                              : _AnswerBubble(message: m),
                        );
                      },
                    ),
            ),
            if (state.progress != null) _ProgressLine(state.progress!),
            _Composer(
              field: _field,
              focus: _focus,
              busy: state.busy,
              onSend: _send,
              onStop: ref.read(askControllerProvider.notifier).cancel,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyAsk extends ConsumerWidget {
  const _EmptyAsk({required this.onExample});

  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsDataProvider).value;
    return EmptyState(
      icon: Icons.question_answer_outlined,
      title: AS.emptyTitle,
      body: AS.emptyBody,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AS.examplesLabel,
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in AS.examples)
                ActionChip(label: Text(q), onPressed: () => onExample(q)),
            ],
          ),
          if (settings != null) ...[
            const SizedBox(height: 20),
            _EngineNotice(settings: settings),
          ],
        ],
      ),
    );
  }
}

class _EngineNotice extends StatelessWidget {
  const _EngineNotice({required this.settings});

  final AppSettingsData settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final engine = minutesEngineDisplayNameAr(settings.minutesEngine);
    final cloud = settings.minutesEngineIsCloud;
    final lines = [
      if (cloud) AS.cloudNotice(engine) else AS.localNotice(engine),
      if (settings.minutesEngine == AppSettingsData.engineGemini)
        AS.geminiFreeTierNotice,
      AS.notStored,
    ];
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                cloud ? Icons.cloud_outlined : Icons.lock_outline_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lines.join('\n'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.message});

  final AskMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 48, bottom: 12),
        child: Semantics(
          label: AS.youAsked,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(16),
                topEnd: Radius.circular(16),
                bottomStart: Radius.circular(16),
                bottomEnd: Radius.circular(4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SelectableText(
                message.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerBubble extends ConsumerWidget {
  const _AnswerBubble({required this.message});

  final AskMessage message;

  Future<void> _open(BuildContext context, WidgetRef ref, AskCitation c) =>
      ref.read(askCitationOpenerProvider)(context, ref, c);

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final answer = message.answer!;
    final b = StringBuffer()..writeln(answer.plainText);
    if (answer.sources.isNotEmpty) {
      b
        ..writeln()
        ..writeln('${AS.sources}:');
      for (final s in answer.sources) {
        b.writeln('${s.number}. ${s.label}');
      }
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    try {
      await ref.read(shareGatewayProvider).copyText(b.toString().trim());
      if (messenger != null) showSnackOn(messenger, scheme, AS.answerCopied);
    } catch (_) {
      if (messenger != null) {
        showSnackOn(messenger, scheme, AS.unexpected, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = message.failure;
    if (failure != null) return _FailureBubble(message: message);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answer = message.answer!;
    final bodyStyle = theme.textTheme.bodyLarge;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 24, bottom: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(16),
              topEnd: Radius.circular(16),
              bottomStart: Radius.circular(4),
              bottomEnd: Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!message.found) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 18,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AS.notFound,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Semantics(
                  label: AS.answerLabel,
                  container: true,
                  child: Text.rich(
                    TextSpan(
                      style: bodyStyle?.copyWith(height: 1.6),
                      children: [
                        for (final part in answer.parts)
                          switch (part) {
                            AskTextPart(:final text) => TextSpan(text: text),
                            AskCitationPart(:final citation) => WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _CitationMarker(
                                citation: citation,
                                onTap: () => _open(context, ref, citation),
                              ),
                            ),
                          },
                      ],
                    ),
                  ),
                ),
                if (answer.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    AS.sources,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final s in answer.sources)
                    _SourceTile(
                      citation: s,
                      onTap: () => _open(context, ref, s),
                    ),
                ],
                Row(
                  children: [
                    if (message.engineName != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              message.sentOffDevice
                                  ? Icons.cloud_outlined
                                  : Icons.lock_outline_rounded,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                AS.answeredBy(message.engineName!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    IconButton(
                      tooltip: AS.copyAnswer,
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => _copy(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CitationMarker extends StatelessWidget {
  const _CitationMarker({required this.citation, required this.onTap});

  final AskCitation citation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: AS.citationSemantics(citation.number, citation.label),
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: citation.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  '${citation.number}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.citation, required this.onTap});

  final AskCitation citation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ts = citation.timestamp;
    return Semantics(
      container: true,
      button: true,
      hint: AS.openSourceHint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: scheme.secondaryContainer,
                  child: Text(
                    '${citation.number}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        citation.meetingTitle,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          AS.sourceDate(citation.meetingDate),
                          ts == null ? AS.wholeMeeting : ltrIsolate(ts),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  ts == null
                      ? Icons.description_outlined
                      : Icons.play_circle_outline_rounded,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureBubble extends ConsumerWidget {
  const _FailureBubble({required this.message});

  final AskMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = message.failure!;
    final controller = ref.read(askControllerProvider.notifier);
    final busy = ref.watch(askControllerProvider.select((s) => s.busy));
    final severity = switch (failure) {
      AskFailure.cancelled || AskFailure.noMeetings => BannerSeverity.info,
      AskFailure.engineNotReady || AskFailure.quota => BannerSeverity.warning,
      AskFailure.error => BannerSeverity.error,
    };
    final canRetry = message.retryable && !busy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ErrorBanner(
        title: failure == AskFailure.error ? AS.errorTitle : null,
        message: message.text,
        severity: severity,
        retryLabel: AS.retry,
        onRetry: canRetry && failure != AskFailure.engineNotReady
            ? () => controller.retry(message.id)
            : null,
        extraAction: failure == AskFailure.engineNotReady
            ? TextButton(
                onPressed: () => ref.read(askSettingsOpenerProvider)(context),
                child: const Text(AS.openSettings),
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress and composer
// ---------------------------------------------------------------------------

class _ProgressLine extends StatelessWidget {
  const _ProgressLine(this.progress);

  final AskProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: progress.labelAr,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress.fraction),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Text(
              progress.labelAr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.field,
    required this.focus,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController field;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final canSend = !busy && field.text.trim().isNotEmpty;
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: ReadableWidth(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    // Enter sends on desktop; Shift+Enter adds a new line.
                    const SingleActivator(LogicalKeyboardKey.enter): () {
                      if (canSend) onSend();
                    },
                  },
                  child: TextField(
                    controller: field,
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: kAskMaxQuestionChars,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => currentLength > (maxLength ?? 0) * 0.9
                        ? Text(ltrIsolate('$currentLength / $maxLength'))
                        : null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: AS.fieldLabel,
                      hintText: AS.fieldHint,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                IconButton.filledTonal(
                  tooltip: AS.stop,
                  iconSize: 24,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.stop_rounded),
                  onPressed: onStop,
                )
              else
                IconButton.filled(
                  tooltip: AS.send,
                  iconSize: 24,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  // Points "forward" in reading direction (left in RTL).
                  icon: const Icon(Icons.send_rounded),
                  onPressed: canSend ? onSend : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
