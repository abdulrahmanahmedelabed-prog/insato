// Step-by-step Arabic guide of phone-call mode: pairing Phone Link with an
// Android phone or an iPhone, or placing a phone on speaker.

import 'package:material_ui/material_ui.dart';

import 'phone_call_models.dart';
import 'strings.dart';

/// Phone platform of the Phone Link guide.
enum GuidePhone {
  /// Android ("Link to Windows").
  android,

  /// iPhone.
  iphone,
}

/// Steps of [mode] (Phone Link: for [phone]).
List<String> phoneCallGuideSteps(PhoneCallMode mode, GuidePhone phone) =>
    switch (mode) {
      PhoneCallMode.speakerphone => PCS.speakerSteps,
      PhoneCallMode.phoneLink =>
        phone == GuidePhone.android ? PCS.androidSteps : PCS.iphoneSteps,
    };

/// The guide of [mode], with an Android / iPhone switch for Phone Link.
class PhoneCallGuide extends StatefulWidget {
  /// Creates the guide.
  const PhoneCallGuide({super.key, required this.mode});

  /// The chosen mode.
  final PhoneCallMode mode;

  @override
  State<PhoneCallGuide> createState() => _PhoneCallGuideState();
}

class _PhoneCallGuideState extends State<PhoneCallGuide> {
  GuidePhone _phone = GuidePhone.android;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phoneLink = widget.mode == PhoneCallMode.phoneLink;
    final steps = phoneCallGuideSteps(widget.mode, _phone);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              phoneLink ? PCS.guideTitle : PCS.speakerGuideTitle,
              style: theme.textTheme.titleSmall,
            ),
            if (phoneLink) ...[
              const SizedBox(height: 8),
              SegmentedButton<GuidePhone>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: GuidePhone.android,
                    icon: Icon(Icons.android_rounded),
                    label: Text(PCS.android),
                  ),
                  ButtonSegment(
                    value: GuidePhone.iphone,
                    icon: Icon(Icons.phone_iphone_rounded),
                    label: Text(PCS.iphone),
                  ),
                ],
                selected: {_phone},
                onSelectionChanged: (s) => setState(() => _phone = s.first),
              ),
            ],
            const SizedBox(height: 8),
            for (var i = 0; i < steps.length; i++)
              _Step(number: i + 1, text: steps[i]),
            if (phoneLink) ...[
              const Divider(height: 20),
              for (final tip in PCS.phoneLinkTips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tip, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$number',
              style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
