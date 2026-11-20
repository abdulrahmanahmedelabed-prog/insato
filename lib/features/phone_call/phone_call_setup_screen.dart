// Setup screen of phone-call mode: mode, call language, legal notice,
// step-by-step guide and the level check, then «بدء تسجيل المكالمة»
// (arms the setup and opens the usual new-meeting flow).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../audio/audio_capture_service.dart' show CapturePlatform;
import '../../session/providers.dart' show meetingSessionControllerProvider;
import '../../ui/widgets/common.dart';
import '../context/meeting_context_flows.dart' show startNewMeetingWithContext;
import '../voice/mic_capture.dart' show capturePlatformProvider;
import 'phone_call_check.dart';
import 'phone_call_guide.dart';
import 'phone_call_models.dart';
import 'phone_call_providers.dart';
import 'strings.dart';
import 'telephone_profile.dart' show kCallLanguageAuto;

/// Opens the setup screen; on «بدء» arms the call and starts a new meeting
/// (consent, context form, recording screen).
Future<void> startPhoneCallFlow(BuildContext context, WidgetRef ref) async {
  if (ref.read(meetingSessionControllerProvider).isActive) {
    showSnack(context, PCS.busy, error: true);
    return;
  }
  final setup = await Navigator.of(context).push<PhoneCallSetup>(
    MaterialPageRoute(builder: (_) => const PhoneCallSetupScreen()),
  );
  if (setup == null || !context.mounted) return;
  ref.read(phoneCallSetupProvider.notifier).arm(setup);
  await startNewMeetingWithContext(context, ref);
}

/// See the file header. Pops with the chosen [PhoneCallSetup].
class PhoneCallSetupScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PhoneCallSetupScreen({super.key});

  @override
  ConsumerState<PhoneCallSetupScreen> createState() =>
      _PhoneCallSetupScreenState();
}

class _PhoneCallSetupScreenState extends ConsumerState<PhoneCallSetupScreen> {
  late PhoneCallMode _mode;
  late final PhoneCallCheckController _check;
  String? _language;
  bool _consent = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final windows =
        ref.read(capturePlatformProvider) == CapturePlatform.windows;
    _mode = windows ? PhoneCallMode.phoneLink : PhoneCallMode.speakerphone;
    _check = PhoneCallCheckController(
      ref.read(phoneCallProbeFactoryProvider),
      _mode,
    );
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  Future<void> _setMode(PhoneCallMode m) async {
    setState(() => _mode = m);
    await _check.setMode(m);
  }

  Future<void> _start() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    // The microphone must be free before the meeting opens it.
    await _check.stop();
    if (!mounted) return;
    Navigator.of(context)
        .pop(PhoneCallSetup(mode: _mode, languageChoice: _language));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = ref.watch(capturePlatformProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(PCS.title)),
      body: ListenableBuilder(
        listenable: _check,
        builder: (context, _) {
          final ready = _check.tracker.ready;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(PCS.intro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    for (final m in PhoneCallMode.values)
                      _ModeTile(
                        mode: m,
                        selected: m == _mode,
                        enabled: phoneCallModeAvailable(m, platform),
                        onTap: () => _setMode(m),
                      ),
                    const SizedBox(height: 8),
                    _LanguageChoice(
                      value: _language,
                      onChanged: (v) => setState(() => _language = v),
                    ),
                    const SizedBox(height: 8),
                    _LegalCard(
                      consent: _consent,
                      onChanged: (v) => setState(() => _consent = v),
                    ),
                    const SizedBox(height: 8),
                    PhoneCallGuide(key: ValueKey(_mode), mode: _mode),
                    const SizedBox(height: 8),
                    PhoneCallCheckPanel(controller: _check),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const ValueKey('phone-call-start'),
                      onPressed: _consent && ready && !_leaving ? _start : null,
                      icon: const Icon(Icons.fiber_manual_record_rounded),
                      label: const Text(PCS.start),
                    ),
                    if (!ready)
                      TextButton(
                        key: const ValueKey('phone-call-start-anyway'),
                        onPressed: _consent && !_leaving ? _start : null,
                        child: const Text(PCS.startAnyway),
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

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PhoneCallMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phoneLink = mode == PhoneCallMode.phoneLink;
    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: ListTile(
        enabled: enabled,
        selected: selected,
        onTap: enabled ? onTap : null,
        leading: Icon(
          phoneLink ? Icons.computer_rounded : Icons.speaker_phone_rounded,
        ),
        title: Text(phoneLink ? PCS.modePhoneLink : PCS.modeSpeakerphone),
        subtitle: Text(
          !enabled
              ? PCS.modePhoneLinkWindowsOnly
              : (phoneLink ? PCS.modePhoneLinkHint : PCS.modeSpeakerphoneHint),
        ),
        trailing: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = <(String?, String)>[
    (null, PCS.languageSettings),
    (kCallLanguageAuto, PCS.languageAuto),
    ('ar', PCS.languageArabic),
    ('en', PCS.languageEnglish),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(PCS.languageTitle, style: theme.textTheme.titleSmall),
            Text(PCS.languageHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (v, label) in _options)
                  ChoiceChip(
                    label: Text(label),
                    selected: value == v,
                    onSelected: (_) => onChanged(v),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.consent, required this.onChanged});

  final bool consent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PCS.legalTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              PCS.legalBody,
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
            ),
            CheckboxListTile(
              key: const ValueKey('phone-call-consent'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: consent,
              onChanged: (v) => onChanged(v ?? false),
              title: const Text(PCS.legalConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
