// Voice library: every known speaker with voiceprint status and number of
// meetings; rename, merge, forget voice and delete.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../actions.dart';
import '../strings_ar.dart';
import '../ui_providers.dart';
import '../widgets/common.dart';
import '../widgets/speaker_avatar.dart';

/// The voice library screen.
class SpeakersScreen extends ConsumerWidget {
  /// Creates the screen.
  const SpeakersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakers = ref.watch(speakersProvider);
    final counts =
        ref.watch(speakerMeetingCountsProvider).value ?? const <String, int>{};
    return Scaffold(
      appBar: AppBar(title: const Text(S.voiceLibrary)),
      body: speakers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: S.unexpectedError,
            onRetry: () => ref.invalidate(speakersProvider),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.graphic_eq_rounded,
              title: S.noSpeakersTitle,
              body: S.noSpeakersBody,
            );
          }
          // Named people first, then automatic labels; each alphabetically.
          final sorted = [...list]
            ..sort((a, b) {
              if (a.isNamedByUser != b.isNamedByUser) {
                return a.isNamedByUser ? -1 : 1;
              }
              return a.name.compareTo(b.name);
            });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      S.voiceLibraryIntro,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final s in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SpeakerLibraryTile(
                          speaker: s,
                          meetingCount: counts[s.id] ?? 0,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _LibraryAction { rename, merge, forget, delete }

/// One speaker in the voice library.
class SpeakerLibraryTile extends ConsumerWidget {
  /// Creates the tile.
  const SpeakerLibraryTile({
    super.key,
    required this.speaker,
    required this.meetingCount,
  });

  /// The speaker.
  final Speaker speaker;

  /// Meetings the speaker appears in.
  final int meetingCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasVoice = speaker.centroid != null;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 6, 4, 6),
        leading: SpeakerAvatar(speaker: speaker, radius: 22),
        title: Text(speaker.name, style: theme.textTheme.titleMedium),
        subtitle: Wrap(
          spacing: 10,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(S.meetingsCount(meetingCount)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasVoice
                      ? Icons.fingerprint_rounded
                      : Icons.voice_over_off_rounded,
                  size: 16,
                  color: hasVoice ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(hasVoice ? S.hasVoiceprint : S.noVoiceprint),
              ],
            ),
            if (!speaker.isNamedByUser) const Text(S.autoNamed),
          ],
        ),
        onTap: () => renameSpeakerFlow(context, ref, speaker),
        trailing: PopupMenuButton<_LibraryAction>(
          tooltip: S.speakerActions,
          onSelected: (a) {
            switch (a) {
              case _LibraryAction.rename:
                renameSpeakerFlow(context, ref, speaker);
              case _LibraryAction.merge:
                mergeSpeakerFlow(context, ref, speaker);
              case _LibraryAction.forget:
                forgetVoiceFlow(context, ref, speaker);
              case _LibraryAction.delete:
                deleteSpeakerFlow(context, ref, speaker);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _LibraryAction.rename,
              child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text(S.rename),
              ),
            ),
            const PopupMenuItem(
              value: _LibraryAction.merge,
              child: ListTile(
                leading: Icon(Icons.merge_rounded),
                title: Text(S.merge),
              ),
            ),
            PopupMenuItem(
              value: _LibraryAction.forget,
              enabled: hasVoice,
              child: const ListTile(
                leading: Icon(Icons.voice_over_off_rounded),
                title: Text(S.forgetVoice),
              ),
            ),
            PopupMenuItem(
              value: _LibraryAction.delete,
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text(S.delete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
