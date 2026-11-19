// Small shared widgets: LTR text for numbers, status chip, empty state,
// error / warning banner, section header and snack-bar helper.

import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../format.dart';
import '../strings_ar.dart';
import '../theme.dart';

/// Text laid out left-to-right regardless of the ambient direction — for
/// clock values (`00:12:34`), API keys, model ids and other Latin tokens.
class LtrText extends StatelessWidget {
  /// Creates LTR text.
  const LtrText(
    this.text, {
    super.key,
    this.style,
    this.tabular = true,
    this.semanticsLabel,
    this.textAlign,
  });

  /// The text.
  final String text;

  /// Style.
  final TextStyle? style;

  /// Use tabular figures (fixed-width digits).
  final bool tabular;

  /// Optional semantics label.
  final String? semanticsLabel;

  /// Alignment.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      text,
      textDirection: TextDirection.ltr,
      style: tabular ? tabularFigures(base) : base,
      semanticsLabel: semanticsLabel,
      textAlign: textAlign,
    );
  }
}

/// Coloured chip showing a meeting status.
class StatusChip extends StatelessWidget {
  /// Creates a chip for [status].
  const StatusChip({super.key, required this.status, this.dense = false});

  /// The status.
  final MeetingStatus status;

  /// Smaller variant for list rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (status) {
      MeetingStatus.recording => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.fiber_manual_record,
      ),
      MeetingStatus.processing => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.hourglass_top_rounded,
      ),
      MeetingStatus.ready => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_rounded,
      ),
      MeetingStatus.failed => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_rounded,
      ),
    };
    final label = meetingStatusLabel(status);
    final textStyle = (dense
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: fg, fontWeight: FontWeight.w600);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

/// Centered illustration (layered icons), title, explanation and an
/// optional action, for empty lists and placeholder panes.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  /// Main illustration icon.
  final IconData icon;

  /// Title.
  final String title;

  /// Explanation.
  final String? body;

  /// Optional call to action.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              scheme.primaryContainer,
                              scheme.primaryContainer.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                      Icon(icon, size: 60, color: scheme.primary),
                      PositionedDirectional(
                        top: 14,
                        end: 10,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 26,
                          color: scheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) const SizedBox(height: 20),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// Severity of an [ErrorBanner].
enum BannerSeverity {
  /// Blocking error.
  error,

  /// Non-fatal warning.
  warning,

  /// Information.
  info,
}

/// Inline banner for errors, warnings and notices, with optional actions.
class ErrorBanner extends StatelessWidget {
  /// Creates a banner.
  const ErrorBanner({
    super.key,
    required this.message,
    this.title,
    this.severity = BannerSeverity.error,
    this.onRetry,
    this.retryLabel,
    this.onDismiss,
    this.extraAction,
  });

  /// Message (Arabic).
  final String message;

  /// Optional bold title.
  final String? title;

  /// Severity (colour and icon).
  final BannerSeverity severity;

  /// Retry / primary action.
  final VoidCallback? onRetry;

  /// Label of [onRetry] (default «إعادة المحاولة»).
  final String? retryLabel;

  /// Dismiss action.
  final VoidCallback? onDismiss;

  /// Additional action widget.
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (severity) {
      BannerSeverity.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      BannerSeverity.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.warning_amber_rounded,
      ),
      BannerSeverity.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline_rounded,
      ),
    };
    final hasActions =
        onRetry != null || onDismiss != null || extraAction != null;
    return Semantics(
      container: true,
      liveRegion: severity == BannerSeverity.error,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, color: fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasActions)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    if (extraAction != null) extraAction!,
                    if (onDismiss != null)
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(foregroundColor: fg),
                        child: const Text(S.dismiss),
                      ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(foregroundColor: fg),
                        child: Text(retryLabel ?? S.retry),
                      ),
                  ],
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section title used in long scrolling pages.
class SectionHeader extends StatelessWidget {
  /// Creates a header.
  const SectionHeader(this.title, {super.key, this.icon, this.trailing});

  /// Title.
  final String title;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Constrains [child] to a comfortable reading width and centers it.
class ReadableWidth extends StatelessWidget {
  /// Creates the constraint.
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = KatibTheme.maxContentWidth,
  });

  /// Content.
  final Widget child;

  /// Maximum width.
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Shows a floating snack bar with [message]; red-tinted when [error].
void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: error ? TextStyle(color: scheme.onErrorContainer) : null,
        ),
        backgroundColor: error ? scheme.errorContainer : null,
        duration: Duration(seconds: error ? 6 : 3),
      ),
    );
}

/// The global rectangle of [context]'s render box (iPad share popover
/// anchor), or null.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
