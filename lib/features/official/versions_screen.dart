// History of approved versions of official minutes (v1.2): every approval
// is kept with its content, hash and signatures; a version opens read-only.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import 'official_document.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_service.dart';
import 'strings.dart';

/// Opens the version history of [meetingId].
Future<void> openVersionsScreen(BuildContext context, String meetingId) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VersionsScreen(meetingId: meetingId),
      ),
    );

/// The version history.
class VersionsScreen extends ConsumerWidget {
  /// Creates the screen.
  const VersionsScreen({super.key, required this.meetingId});

  /// Meeting.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = ref.watch(minutesVersionsProvider(meetingId));
    final signatures =
        ref.watch(minutesSignaturesProvider(meetingId)).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text(OS.versions)),
      body: versions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(S.unexpectedError)),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: OS.noVersions,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final v in list)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${v.version}')),
                        title: Text(OS.version(v.version)),
                        subtitle: Text(
                          '${formatArabicDateTime(v.approvedAt)}\n'
                          '${OS.signatures}: '
                          '${signatures.where((s) => s.version == v.version).length}\n'
                          '${formatHash(v.contentHash)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => VersionViewScreen(
                              meetingId: meetingId,
                              version: v,
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

/// A read-only view of one approved version.
class VersionViewScreen extends ConsumerWidget {
  /// Creates the view.
  const VersionViewScreen({
    super.key,
    required this.meetingId,
    required this.version,
  });

  /// Meeting.
  final String meetingId;

  /// The version.
  final MinutesVersion version;

  Future<String> _render(WidgetRef ref) async {
    final meeting = await ref.read(meetingRepositoryProvider).get(meetingId);
    if (meeting == null) return S.meetingNotFound;
    final service = ref.read(officialMinutesServiceProvider);
    final profile = await ref.read(officialSettingsStoreProvider).profile();
    final sigs = await ref
        .read(officialMinutesRepositoryProvider)
        .signatures(meetingId, version: version.version);
    final doc = buildOfficialDocument(
      meeting: meeting,
      minutes: version.minutes,
      record: version.record,
      profile: profile,
      choice: await service.templateOf(meeting),
      signatures: sigs,
    );
    return ref
        .read(exportServiceProvider)
        .toPlainText(
          meeting,
          version.minutes,
          await ref.read(speakerRepositoryProvider).getAllById(),
          official: doc,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(OS.version(version.version))),
      body: FutureBuilder<String>(
        future: _render(ref),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${OS.hashLabel}: ${version.contentHash}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Divider(),
                    SelectableText(snap.data!),
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
