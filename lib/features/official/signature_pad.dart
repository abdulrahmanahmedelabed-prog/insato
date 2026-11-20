// On-device signature capture (v1.2): a pad that records finger / pen
// strokes as vectors (normalised points with timestamps), a preview painter
// and the signing page.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'official_logic.dart' show formatHash;
import 'official_models.dart';
import 'official_service.dart';
import 'strings.dart';

/// Width / height of the signature pad.
const double kSignatureAspect = 3;

/// Controller of a [SignaturePad]: the strokes drawn so far.
class SignatureController extends ChangeNotifier {
  final List<List<SignaturePoint>> _strokes = [];
  final Stopwatch _clock = Stopwatch();

  /// Strokes (normalised 0..1 points).
  List<List<SignaturePoint>> get strokes => [
    for (final s in _strokes) List.unmodifiable(s),
  ];

  /// True when nothing was drawn.
  bool get isEmpty => _strokes.every((s) => s.isEmpty);

  /// Starts a stroke at [p].
  void begin(SignaturePoint p) {
    if (!_clock.isRunning) _clock.start();
    _strokes.add([_stamp(p)]);
    notifyListeners();
  }

  /// Extends the current stroke.
  void extend(SignaturePoint p) {
    if (_strokes.isEmpty) return begin(p);
    _strokes.last.add(_stamp(p));
    notifyListeners();
  }

  SignaturePoint _stamp(SignaturePoint p) => SignaturePoint(
    p.x.clamp(0.0, 1.0),
    p.y.clamp(0.0, 1.0),
    t: _clock.elapsedMilliseconds,
  );

  /// Clears the pad.
  void clear() {
    _strokes.clear();
    _clock
      ..stop()
      ..reset();
    notifyListeners();
  }
}

/// Paints normalised strokes into the available size.
class SignaturePainter extends CustomPainter {
  /// Creates a painter.
  SignaturePainter(this.strokes, {required this.color, this.width = 2.6});

  /// Strokes.
  final List<List<SignaturePoint>> strokes;

  /// Ink.
  final Color color;

  /// Stroke width.
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      final path = Path()
        ..moveTo(s.first.x * size.width, s.first.y * size.height);
      if (s.length == 1) {
        canvas.drawCircle(
          Offset(s.first.x * size.width, s.first.y * size.height),
          width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      for (final p in s.skip(1)) {
        path.lineTo(p.x * size.width, p.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) => true;
}

/// A drawing pad for a signature (left-to-right coordinates, whatever the
/// text direction).
class SignaturePad extends StatelessWidget {
  /// Creates the pad.
  const SignaturePad({super.key, required this.controller});

  /// Controller.
  final SignatureController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: OS.signaturePadSemantics,
      child: AspectRatio(
        aspectRatio: kSignatureAspect,
        child: LayoutBuilder(
          builder: (context, c) {
            SignaturePoint norm(Offset o) =>
                SignaturePoint(o.dx / c.maxWidth, o.dy / c.maxHeight);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => controller.begin(norm(d.localPosition)),
                onPanUpdate: (d) => controller.extend(norm(d.localPosition)),
                onTapDown: (d) => controller.begin(norm(d.localPosition)),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: SignaturePainter(
                      controller.strokes,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A read-only signature preview.
class SignaturePreview extends StatelessWidget {
  /// Creates a preview.
  const SignaturePreview({
    super.key,
    required this.signature,
    this.height = 48,
  });

  /// The signature.
  final MinutesSignature signature;

  /// Height.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: height * signature.aspectRatio,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: CustomPaint(
        painter: SignaturePainter(
          signature.strokes,
          color: Theme.of(context).colorScheme.onSurface,
          width: 1.6,
        ),
      ),
    ),
  );
}

/// Opens the signing page for [meetingId]. Returns true when saved.
Future<bool> showSignatureCapture(
  BuildContext context, {
  required String meetingId,
  required String contentHash,
  String signerName = '',
  String signerRole = '',
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => SignatureCaptureScreen(
          meetingId: meetingId,
          contentHash: contentHash,
          signerName: signerName,
          signerRole: signerRole,
        ),
      ),
    ) ??
    false;

/// The signing page.
class SignatureCaptureScreen extends ConsumerStatefulWidget {
  /// Creates the page.
  const SignatureCaptureScreen({
    super.key,
    required this.meetingId,
    required this.contentHash,
    this.signerName = '',
    this.signerRole = '',
  });

  /// Meeting signed.
  final String meetingId;

  /// Hash of the approved content shown to the signer.
  final String contentHash;

  /// Pre-filled name.
  final String signerName;

  /// Pre-filled role.
  final String signerRole;

  @override
  ConsumerState<SignatureCaptureScreen> createState() =>
      _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState
    extends ConsumerState<SignatureCaptureScreen> {
  final _pad = SignatureController();
  late final _name = TextEditingController(text: widget.signerName);
  late final _role = TextEditingController(text: widget.signerRole);
  bool _saving = false;

  @override
  void dispose() {
    _pad.dispose();
    _name.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pad.isEmpty) {
      showSnack(context, OS.emptySignature, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(officialMinutesServiceProvider)
          .sign(
            meetingId: widget.meetingId,
            signerName: _name.text,
            signerRole: _role.text,
            strokes: _pad.strokes,
            aspectRatio: kSignatureAspect,
          );
      if (!mounted) return;
      showSnack(context, OS.signatureSaved);
      Navigator.of(context).pop(true);
    } on OfficialActionException catch (e) {
      if (mounted) showSnack(context, e.messageAr, error: true);
    } catch (_) {
      if (mounted) showSnack(context, S.unexpectedError, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(OS.signatureTitle),
        leading: IconButton(
          tooltip: S.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  OS.signerStatement(formatHash(widget.contentHash)),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: OS.signerName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _role,
                  decoration: const InputDecoration(labelText: OS.signerRole),
                ),
                const SizedBox(height: 16),
                Text(OS.signatureHint, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SignaturePad(controller: _pad),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: _saving ? null : _pad.clear,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text(OS.clear),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.draw_rounded),
                      label: const Text(OS.saveSignature),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
