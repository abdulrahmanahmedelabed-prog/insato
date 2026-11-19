// Audio-source selector (F13 / D1): microphone, system audio or both. The
// only Windows-specific control of the app; renders nothing elsewhere.
// Used in Settings (full) and on the recording screen (compact).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../data/secure_settings.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../voice/enrollment_controller.dart'
    show meetingRecordingActiveProvider;
import '../voice/mic_capture.dart' show capturePlatformProvider;
import '../voice/strings.dart' show VoiceStrings;
import 'mixed_session_audio_source.dart';
import 'strings.dart';

/// Short Arabic label of an `audioSource` setting value.
String audioSourceLabel(String value) => switch (value) {
  AppSettingsData.audioSourceMic => SystemAudioStrings.mic,
  AppSettingsData.audioSourceSystem => SystemAudioStrings.system,
  _ => SystemAudioStrings.both,
};

/// Long Arabic description of an `audioSource` setting value.
String audioSourceDescription(String value) => switch (value) {
  AppSettingsData.audioSourceMic => SystemAudioStrings.micLong,
  AppSettingsData.audioSourceSystem => SystemAudioStrings.systemLong,
  _ => SystemAudioStrings.bothLong,
};

IconData _icon(String value) => switch (value) {
  AppSettingsData.audioSourceMic => Icons.mic_rounded,
  AppSettingsData.audioSourceSystem => Icons.speaker_rounded,
  _ => Icons.merge_type_rounded,
};

/// Mic / system / both selector bound to `AppSettingsData.audioSource`.
/// Shown only on Windows. [compact] drops the title and explanation (for
/// the recording screen).
class AudioSourceSelector extends ConsumerWidget {
  /// Creates the selector.
  const AudioSourceSelector({super.key, this.compact = false});

  /// Segmented control only, without title and hints.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(capturePlatformProvider) != CapturePlatform.windows) {
      return const SizedBox.shrink();
    }
    final stored =
        ref.watch(appSettingsDataProvider).value?.audioSource ??
        AppSettingsData.audioSourceBoth;
    final value = AppSettingsData.audioSources.contains(stored)
        ? stored
        : AppSettingsData.audioSourceBoth;
    final supported = ref.watch(systemAudioSupportedProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;

    final selector = SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 48)),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      segments: [
        for (final v in AppSettingsData.audioSources)
          ButtonSegment<String>(
            value: v,
            icon: Icon(_icon(v)),
            label: Text(audioSourceLabel(v)),
            tooltip: audioSourceDescription(v),
            enabled: supported || v == AppSettingsData.audioSourceMic,
          ),
      ],
      selected: {supported ? value : AppSettingsData.audioSourceMic},
      onSelectionChanged: (picked) => _save(context, ref, picked.first),
    );

    final notes = <Widget>[
      if (!supported)
        _Note(
          icon: Icons.info_outline_rounded,
          text: SystemAudioStrings.unsupported,
          color: scheme.error,
        )
      else if (value == AppSettingsData.audioSourceBoth && !compact)
        const _Note(
          icon: Icons.headphones_rounded,
          text: SystemAudioStrings.headphonesTip,
        ),
    ];

    if (compact) {
      return Semantics(
        container: true,
        label: SystemAudioStrings.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: selector,
              ),
            ),
            ...notes,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          SystemAudioStrings.title,
          icon: Icons.settings_input_component_rounded,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  SystemAudioStrings.hint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Semantics(
                  container: true,
                  label: SystemAudioStrings.title,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: selector,
                    ),
                  ),
                ),
                ...notes,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String value) async {
    try {
      await ref.read(appSettingsProvider).setAudioSource(value);
    } catch (_) {
      if (context.mounted) showSnack(context, S.unexpectedError, error: true);
      return;
    }
    if (!context.mounted) return;
    final base = SystemAudioStrings.chosen(audioSourceLabel(value));
    final busy = ref.read(meetingRecordingActiveProvider);
    showSnack(
      context,
      busy ? '$base ${VoiceStrings.appliesNextRecording}' : base,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
