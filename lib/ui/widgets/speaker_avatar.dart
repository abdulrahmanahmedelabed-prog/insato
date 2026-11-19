// Speaker avatar (coloured circle with the speaker's number or initial) and
// speaker chip (avatar + name), coloured from the speaker's palette colour.

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../format.dart';
import '../strings_ar.dart';
import '../theme.dart';

/// Circular avatar of a speaker. A null [speaker] renders the neutral
/// "unknown speaker" avatar.
class SpeakerAvatar extends StatelessWidget {
  /// Creates an avatar.
  const SpeakerAvatar({super.key, required this.speaker, this.radius = 18});

  /// The speaker (null = unknown).
  final Speaker? speaker;

  /// Radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = speaker;
    final bg = s == null ? scheme.surfaceContainerHighest : Color(s.colorValue);
    final fg = s == null ? scheme.onSurfaceVariant : onColor(bg);
    return Semantics(
      label: s?.name ?? S.unknownSpeaker,
      image: true,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: s == null
            ? Icon(Icons.person_outline_rounded, size: radius, color: fg)
            : Text(
                speakerInitials(s.name),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.85,
                  height: 1.1,
                ),
              ),
      ),
    );
  }
}

/// A row of overlapping speaker avatars (meeting list rows).
class SpeakerAvatarStack extends StatelessWidget {
  /// Creates a stack of at most [maxVisible] avatars plus a "+N" bubble.
  const SpeakerAvatarStack({
    super.key,
    required this.speakers,
    this.radius = 13,
    this.maxVisible = 4,
  });

  /// Speakers.
  final List<Speaker> speakers;

  /// Avatar radius.
  final double radius;

  /// Maximum avatars shown.
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (speakers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final visible = speakers.take(maxVisible).toList();
    final extra = speakers.length - visible.length;
    final step = radius * 1.45;
    final count = visible.length + (extra > 0 ? 1 : 0);
    return Semantics(
      label: speakers.map((s) => s.name).join('، '),
      excludeSemantics: true,
      child: SizedBox(
        height: radius * 2 + 4,
        width: step * (count - 1) + radius * 2 + 4,
        child: Stack(
          children: [
            for (var i = 0; i < visible.length; i++)
              PositionedDirectional(
                start: i * step,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: SpeakerAvatar(speaker: visible[i], radius: radius),
                ),
              ),
            if (extra > 0)
              PositionedDirectional(
                start: visible.length * step,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: radius,
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      '+$extra',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: radius * 0.75,
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Avatar plus name in a rounded, speaker-tinted pill. Tappable when
/// [onTap] is set (e.g. to rename the speaker).
class SpeakerChip extends StatelessWidget {
  /// Creates a chip.
  const SpeakerChip({
    super.key,
    required this.speaker,
    this.onTap,
    this.dense = false,
    this.tooltip,
  });

  /// The speaker (null = unknown).
  final Speaker? speaker;

  /// Tap action.
  final VoidCallback? onTap;

  /// Smaller variant.
  final bool dense;

  /// Optional tooltip.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = speaker;
    final tint = s == null ? scheme.outline : Color(s.colorValue);
    final name = s?.name ?? S.unknownSpeaker;
    final chip = Material(
      color: Color.alphaBlend(tint.withValues(alpha: 0.14), scheme.surface),
      shape: StadiumBorder(
        side: BorderSide(color: tint.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: dense ? 32 : 40),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(4, 4, dense ? 10 : 14, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpeakerAvatar(speaker: s, radius: dense ? 12 : 15),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    autoIsolate(name),
                    overflow: TextOverflow.ellipsis,
                    style:
                        (dense
                                ? theme.textTheme.labelLarge
                                : theme.textTheme.titleSmall)
                            ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: dense ? 14 : 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: tooltip == null ? chip : Tooltip(message: tooltip, child: chip),
    );
  }
}
