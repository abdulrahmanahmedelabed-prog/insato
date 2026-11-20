// Pre-call check: both levels (microphone and the remote side) must be seen
// moving before the recording starts.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import 'phone_call_models.dart';
import 'phone_call_providers.dart';
import 'strings.dart';

/// Pure bookkeeping of the check: a side counts as working once its level
/// reached [threshold] in [requiredHits] readings.
class PhoneCallCheckTracker {
  /// Creates a tracker for [mode].
  PhoneCallCheckTracker(
    this.mode, {
    this.threshold = 0.12,
    this.requiredHits = 3,
  });

  /// The mode checked (speakerphone has one shared level).
  final PhoneCallMode mode;

  /// Level (0..1) that counts as sound.
  final double threshold;

  /// Readings at or above [threshold] needed per side.
  final int requiredHits;

  int _localHits = 0;
  int _remoteHits = 0;

  /// Latest microphone level.
  double local = 0;

  /// Latest remote level.
  double remote = 0;

  /// Feeds a microphone reading.
  void addLocal(double v) {
    local = v;
    if (v >= threshold) _localHits++;
  }

  /// Feeds a remote reading.
  void addRemote(double v) {
    remote = v;
    if (v >= threshold) _remoteHits++;
  }

  /// The microphone was heard.
  bool get localOk => _localHits >= requiredHits;

  /// The remote side was heard (always true for speakerphone, where both
  /// sides share the microphone).
  bool get remoteOk =>
      mode == PhoneCallMode.speakerphone || _remoteHits >= requiredHits;

  /// Both sides work.
  bool get ready => localOk && remoteOk;

  /// Forgets everything.
  void reset() {
    _localHits = 0;
    _remoteHits = 0;
    local = 0;
    remote = 0;
  }
}

/// Runs a [PhoneCallLevelProbe] for the check panel.
class PhoneCallCheckController extends ChangeNotifier {
  /// Creates the controller; [probeFor] makes the probe of a mode.
  PhoneCallCheckController(this._probeFor, PhoneCallMode mode)
    : _tracker = PhoneCallCheckTracker(mode);

  final PhoneCallLevelProbe Function(PhoneCallMode) _probeFor;
  PhoneCallCheckTracker _tracker;
  PhoneCallLevelProbe? _probe;
  final List<StreamSubscription<double>> _subs = [];
  bool _starting = false;
  bool _disposed = false;

  /// Arabic error of the last start, if any.
  String? error;

  /// Current results.
  PhoneCallCheckTracker get tracker => _tracker;

  /// True while the probe runs.
  bool get running => _probe != null;

  /// True while the probe is starting.
  bool get starting => _starting;

  /// Switches to [mode] (stops a running check).
  Future<void> setMode(PhoneCallMode mode) async {
    if (mode == _tracker.mode) return;
    await stop();
    _tracker = PhoneCallCheckTracker(mode);
    _notify();
  }

  /// Starts the check.
  Future<void> start() async {
    if (_probe != null || _starting) return;
    _starting = true;
    error = null;
    _tracker.reset();
    _notify();
    final probe = _probeFor(_tracker.mode);
    _subs
      ..add(probe.localLevel.listen((v) => _on(() => _tracker.addLocal(v))))
      ..add(probe.remoteLevel.listen((v) => _on(() => _tracker.addRemote(v))));
    try {
      await probe.start();
      _probe = probe;
    } catch (e) {
      await _cancelSubs();
      try {
        await probe.stop();
      } catch (_) {
        // Best effort.
      }
      error = e is InsatoException ? e.messageAr : '$e';
    } finally {
      _starting = false;
      _notify();
    }
  }

  /// Stops the check (the results stay).
  Future<void> stop() async {
    final probe = _probe;
    _probe = null;
    await _cancelSubs();
    if (probe != null) {
      try {
        await probe.stop();
      } catch (_) {
        // Best effort.
      }
    }
    _notify();
  }

  void _on(void Function() f) {
    f();
    _notify();
  }

  Future<void> _cancelSubs() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}

/// The check panel: start / stop and one level bar per side.
class PhoneCallCheckPanel extends ConsumerWidget {
  /// Creates the panel over [controller].
  const PhoneCallCheckPanel({super.key, required this.controller});

  /// The running check.
  final PhoneCallCheckController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final t = controller.tracker;
      final phoneLink = t.mode == PhoneCallMode.phoneLink;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(PCS.checkTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                phoneLink ? PCS.checkHintPhoneLink : PCS.checkHintSpeaker,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              PhoneCallLevelRow(
                label: phoneLink ? PCS.levelLocal : PCS.levelRoom,
                icon: Icons.mic_rounded,
                level: t.local,
                ok: t.localOk,
              ),
              if (phoneLink)
                PhoneCallLevelRow(
                  label: PCS.levelRemote,
                  icon: Icons.phone_in_talk_rounded,
                  level: t.remote,
                  ok: t.remoteOk,
                ),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    PCS.checkFailed(controller.error!),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (t.ready)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(child: Text(PCS.checkReady)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: controller.running
                    ? OutlinedButton.icon(
                        onPressed: controller.stop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text(PCS.checkStop),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: controller.starting
                            ? null
                            : controller.start,
                        icon: const Icon(Icons.graphic_eq_rounded),
                        label: const Text(PCS.checkStart),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One labelled level bar with its status.
class PhoneCallLevelRow extends StatelessWidget {
  /// Creates the row.
  const PhoneCallLevelRow({
    super.key,
    required this.label,
    required this.icon,
    required this.level,
    this.ok,
  });

  /// Side label.
  final String label;

  /// Side icon.
  final IconData icon;

  /// 0..1 level.
  final double level;

  /// Status (null: no status shown).
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ok;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label)),
              if (status != null)
                Text(
                  status ? PCS.levelOk : PCS.levelWaiting,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Semantics(
            label: label,
            value: '${(level.clamp(0.0, 1.0) * 100).round()}%',
            child: LinearProgressIndicator(
              value: level.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
