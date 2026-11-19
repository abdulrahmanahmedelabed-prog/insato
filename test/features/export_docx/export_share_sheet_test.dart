import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/export_docx/docx_export_service.dart';
import 'package:insato/features/export_docx/export_share_sheet.dart';
import 'package:insato/features/export_docx/strings.dart';
import 'package:insato/session/providers.dart';
import 'package:insato/ui/strings_ar.dart';
import 'package:insato/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../ui/harness.dart';
import 'xml_check.dart';

class _Share {
  final List<ShareParams> params = [];
  final List<Uint8List> bytes = [];

  Future<void> call(ShareParams p) async {
    params.add(p);
    bytes.add(await p.files!.single.readAsBytes());
  }
}

Future<void> _pump(
  WidgetTester t,
  UiTestEnv env,
  _Share share,
  String meetingId, {
  bool enabled = true,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...env.overrides,
        docxExportServiceProvider.overrideWith(
          (ref) => DocxExportService(
            export: ref.watch(exportServiceProvider),
            exportsDir: () async => '${env.tmp.path}/exports',
            shareTempDir: () async => '${env.tmp.path}/share',
            isMobile: true,
            share: share.call,
          ),
        ),
      ],
      retry: (_, _) => null,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: InsatoTheme.light(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ExportShareButton(meetingId: meetingId, enabled: enabled),
            ],
          ),
        ),
      ),
    ),
  );
  await settle(t);
}

/// Pumps real-async rounds until [done] or the rounds run out.
Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
  await settle(t);
}

void main() {
  for (final size in [kPhone, kDesktop]) {
    testWidgets('Word: shares a .docx with subject and body (${size.width})', (
      t,
    ) async {
      setScreenSize(t, size);
      final env = UiTestEnv();
      final seeded = await env.run(t, () => seedMeeting(env));
      final share = _Share();
      await _pump(t, env, share, seeded.meeting.id);

      await t.tap(find.byTooltip(XS.openSheet));
      await settle(t);
      expect(find.text(XS.sheetTitle), findsOneWidget);
      for (final s in [
        XS.shareDocx,
        XS.sharePdf,
        XS.shareMarkdown,
        XS.printPdf,
        S.includeTranscript,
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // Every option is a comfortable touch target.
      expect(
        t.getSize(find.widgetWithText(ListTile, XS.printPdf)).height,
        greaterThanOrEqualTo(48),
      );

      await t.tap(find.text(S.includeTranscript));
      await t.pump();
      await t.tap(find.text(XS.shareDocx));
      await _until(t, () => share.params.isNotEmpty);

      final p = share.params.single;
      expect(p.subject, 'محضر اجتماع: محضر اجتماع الميزانية');
      expect(p.text, contains('ناقش الفريق ميزانية التسويق للربع القادم.'));
      expect(p.text, contains(XS.attachedAs('Word')));
      expect(p.files!.single.name, endsWith('.docx'));
      final parts = unzipParts(share.bytes.single);
      final text = plainText(parts['word/document.xml']!);
      expect(text, contains('إعداد تقرير الميزانية'));
      expect(text, contains(XS.transcriptAppendix));
      expect(text, contains('We should finalize the marketing budget'));
      // The sheet closed.
      expect(find.text(XS.sheetTitle), findsNothing);
      expect(Directory('${env.tmp.path}/share').listSync(), isEmpty);
      await env.dispose(t);
    });
  }

  testWidgets('Markdown and print', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env));
    final share = _Share();
    await _pump(t, env, share, seeded.meeting.id);

    await t.tap(find.byTooltip(XS.openSheet));
    await settle(t);
    await t.tap(find.text(XS.shareMarkdown));
    await _until(t, () => share.params.isNotEmpty);
    expect(share.params.single.files!.single.mimeType, 'text/markdown');
    expect(
      utf8.decode(share.bytes.single),
      startsWith('# محضر اجتماع: محضر اجتماع الميزانية'),
    );

    await t.tap(find.byTooltip(XS.openSheet));
    await settle(t);
    await t.tap(find.text(XS.printPdf));
    await _until(t, () => env.share.prints > 0);
    expect(env.share.prints, 1);
    await env.dispose(t);
  });

  testWidgets('no minutes: an error snack bar, nothing shared', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final seeded = await env.run(t, () => seedMeeting(env, withMinutes: false));
    final share = _Share();
    await _pump(t, env, share, seeded.meeting.id);

    await t.tap(find.byTooltip(XS.openSheet));
    await settle(t);
    await t.tap(find.text(XS.shareDocx));
    await _until(t, () => find.text(S.noMinutesToExport).evaluate().isNotEmpty);
    expect(find.text(S.noMinutesToExport), findsOneWidget);
    expect(share.params, isEmpty);
    await env.dispose(t);
  });

  testWidgets('disabled button does not open the sheet', (t) async {
    setScreenSize(t, kPhone);
    final env = UiTestEnv();
    final share = _Share();
    await _pump(t, env, share, 'missing', enabled: false);
    await t.tap(find.byTooltip(XS.openSheet));
    await settle(t);
    expect(find.text(XS.sheetTitle), findsNothing);
    await env.dispose(t);
  });
}
