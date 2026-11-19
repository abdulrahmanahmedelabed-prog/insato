// Platform sharing / printing / clipboard behind one seam, so screens stay
// testable without the share_plus and printing plugins.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  /// Offers [bytes] as [fileName] through the share sheet. On desktop a copy
  /// is saved in the exports folder and its path returned (also when sharing
  /// is unavailable); on mobile the file is temporary and removed after the
  /// share.
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
///
/// Where exported files go:
/// * desktop: [exportsDir], and the user is told the saved path (a copy the
///   user chose to keep);
/// * Android / iOS: a short-lived file in [shareTempDir], deleted as soon as
///   the share sheet returns (share_plus copies the file into its own cache
///   on Android; on iOS the call completes when the sheet is dismissed).
///   Nothing stays behind after the meeting is deleted.
class DefaultShareGateway implements ShareGateway {
  /// Creates the gateway. [shareTempDir] defaults to `<temporary>/share`,
  /// [isMobile] to the current platform and [share] to share_plus.
  DefaultShareGateway({
    required this.exportsDir,
    Future<String> Function()? shareTempDir,
    bool? isMobile,
    Future<void> Function(ShareParams params)? share,
  }) : _shareTempDir = shareTempDir ?? _defaultShareTempDir,
       _isMobile = isMobile ?? (Platform.isAndroid || Platform.isIOS),
       _share = share ?? _sharePlus;

  /// Resolves the exports directory (desktop copies).
  final Future<String> Function() exportsDir;

  final Future<String> Function() _shareTempDir;
  final bool _isMobile;
  final Future<void> Function(ShareParams params) _share;
  Future<void>? _purge;

  static Future<void> _sharePlus(ShareParams params) async {
    await SharePlus.instance.share(params);
  }

  static Future<String> _defaultShareTempDir() async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'share'),
    );
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Best-effort removal of share files left behind (an interrupted share,
  /// or `<data root>/exports` copies written by older builds on mobile).
  /// Desktop exports are user-visible saved copies and are kept.
  /// Runs once; [shareFile] waits for it, so it never races a new file.
  Future<void> purgeStale() => _purge ??= _purgeStale();

  Future<void> _purgeStale() async {
    if (!_isMobile) return;
    for (final dir in [_shareTempDir, exportsDir]) {
      try {
        await for (final e in Directory(await dir()).list()) {
          if (e is File) {
            try {
              await e.delete();
            } catch (_) {
              // Best effort.
            }
          }
        }
      } catch (_) {
        // Best effort.
      }
    }
  }

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
      await _share(
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
    await purgeStale();
    final dir = _isMobile ? await _shareTempDir() : await exportsDir();
    final path = p.join(dir, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    try {
      await _share(
        ShareParams(
          files: [XFile(path, mimeType: mimeType, name: fileName)],
          subject: subject,
          sharePositionOrigin: origin,
        ),
      );
      return ShareOutcome(shared: true, savedPath: _isMobile ? null : path);
    } catch (_) {
      // A hidden app-private path means nothing to a mobile user.
      return ShareOutcome(shared: false, savedPath: _isMobile ? null : path);
    } finally {
      if (_isMobile) {
        try {
          await File(path).delete();
        } catch (_) {
          // Best effort; purged on the next share.
        }
      }
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
  final gateway = DefaultShareGateway(exportsDir: paths.exportsDir);
  // Clear share files an earlier run left behind.
  unawaited(gateway.purgeStale());
  return gateway;
});
