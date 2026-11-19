// Platform sharing / printing / clipboard behind one seam, so screens stay
// testable without the share_plus and printing plugins.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../session/providers.dart';

/// Result of a share action.
class ShareOutcome {
  /// Creates an outcome.
  const ShareOutcome({required this.shared, this.savedPath});

  /// True when the system share sheet was shown.
  final bool shared;

  /// Where a copy of the exported file was saved (desktop / fallback).
  final String? savedPath;
}

/// Sharing, printing and clipboard used by the UI.
abstract class ShareGateway {
  /// Copies [text] to the clipboard.
  Future<void> copyText(String text);

  /// Shares plain [text] through the system share sheet.
  Future<ShareOutcome> shareText(String text, {String? subject, Rect? origin});

  /// Saves [bytes] as [fileName] in the exports folder and offers it through
  /// the share sheet. When sharing is unavailable the saved path is still
  /// returned.
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    Rect? origin,
  });

  /// Shares a PDF document.
  Future<ShareOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  });

  /// Opens the platform print dialog for the PDF produced by [build].
  /// Returns false when printing was cancelled or is unavailable.
  Future<bool> printPdf({
    required Future<Uint8List> Function() build,
    required String name,
  });
}

/// Production [ShareGateway] over share_plus, printing and the clipboard.
class DefaultShareGateway implements ShareGateway {
  /// Creates the gateway; exported files go to [exportsDir].
  DefaultShareGateway({required this.exportsDir});

  /// Resolves the exports directory.
  final Future<String> Function() exportsDir;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
      );
      return const ShareOutcome(shared: true);
    } catch (_) {
      // No share target (e.g. old Windows without a mail client): fall back
      // to the clipboard so the user still gets the text.
      await copyText(text);
      return const ShareOutcome(shared: false);
    }
  }

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    final dir = await exportsDir();
    final path = p.join(dir, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: mimeType, name: fileName)],
          subject: subject,
          sharePositionOrigin: origin,
        ),
      );
      return ShareOutcome(shared: true, savedPath: _isMobile ? null : path);
    } catch (_) {
      return ShareOutcome(shared: false, savedPath: path);
    }
  }

  @override
  Future<ShareOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  }) async {
    if (_isMobile) {
      try {
        final ok = await Printing.sharePdf(
          bytes: bytes,
          filename: fileName,
          bounds: origin,
        );
        if (ok) return const ShareOutcome(shared: true);
      } catch (_) {
        // Fall through to the generic file share.
      }
    }
    return shareFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
      origin: origin,
    );
  }

  @override
  Future<bool> printPdf({
    required Future<Uint8List> Function() build,
    required String name,
  }) async {
    try {
      return await Printing.layoutPdf(onLayout: (_) => build(), name: name);
    } catch (_) {
      return false;
    }
  }
}

/// The share gateway (overridden in widget tests).
final shareGatewayProvider = Provider<ShareGateway>((ref) {
  final paths = ref.watch(appPathsProvider);
  return DefaultShareGateway(exportsDir: paths.exportsDir);
});
