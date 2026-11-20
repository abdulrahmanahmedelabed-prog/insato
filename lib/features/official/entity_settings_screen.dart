// Settings → «الجهة والقوالب» (v1.2): the entity profile (name, logo,
// councils / committees, default chair / secretary / place, numbering
// year) and the institution's own Word templates (upload, link to a
// built-in template's rules, delete), the downloadable sample template and
// the placeholder guide.

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time_format.dart';
import '../../session/providers.dart';
import '../../ui/strings_ar.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/dialogs.dart';
import '../export_docx/docx_export_service.dart'
    show MinutesExportFormat, docxExportServiceProvider;
import 'docx_template.dart' show DocxTemplateException;
import 'official_models.dart';
import 'official_service.dart';
import 'official_templates.dart';
import 'strings.dart';
import 'template_placeholders.dart';

/// A file chosen by the user.
class PickedFile {
  /// Creates a picked file.
  const PickedFile(this.name, this.bytes);

  /// File name.
  final String name;

  /// Content.
  final Uint8List bytes;
}

/// Opens the platform file chooser (overridable in tests).
abstract class OfficialFilePicker {
  /// Lets the user choose an image (PNG / JPG).
  Future<PickedFile?> pickImage();

  /// Lets the user choose a Word document (.docx).
  Future<PickedFile?> pickDocx();
}

class _FileSelectorPicker implements OfficialFilePicker {
  const _FileSelectorPicker();

  Future<PickedFile?> _pick(fs.XTypeGroup group) async {
    final f = await fs.openFile(acceptedTypeGroups: [group]);
    if (f == null) return null;
    return PickedFile(f.name, await f.readAsBytes());
  }

  @override
  Future<PickedFile?> pickImage() => _pick(
    const fs.XTypeGroup(
      label: 'صور',
      extensions: ['png', 'jpg', 'jpeg'],
      mimeTypes: ['image/png', 'image/jpeg'],
      uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
    ),
  );

  @override
  Future<PickedFile?> pickDocx() => _pick(
    const fs.XTypeGroup(
      label: 'Word',
      extensions: ['docx'],
      mimeTypes: [
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ],
      uniformTypeIdentifiers: ['org.openxmlformats.wordprocessingml.document'],
    ),
  );
}

/// The file picker used by the settings screen.
final officialFilePickerProvider = Provider<OfficialFilePicker>(
  (ref) => const _FileSelectorPicker(),
);

/// Opens the entity & templates settings.
Future<void> openEntitySettingsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const EntitySettingsScreen()),
    );

/// Settings tile opening [EntitySettingsScreen].
class EntitySettingsTile extends StatelessWidget {
  /// Creates the tile.
  const EntitySettingsTile({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.account_balance_rounded),
      title: const Text(OS.entityTitle),
      subtitle: const Text(OS.entitySubtitle),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => openEntitySettingsScreen(context),
    ),
  );
}

/// The entity & templates settings screen.
class EntitySettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const EntitySettingsScreen({super.key});

  @override
  ConsumerState<EntitySettingsScreen> createState() =>
      _EntitySettingsScreenState();
}

class _EntitySettingsScreenState extends ConsumerState<EntitySettingsScreen> {
  final _name = TextEditingController();
  final _chair = TextEditingController();
  final _secretary = TextEditingController();
  final _place = TextEditingController();
  final _committee = TextEditingController();
  EntityProfile? _loaded;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _chair.dispose();
    _secretary.dispose();
    _place.dispose();
    _committee.dispose();
    super.dispose();
  }

  void _fill(EntityProfile p) {
    if (_loaded != null) return;
    _loaded = p;
    _name.text = p.entityName;
    _chair.text = p.chairName;
    _secretary.text = p.secretaryName;
    _place.text = p.defaultPlace;
  }

  Future<void> _saveProfile(EntityProfile p, {bool quiet = false}) async {
    await ref.read(officialSettingsStoreProvider).saveProfile(p);
    _loaded = p;
    if (!quiet && mounted) showSnack(context, OS.saved);
  }

  EntityProfile _fromFields(EntityProfile p) => p.copyWith(
    entityName: _name.text.trim(),
    chairName: _chair.text.trim(),
    secretaryName: _secretary.text.trim(),
    defaultPlace: _place.text.trim(),
  );

  Future<void> _guard(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } on OfficialActionException catch (e) {
      if (mounted) showSnack(context, e.messageAr, error: true);
    } on DocxTemplateException catch (e) {
      if (mounted) showSnack(context, e.messageAr, error: true);
    } catch (_) {
      if (mounted) showSnack(context, OS.fileReadFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickLogo() => _guard(() async {
    final f = await ref.read(officialFilePickerProvider).pickImage();
    if (f == null) return;
    final service = ref.read(officialMinutesServiceProvider);
    // Keep any unsaved text fields.
    await _saveProfile(
      _fromFields(await ref.read(officialSettingsStoreProvider).profile()),
      quiet: true,
    );
    _loaded = await service.setLogo(f.bytes, f.name);
    ref.invalidate(_logoProvider);
    if (mounted) showSnack(context, OS.saved);
  });

  Future<void> _upload() => _guard(() async {
    final f = await ref.read(officialFilePickerProvider).pickDocx();
    if (f == null || !mounted) return;
    final details = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _TemplateDetailsDialog(
        initialName: f.name.replaceAll(
          RegExp(r'\.docx$', caseSensitive: false),
          '',
        ),
      ),
    );
    if (details == null) return;
    final t = await ref
        .read(officialMinutesServiceProvider)
        .uploadTemplate(
          bytes: f.bytes,
          fileName: f.name,
          name: details.$1,
          baseTemplateId: details.$2,
        );
    if (mounted) showSnack(context, OS.templateUploaded(t.placeholders.length));
  });

  Future<void> _downloadSample() => _guard(() async {
    final origin = shareOriginOf(context);
    final r = await ref
        .read(docxExportServiceProvider)
        .shareFile(
          bytes: buildSampleTemplate(),
          fileName: OS.sampleFileName,
          mimeType: MinutesExportFormat.docx.mimeType,
          subject: OS.downloadSample,
          body: placeholderGuideLines().join('\n'),
          origin: origin,
        );
    if (r.savedPath != null && mounted) {
      showSnack(context, S.savedTo(r.savedPath!));
    }
  });

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(entityProfileProvider);
    final templates = ref.watch(customTemplatesProvider).value ?? const [];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(OS.entityTitle),
        actions: [
          TextButton(
            onPressed: _loaded == null
                ? null
                : () => _guard(() => _saveProfile(_fromFields(_loaded!))),
            child: const Text(S.save),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(S.unexpectedError)),
        data: (p) {
          _fill(p);
          final profile = _loaded ?? p;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    const SectionHeader(
                      OS.entitySection,
                      icon: Icons.account_balance_rounded,
                    ),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: OS.entityName,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LogoRow(
                      hasLogo: profile.logoFile != null,
                      busy: _busy,
                      onPick: _pickLogo,
                      onRemove: () => _guard(() async {
                        _loaded = await ref
                            .read(officialMinutesServiceProvider)
                            .clearLogo();
                        ref.invalidate(_logoProvider);
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _chair,
                      decoration: const InputDecoration(
                        labelText: OS.defaultChair,
                      ),
                    ),
                    TextField(
                      controller: _secretary,
                      decoration: const InputDecoration(
                        labelText: OS.defaultSecretary,
                      ),
                    ),
                    TextField(
                      controller: _place,
                      decoration: const InputDecoration(
                        labelText: OS.defaultPlace,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(OS.yearStyle, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    SegmentedButton<NumberYearStyle>(
                      segments: const [
                        ButtonSegment(
                          value: NumberYearStyle.hijri,
                          label: Text(OS.hijriYear),
                        ),
                        ButtonSegment(
                          value: NumberYearStyle.gregorian,
                          label: Text(OS.gregorianYear),
                        ),
                      ],
                      selected: {profile.yearStyle},
                      onSelectionChanged: (v) => _guard(
                        () => _saveProfile(
                          _fromFields(profile).copyWith(yearStyle: v.first),
                          quiet: true,
                        ),
                      ),
                    ),
                    SectionHeader(
                      OS.committees,
                      icon: Icons.groups_2_outlined,
                      trailing: Text('${profile.committees.length}'),
                    ),
                    Text(OS.committeesHelper, style: theme.textTheme.bodySmall),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final c in profile.committees)
                          InputChip(
                            label: Text(c),
                            onDeleted: () => _guard(
                              () => _saveProfile(
                                _fromFields(profile).copyWith(
                                  committees: [
                                    for (final x in profile.committees)
                                      if (x != c) x,
                                  ],
                                ),
                                quiet: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _committee,
                            decoration: const InputDecoration(
                              labelText: OS.addCommittee,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: OS.addCommittee,
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () {
                            final c = _committee.text.trim();
                            if (c.isEmpty || profile.committees.contains(c)) {
                              return;
                            }
                            _committee.clear();
                            _guard(
                              () => _saveProfile(
                                _fromFields(profile).copyWith(
                                  committees: [...profile.committees, c],
                                ),
                                quiet: true,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // ------------------------------------------ Templates
                    const SectionHeader(
                      OS.templatesSection,
                      icon: Icons.description_rounded,
                    ),
                    Text(OS.templatesIntro, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _upload,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text(OS.uploadTemplate),
                        ),
                        Builder(
                          builder: (context) => OutlinedButton.icon(
                            onPressed: _busy ? null : _downloadSample,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text(OS.downloadSample),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (templates.isEmpty) const Text(OS.noTemplates),
                    for (final t in templates)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(t.name),
                          subtitle: Text(
                            '${OfficialTemplates.byId(t.baseTemplateId).nameAr}'
                            ' — ${OS.placeholdersCount(t.placeholders.length)}'
                            ' — ${formatArabicShortDate(t.uploadedAt)}',
                          ),
                          trailing: IconButton(
                            tooltip: OS.deleteTemplate,
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: OS.deleteTemplate,
                                body: OS.deleteTemplateBody,
                                confirmLabel: S.delete,
                                destructive: true,
                              );
                              if (ok) {
                                await _guard(
                                  () => ref
                                      .read(officialMinutesServiceProvider)
                                      .deleteTemplate(t),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(OS.placeholderGuide),
                      children: [
                        for (final ph in kTemplatePlaceholders)
                          ListTile(
                            dense: true,
                            title: Directionality(
                              textDirection: TextDirection.ltr,
                              child: SelectableText(ph.token),
                            ),
                            subtitle: Text(ph.descriptionAr),
                          ),
                      ],
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

final _logoProvider = FutureProvider.autoDispose<Uint8List?>((ref) async {
  ref.watch(entityProfileProvider);
  return ref.read(officialMinutesServiceProvider).logoBytes();
});

class _LogoRow extends ConsumerWidget {
  const _LogoRow({
    required this.hasLogo,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final bool hasLogo;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = hasLogo ? ref.watch(_logoProvider).value : null;
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: bytes == null
              ? const Icon(Icons.image_outlined)
              : Image.memory(bytes, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(OS.logo, style: theme.textTheme.titleSmall),
              Text(
                hasLogo ? OS.logoFormats : OS.noLogo,
                style: theme.textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : onPick,
                    child: const Text(OS.pickLogo),
                  ),
                  if (hasLogo)
                    TextButton(
                      onPressed: busy ? null : onRemove,
                      child: const Text(OS.removeLogo),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateDetailsDialog extends StatefulWidget {
  const _TemplateDetailsDialog({required this.initialName});

  final String initialName;

  @override
  State<_TemplateDetailsDialog> createState() => _TemplateDetailsDialogState();
}

class _TemplateDetailsDialogState extends State<_TemplateDetailsDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  String _base = OfficialTemplates.board.id;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(OS.uploadTemplate),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: OS.templateName),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _base,
          isExpanded: true,
          decoration: const InputDecoration(labelText: OS.baseTemplate),
          items: [
            for (final t in OfficialTemplates.all)
              if (t.isOfficial)
                DropdownMenuItem(value: t.id, child: Text(t.nameAr)),
          ],
          onChanged: (v) => setState(() => _base = v ?? _base),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(S.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop((_name.text.trim(), _base)),
        child: const Text(OS.uploadTemplate),
      ),
    ],
  );
}
