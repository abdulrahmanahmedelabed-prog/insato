// Opt-in switch of a speaker profile (F16): off by default, shows that the
// person should be informed and that the profile stays on the device; the
// first time, the one-time notice dialog (`profilesFeatureAcknowledged`)
// must be accepted. Turning it off offers to delete the profile and notes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'profile_service.dart';
import 'strings.dart';

/// What to do when turning a profile off.
enum ProfileDisableChoice {
  /// Stop collecting, keep the stored profile and notes.
  keep,

  /// Stop collecting and delete the profile and notes.
  delete,
}

/// Shows the one-time speaker-profiles notice. True when accepted.
Future<bool> showProfilesNoticeDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: const Text(PS.noticeTitle),
      content: const SingleChildScrollView(child: Text(PS.noticeBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(PS.noticeAccept),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks how to turn a profile off; null when cancelled.
Future<ProfileDisableChoice?> showDisableProfileDialog(BuildContext context) =>
    showDialog<ProfileDisableChoice>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text(PS.disableTitle),
          content: const SingleChildScrollView(child: Text(PS.disableBody)),
          actionsOverflowDirection: VerticalDirection.up,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(S.cancel),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(ProfileDisableChoice.keep),
              child: const Text(PS.disableKeep),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () =>
                  Navigator.of(context).pop(ProfileDisableChoice.delete),
              child: const Text(PS.disableDelete),
            ),
          ],
        );
      },
    );

/// The opt-in switch of [speakerId]'s profile (for the speaker's detail
/// page / sheet and the profile screen).
class ProfileOptInTile extends ConsumerStatefulWidget {
  /// Creates the tile.
  const ProfileOptInTile({super.key, required this.speakerId});

  /// Speaker id.
  final String speakerId;

  @override
  ConsumerState<ProfileOptInTile> createState() => _ProfileOptInTileState();
}

class _ProfileOptInTileState extends ConsumerState<ProfileOptInTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final Speaker? speaker = ref
        .watch(speakersByIdProvider)
        .value?[widget.speakerId];
    if (speaker == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final enabled = speaker.profileEnabled;
    return MergeSemantics(
      child: SwitchListTile(
        secondary: _busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(
                enabled ? Icons.badge_rounded : Icons.badge_outlined,
                color: theme.colorScheme.primary,
              ),
        title: const Text(PS.optInTitle),
        subtitle: Text(
          '${enabled ? PS.optInOnSubtitle : PS.optInOffSubtitle}\n'
          '${PS.optInNotice}',
        ),
        isThreeLine: true,
        value: enabled,
        onChanged: _busy ? null : (v) => _toggle(v),
      ),
    );
  }

  Future<void> _toggle(bool enable) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final service = ref.read(speakerProfileServiceProvider);
    ProfileDisableChoice? choice;
    if (enable) {
      final settings = await ref.read(appSettingsProvider).load();
      if (!mounted) return;
      if (!settings.profilesFeatureAcknowledged &&
          !await showProfilesNoticeDialog(context)) {
        return;
      }
    } else {
      choice = await showDisableProfileDialog(context);
      if (choice == null) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await service.setEnabled(
        widget.speakerId,
        enable,
        deleteData: choice == ProfileDisableChoice.delete,
      );
      if (messenger != null) {
        showSnackOn(
          messenger,
          scheme,
          enable
              ? PS.enabledSnack
              : choice == ProfileDisableChoice.delete
              ? PS.deletedSnack
              : PS.disabledSnack,
        );
      }
    } catch (_) {
      if (messenger != null) {
        showSnackOn(messenger, scheme, PS.actionFailed, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
