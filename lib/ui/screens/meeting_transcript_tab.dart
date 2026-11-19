// "النص الكامل" tab: transcript grouped by speaker turns. Tapping a segment
// opens a sheet to reassign its speaker (from this meeting, any known
// speaker, or a new one) or edit / delete its text; tapping a speaker name
// renames the speaker.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/models.dart';
import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../actions.dart';
import '../format.dart';
import '../strings_ar.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/speaker_avatar.dart';
import '../widgets/transcript_view.dart';

/// The full transcript of [meetingId].
class MeetingTranscriptTab extends ConsumerWidget {
  /// Creates the tab.
  const MeetingTranscriptTab({super.key, required this.meetingId});

  /// Meeting shown.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(segmentsProvider(meetingId));
    final speakers =
        ref.watch(speakersByIdProvider).value ?? const <String, Speaker>{};
    return segments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(
          message: S.unexpectedError,
          onRetry: () => ref.invalidate(segmentsProvider(meetingId)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.notes_rounded,
            title: S.noTranscriptTitle,
            body: S.noTranscriptBody,
          );
        }
        return ReadableWidth(
          child: TranscriptView(
            segments: list,
            speakersById: speakers,
            onSegmentTap: (seg) => showSegmentSheet(context, seg),
            onSpeakerTap: (sp) => renameSpeakerFlow(context, ref, sp),
          ),
        );
      },
    );
  }
}

/// Opens the correction sheet of [segment].
Future<void> showSegmentSheet(BuildContext context, TranscriptSegment segment) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SegmentSheet(segment: segment),
  );
}

/// Bottom sheet correcting one transcript segment.
class SegmentSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const SegmentSheet({super.key, required this.segment});

  /// The segment.
  final TranscriptSegment segment;

  @override
  ConsumerState<SegmentSheet> createState() => _SegmentSheetState();
}

class _SegmentSheetState extends ConsumerState<SegmentSheet> {
  bool _busy = false;

  TranscriptSegment get _seg => widget.segment;

  Future<void> _guard(Future<void> Function() f, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    String message = done;
    var error = false;
    try {
      await f();
    } catch (e) {
      error = true;
      message = e is InsatoException ? e.messageAr : S.unexpectedError;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    nav.maybePop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: error ? 6 : 3),
      ),
    );
  }

  Future<void> _assign(String? speakerId) => _guard(
    () => ref.read(postProcessorProvider).reassignSegment(_seg.id, speakerId),
    S.speakerAssigned,
  );

  Future<void> _assignNew() => _guard(() async {
    final sp = await ref.read(speakerRepositoryProvider).create();
    await ref.read(postProcessorProvider).reassignSegment(_seg.id, sp.id);
  }, S.speakerAssigned);

  Future<void> _assignOther(List<Speaker> exclude) async {
    final all = await ref.read(speakerRepositoryProvider).getAll();
    if (!mounted) return;
    final ids = exclude.map((s) => s.id).toSet();
    final picked = await showSpeakerPicker(
      context,
      title: S.whoSaidThis,
      speakers: all.where((s) => !ids.contains(s.id)).toList(),
    );
    if (picked != null) await _assign(picked.id);
  }

  Future<void> _editText() async {
    final text = await showTextInputDialog(
      context,
      title: S.editText,
      initialValue: _seg.text,
      label: S.segmentText,
      maxLines: 6,
      emptyError: S.textEmpty,
      textDirection: detectTextDirection(_seg.text),
    );
    if (text == null || text == _seg.text) return;
    await _guard(
      () => ref.read(segmentRepositoryProvider).updateText(_seg.id, text),
      S.textSaved,
    );
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: S.deleteSegment,
      body: _seg.text,
      confirmLabel: S.delete,
      destructive: true,
    );
    if (!ok) return;
    await _guard(
      () => ref.read(segmentRepositoryProvider).delete(_seg.id),
      S.segmentDeleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meetingSpeakers =
        ref.watch(meetingSpeakersProvider(_seg.meetingId)).value ??
        const <Speaker>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.segmentSheetTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                LtrText(
                  formatTimestamp(_seg.startMs),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _seg.text,
                textDirection: detectTextDirection(_seg.text),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            const SectionHeader(S.whoSaidThis, icon: Icons.person_search),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in meetingSpeakers)
                  ChoiceChip(
                    selected: s.id == _seg.speakerId,
                    avatar: SpeakerAvatar(speaker: s, radius: 12),
                    label: Text(s.name),
                    onSelected: _busy || s.id == _seg.speakerId
                        ? null
                        : (_) => _assign(s.id),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text(S.newSpeaker),
              onTap: _assignNew,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('${S.navSpeakers}…'),
              onTap: () => _assignOther(meetingSpeakers),
            ),
            if (_seg.speakerId != null)
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.person_off_outlined),
                title: const Text(S.noSpeaker),
                onTap: () => _assign(null),
              ),
            const Divider(),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text(S.editText),
              onTap: _editText,
            ),
            ListTile(
              enabled: !_busy,
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: const Text(S.deleteSegment),
              onTap: _delete,
            ),
          ],
        ),
      ),
    );
  }
}
