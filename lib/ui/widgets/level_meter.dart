// Animated microphone level meter: a mirrored, rolling bar waveform of the
// recent levels, smoothed so it moves fluidly at the ~20 Hz level rate.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../strings_ar.dart';

/// Rolling waveform of the microphone [level] (0..1).
///
/// Each new value enters at the reading-start edge and scrolls towards the
/// end; when [active] is false the bars settle to a flat line.
class LevelMeter extends StatefulWidget {
  /// Creates a meter.
  const LevelMeter({
    super.key,
    required this.level,
    this.active = true,
    this.bars = 36,
    this.height = 72,
    this.color,
  });

  /// Current level 0..1.
  final double level;

  /// Whether capture is running (paused / stopped meters go flat).
  final bool active;

  /// Number of bars.
  final int bars;

  /// Height.
  final double height;

  /// Bar colour (default: primary).
  final Color? color;

  @override
  State<LevelMeter> createState() => _LevelMeterState();
}

class _LevelMeterState extends State<LevelMeter>
    with SingleTickerProviderStateMixin {
  late List<double> _history;
  late final AnimationController _anim;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _history = List<double>.filled(widget.bars, 0);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _push(widget.active ? widget.level : 0);
  }

  @override
  void didUpdateWidget(LevelMeter old) {
    super.didUpdateWidget(old);
    if (old.bars != widget.bars) {
      _history = List<double>.filled(widget.bars, 0);
    }
    final v = widget.active ? widget.level : 0.0;
    if (v != old.level || widget.active != old.active) _push(v);
  }

  void _push(double raw) {
    final v = raw.isFinite ? raw.clamp(0.0, 1.0) : 0.0;
    _history = [v, ..._history.take(widget.bars - 1)];
    // Continue from the currently displayed value (no jump mid-animation).
    _from = _from + (_to - _from) * Curves.easeOut.transform(_anim.value);
    _to = v;
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? scheme.primary;
    final percent = (widget.active ? widget.level : 0).clamp(0.0, 1.0) * 100;
    return Semantics(
      label: S.micLevel,
      value: '${percent.round()}٪',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final head =
                _from + (_to - _from) * Curves.easeOut.transform(_anim.value);
            return CustomPaint(
              painter: _MeterPainter(
                levels: [head, ..._history.skip(1)],
                color: color,
                idleColor: scheme.outlineVariant,
                direction: Directionality.of(context),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.levels,
    required this.color,
    required this.idleColor,
    required this.direction,
  });

  final List<double> levels;
  final Color color;
  final Color idleColor;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final n = levels.length;
    if (n == 0 || size.width <= 0) return;
    final slot = size.width / n;
    final barWidth = math.max(2.0, slot * 0.55);
    final mid = size.height / 2;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      // Perceptual shaping: quiet speech still shows clearly.
      final v = math.sqrt(levels[i].clamp(0.0, 1.0));
      final h = math.max(barWidth, v * size.height * 0.95);
      final fade = 1 - (i / n) * 0.65;
      paint
        ..color = (v < 0.02 ? idleColor : color).withValues(alpha: fade)
        ..strokeWidth = barWidth;
      // Newest bar at the reading-start edge.
      final xFromStart = slot * i + slot / 2;
      final x = direction == TextDirection.rtl
          ? size.width - xFromStart
          : xFromStart;
      final half = (h - barWidth) / 2;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.levels != levels ||
      old.color != color ||
      old.idleColor != idleColor ||
      old.direction != direction;
}
