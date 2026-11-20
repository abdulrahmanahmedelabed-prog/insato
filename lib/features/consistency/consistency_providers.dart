// Riverpod wiring of the consistency checker (v1.2, D): the service, the
// per-meeting check controller (run after minutes generation and on
// demand from the meeting screen) and the live-mode controller used while
// recording.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../data/consistency_repository.dart';
import '../../data/official_repository.dart';
import '../../data/repositories.dart';
import '../../data/repositories_v11.dart' show taskRepositoryProvider;
import '../../session/providers.dart' show minutesBackendFactoryProvider;
import 'consistency_models.dart';
import 'consistency_service.dart';
import 'strings.dart';

/// The checker service (engine: the one selected in Settings).
final consistencyServiceProvider = Provider<ConsistencyService>(
  (ref) => ConsistencyService(
    repository: ref.watch(consistencyRepositoryProvider),
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
    official: ref.watch(officialMinutesRepositoryProvider),
    officialSettings: ref.watch(officialSettingsStoreProvider),
    tasks: ref.watch(taskRepositoryProvider),
    backendFactory: ref.watch(minutesBackendFactoryProvider),
  ),
);

/// Whether minutes generation triggers a check automatically (a seam for
/// tests; always true in the app).
final consistencyAutoCheckProvider = Provider<bool>((ref) => true);

/// State of the check of one meeting.
class ConsistencyCheckState {
  /// Creates a state.
  const ConsistencyCheckState({
    this.running = false,
    this.statusAr,
    this.noticeAr,
    this.errorAr,
    this.result,
  });

  /// True while checking.
  final bool running;

  /// Progress line while running.
  final String? statusAr;

  /// Notice after a run (e.g. local rules only).
  final String? noticeAr;

  /// Error of the last run.
  final String? errorAr;

  /// Result of the last run in this session.
  final ConsistencyRunResult? result;
}

/// Runs the check of one meeting, one at a time. Errors never escape.
class ConsistencyCheckController extends Notifier<ConsistencyCheckState> {
  /// Creates the controller of [meetingId].
  ConsistencyCheckController(this.meetingId);

  /// The meeting.
  final String meetingId;

  Future<bool>? _running;

  @override
  ConsistencyCheckState build() => const ConsistencyCheckState();

  void _set(ConsistencyCheckState s) {
    if (ref.mounted) state = s;
  }

  /// Checks the meeting. Returns true on success.
  Future<bool> run() {
    final running = _running;
    if (running != null) return running;
    final service = ref.read(consistencyServiceProvider);
    _set(const ConsistencyCheckState(running: true, statusAr: DS.checking));
    final f = () async {
      try {
        final r = await service.check(
          meetingId,
          onStatus: (s) =>
              _set(ConsistencyCheckState(running: true, statusAr: s)),
        );
        _set(ConsistencyCheckState(result: r, noticeAr: r.engineNoticeAr));
        return true;
      } catch (e) {
        _set(
          ConsistencyCheckState(
            errorAr: e is InsatoException ? e.messageAr : DS.actionFailed,
          ),
        );
        return false;
      }
    }();
    _running = f;
    return f.whenComplete(() => _running = null);
  }

  /// Clears the notice / error.
  void clearNotice() {
    if (!state.running) {
      _set(ConsistencyCheckState(result: state.result));
    }
  }
}

/// The check controller of a meeting. Not auto-disposed: a check started
/// after minutes generation keeps running while no screen listens.
final consistencyCheckProvider =
    NotifierProvider.family<
      ConsistencyCheckController,
      ConsistencyCheckState,
      String
    >(ConsistencyCheckController.new);

/// Starts the automatic check of [meetingId] after its minutes were
/// generated (no-op when [consistencyAutoCheckProvider] is false).
void startAutomaticConsistencyCheck(Ref ref, String meetingId) {
  if (!ref.read(consistencyAutoCheckProvider)) return;
  unawaited(ref.read(consistencyCheckProvider(meetingId).notifier).run());
}

// ---------------------------------------------------------------------------
// Live mode
// ---------------------------------------------------------------------------

/// Interval between two live checks.
const Duration kLiveCheckInterval = Duration(minutes: 4);

/// New transcript lines needed before a live check is worth sending.
const int kLiveMinNewLines = 4;

/// At most this many recent lines are sent.
const int kLiveMaxLines = 60;

/// State of the live check of the meeting being recorded.
class LiveConsistencyState {
  /// Creates a state.
  const LiveConsistencyState({
    this.meetingId,
    this.findings = const [],
    this.hidden = false,
    this.checking = false,
    this.lastIndex = -1,
  });

  /// Meeting checked.
  final String? meetingId;

  /// Live findings (not stored).
  final List<ConsistencyFinding> findings;

  /// The user hid the banner (until a new finding).
  final bool hidden;

  /// A check is in flight.
  final bool checking;

  /// Last segment index already checked.
  final int lastIndex;

  /// Copy.
  LiveConsistencyState copyWith({
    String? meetingId,
    List<ConsistencyFinding>? findings,
    bool? hidden,
    bool? checking,
    int? lastIndex,
  }) => LiveConsistencyState(
    meetingId: meetingId ?? this.meetingId,
    findings: findings ?? this.findings,
    hidden: hidden ?? this.hidden,
    checking: checking ?? this.checking,
    lastIndex: lastIndex ?? this.lastIndex,
  );
}

/// Runs the live checks of the meeting being recorded (driven by
/// `LiveConsistencyBanner`'s timer). Failures are silent: live mode is a
/// hint, the full check runs after the minutes.
class LiveConsistencyController extends Notifier<LiveConsistencyState> {
  @override
  LiveConsistencyState build() => const LiveConsistencyState();

  /// Checks the lines of [meetingId] added since the last check. Does
  /// nothing unless live mode is on, enough new lines exist and a cloud
  /// engine the user accepted is selected.
  Future<void> tick(String meetingId) async {
    if (state.meetingId != meetingId) {
      state = LiveConsistencyState(meetingId: meetingId);
    }
    if (state.checking) return;
    if (!await ref.read(consistencySettingsStoreProvider).liveMode()) return;
    final meeting = await ref.read(meetingRepositoryProvider).get(meetingId);
    if (meeting == null || !ref.mounted) return;
    final all = await ref
        .read(segmentRepositoryProvider)
        .getForMeeting(meetingId);
    final fresh = [
      for (final s in all)
        if (s.index > state.lastIndex && s.hasContent) s,
    ];
    if (fresh.length < kLiveMinNewLines) return;
    final recent = fresh.length > kLiveMaxLines
        ? fresh.sublist(fresh.length - kLiveMaxLines)
        : fresh;
    state = state.copyWith(checking: true);
    try {
      final found = await ref
          .read(consistencyServiceProvider)
          .liveCheck(
            meetingId: meetingId,
            title: meeting.title,
            createdAt: meeting.createdAt,
            recent: recent,
          );
      if (!ref.mounted || state.meetingId != meetingId) return;
      final keys = {for (final f in state.findings) f.key};
      final added = [
        for (final f in found)
          if (!keys.contains(f.key)) f,
      ];
      state = state.copyWith(
        findings: [...state.findings, ...added],
        hidden: added.isEmpty ? state.hidden : false,
        lastIndex: recent.last.index,
        checking: false,
      );
    } catch (_) {
      if (ref.mounted && state.meetingId == meetingId) {
        state = state.copyWith(checking: false, lastIndex: recent.last.index);
      }
    }
  }

  /// Hides the banner until a new finding.
  void hide() => state = state.copyWith(hidden: true);
}

/// The live-check controller.
final liveConsistencyProvider =
    NotifierProvider<LiveConsistencyController, LiveConsistencyState>(
      LiveConsistencyController.new,
    );

/// Live findings of a meeting being recorded (empty for another meeting).
List<ConsistencyFinding> liveFindingsOf(
  LiveConsistencyState s,
  String meetingId,
) => s.meetingId == meetingId ? s.findings : const [];
