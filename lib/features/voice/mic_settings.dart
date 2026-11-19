// Microphone settings widgets (F18): input-device selector with Bluetooth
// warning, far-field toggle and the entry to the microphone test. Used in
// Settings ([MicSettingsSection]) and before recording ([MicDeviceChip]).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../audio/audio_capture_service.dart'
    show InputDevice, InputDeviceType;
import '../../core/errors.dart';
import '../../data/secure_settings.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'enrollment_controller.dart' show meetingRecordingActiveProvider;
import 'mic_capture.dart';
import 'mic_test_screen.dart';
import 'strings.dart';
import 'voice_devices.dart';

/// Arabic label of [device] with its type, e.g. «Jabra Speak 510 (USB)».
String deviceDisplayLabel(InputDevice device) {
  final label = device.label.trim().isEmpty ? device.id : device.label.trim();
  if (device.type == InputDeviceType.unknown) return label;
  return '$label (${VoiceStrings.deviceType(device.type.name)})';
}

/// Arabic label of a stored device key (null = default microphone).
String deviceKeyDisplayLabel(String? key) {
  final parts = parseVoiceDeviceKey(key);
  if (parts == null) return VoiceStrings.defaultDevice;
  if (parts.type == InputDeviceType.unknown) return parts.label;
  return '${parts.label} (${VoiceStrings.deviceType(parts.type.name)})';
}

/// Icon of a device type.
IconData deviceIcon(InputDeviceType? type) => switch (type) {
  null => Icons.mic_rounded,
  InputDeviceType.builtIn => Icons.mic_rounded,
  InputDeviceType.bluetoothSco ||
  InputDeviceType.bluetoothA2dp ||
  InputDeviceType.bluetoothLe => Icons.bluetooth_audio_rounded,
  InputDeviceType.wiredHeadset => Icons.headset_mic_rounded,
  InputDeviceType.usb => Icons.usb_rounded,
  _ => Icons.mic_external_on_rounded,
};

/// Lets the user pick the input device; remembers the choice. Returns true
/// when a choice was saved.
Future<bool> showInputDevicePicker(BuildContext context, WidgetRef ref) async {
  final picked = await showDialog<_Pick>(
    context: context,
    builder: (_) => const _DevicePickerDialog(),
  );
  if (picked == null || !context.mounted) return false;
  try {
    await ref.read(inputDevicePreferencesProvider).remember(picked.device);
  } catch (e) {
    if (context.mounted) {
      showSnack(
        context,
        e is InsatoException ? e.messageAr : S.unexpectedError,
        error: true,
      );
    }
    return false;
  }
  ref.invalidate(rememberedInputDeviceProvider);
  if (!context.mounted) return true;
  final base = picked.device == null
      ? VoiceStrings.defaultChosen
      : VoiceStrings.deviceChosen(deviceDisplayLabel(picked.device!));
  final busy = ref.read(meetingRecordingActiveProvider);
  showSnack(
    context,
    busy ? '$base ${VoiceStrings.appliesNextRecording}' : base,
  );
  return true;
}

class _Pick {
  const _Pick(this.device);

  final InputDevice? device;
}

class _DevicePickerDialog extends ConsumerWidget {
  const _DevicePickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(inputDevicesProvider);
    final remembered = ref.watch(rememberedInputDeviceProvider).value;
    final list = devices.value ?? const <InputDevice>[];
    final resolution = remembered == null
        ? const InputDeviceResolution()
        : resolveRemembered(list, remembered);
    final selectedId = resolution.device?.id;
    final defaultSelected =
        remembered == null || remembered.isDefault || resolution.missing;
    final scheme = Theme.of(context).colorScheme;

    Widget tile({required InputDevice? device, required bool selected}) {
      final bt = device != null && isBluetoothInput(device.type);
      return ListTile(
        selected: selected,
        leading: Icon(deviceIcon(device?.type)),
        title: Text(
          device == null
              ? VoiceStrings.defaultDevice
              : deviceDisplayLabel(device),
        ),
        subtitle: device == null
            ? const Text(VoiceStrings.defaultDeviceHint)
            : bt
            ? Text(
                VoiceStrings.bluetoothBadge,
                style: TextStyle(color: scheme.error),
              )
            : null,
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: () => Navigator.of(context).pop(_Pick(device)),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text(VoiceStrings.chooseDevice)),
          IconButton(
            tooltip: VoiceStrings.refreshDevices,
            onPressed: () => ref.invalidate(inputDevicesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (remembered != null && resolution.missing)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ErrorBanner(
                  message: VoiceStrings.rememberedMissing(
                    remembered.label ?? remembered.id ?? '',
                  ),
                  severity: BannerSeverity.warning,
                ),
              ),
            tile(device: null, selected: defaultSelected),
            if (devices.isLoading && !devices.hasValue)
              const ListTile(
                leading: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                title: Text(VoiceStrings.loadingDevices),
              ),
            if (devices.hasError && !devices.hasValue)
              Padding(
                padding: const EdgeInsets.all(8),
                child: ErrorBanner(
                  message: VoiceStrings.devicesFailed,
                  onRetry: () => ref.invalidate(inputDevicesProvider),
                ),
              ),
            for (final d in list)
              tile(device: d, selected: !defaultSelected && d.id == selectedId),
            if (list.any((d) => isBluetoothInput(d.type)))
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ErrorBanner(
                  message: VoiceStrings.bluetoothWarning,
                  severity: BannerSeverity.info,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
      ],
    );
  }
}

/// Settings tile showing the remembered microphone; tap to change it.
class InputDeviceTile extends ConsumerWidget {
  /// Creates the tile.
  const InputDeviceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remembered = ref.watch(rememberedInputDeviceProvider).value;
    final key = remembered?.key;
    final parts = parseVoiceDeviceKey(key);
    final bt = parts != null && isBluetoothInput(parts.type);
    final label = remembered == null || remembered.isDefault
        ? VoiceStrings.defaultDevice
        : (key != null
              ? deviceKeyDisplayLabel(key)
              : (remembered.label ?? VoiceStrings.defaultDevice));
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(deviceIcon(parts?.type)),
          title: const Text(VoiceStrings.inputDevice),
          subtitle: Text(label),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => showInputDevicePicker(context, ref),
        ),
        if (bt)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: scheme.error,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text(VoiceStrings.bluetoothWarning)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Far-field ("meeting room") toggle.
class FarFieldTile extends ConsumerWidget {
  /// Creates the tile.
  const FarFieldTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(appSettingsDataProvider).value?.farFieldMode ?? false;
    return SwitchListTile(
      secondary: const Icon(Icons.meeting_room_rounded),
      title: const Text(VoiceStrings.farField),
      subtitle: const Text(VoiceStrings.farFieldHint),
      value: on,
      onChanged: (v) async {
        try {
          await ref.read(appSettingsProvider).setFarFieldMode(v);
        } catch (e) {
          if (context.mounted) {
            showSnack(context, S.unexpectedError, error: true);
          }
        }
      },
    );
  }
}

/// Entry to the microphone test.
class MicTestTile extends StatelessWidget {
  /// Creates the tile.
  const MicTestTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.graphic_eq_rounded),
    title: const Text(VoiceStrings.micTest),
    subtitle: const Text(VoiceStrings.micTestHint),
    trailing: const Icon(Icons.chevron_left_rounded),
    onTap: () => openMicTest(context),
  );
}

/// The "الميكروفون" settings section: device, far field, microphone test.
class MicSettingsSection extends StatelessWidget {
  /// Creates the section.
  const MicSettingsSection({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(VoiceStrings.micSection, icon: Icons.mic_rounded),
      Card(
        child: Column(
          children: [
            InputDeviceTile(),
            Divider(height: 1),
            FarFieldTile(),
            Divider(height: 1),
            MicTestTile(),
          ],
        ),
      ),
    ],
  );
}

/// Compact microphone chip for the recording screen (before / during a
/// meeting). Tapping opens the device picker; a change applies to the next
/// recording.
class MicDeviceChip extends ConsumerWidget {
  /// Creates the chip.
  const MicDeviceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remembered = ref.watch(rememberedInputDeviceProvider).value;
    final parts = parseVoiceDeviceKey(remembered?.key);
    final label = remembered == null || remembered.isDefault
        ? VoiceStrings.defaultDevice
        : (parts?.label ?? remembered.label ?? VoiceStrings.defaultDevice);
    final bt = parts != null && isBluetoothInput(parts.type);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${VoiceStrings.inputDevice}: $label',
      excludeSemantics: true,
      child: ActionChip(
        avatar: Icon(
          deviceIcon(parts?.type),
          size: 18,
          color: bt ? scheme.error : null,
        ),
        label: Text(label, overflow: TextOverflow.ellipsis),
        tooltip: bt ? VoiceStrings.bluetoothWarning : VoiceStrings.chooseDevice,
        onPressed: () => showInputDevicePicker(context, ref),
      ),
    );
  }
}
