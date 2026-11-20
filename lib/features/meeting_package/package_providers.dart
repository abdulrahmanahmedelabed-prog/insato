// Riverpod wiring of «حزمة الاجتماع»: the service, the file seams (pick /
// save / share, overridden in widget tests), the undo state of a meeting
// and the packages other apps hand to Insato (Android "open with" / share,
// iOS "Open in Insato").

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/meeting_package_store.dart';
import '../../session/providers.dart';
import '../../ui/screens/settings_screen.dart' show kAppVersion;
import '../../ui/services/share_gateway.dart';
import '../multi_device/multi_device_providers.dart'
    show currentPlatformId, defaultDeviceName;
import 'package_format.dart';
import 'package_service.dart';

/// The package service.
final meetingPackageServiceProvider = Provider<MeetingPackageService>((ref) {
  final paths = ref.watch(appPathsProvider);
  return MeetingPackageService(
    db: ref.watch(databaseProvider),
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
    settings: ref.watch(appSettingsProvider),
    recordingsDir: paths.recordingsDir,
    resolveRecording: paths.resolveRecording,
    refine: (id) => ref.read(postProcessorProvider).refine(id),
    isMeetingActive: (id) {
      final s = ref.read(meetingSessionControllerProvider);
      return s.isActive && s.meetingId == id;
    },
    device: PackageDevice(
      name: defaultDeviceName(),
      platform: currentPlatformId(),
    ),
    appVersion: kAppVersion,
  );
});

/// The latest merge of a meeting that can be undone (null: none).
final latestPackageMergeProvider = StreamProvider.autoDispose
    .family<MergeSnapshot?, String>(
      (ref, meetingId) =>
          ref.watch(meetingPackageServiceProvider).store.watchLatest(meetingId),
    );

/// A package file chosen by the user or handed over by another app.
class PickedPackageFile {
  /// Creates the file.
  const PickedPackageFile(this.name, this.bytes);

  /// File name.
  final String name;

  /// Content.
  final Uint8List bytes;
}

/// What happened to an exported package.
class PackageSaveResult {
  /// Creates the result.
  const PackageSaveResult({required this.done, this.savedPath});

  /// Shared or saved (false: cancelled / unavailable).
  final bool done;

  /// Where the file was saved (desktop).
  final String? savedPath;
}

/// Picking and saving / sharing package files.
abstract class PackageFiles {
  /// Lets the user choose a `.insato` file.
  Future<PickedPackageFile?> pick();

  /// Saves (desktop: a save dialog) or shares (mobile: the share sheet —
  /// Nearby Share, Bluetooth, AirDrop, Files, e-mail …) [bytes].
  Future<PackageSaveResult> save({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  });
}

/// Production [PackageFiles] over file_selector and the share gateway.
class DefaultPackageFiles implements PackageFiles {
  /// Creates the seam.
  DefaultPackageFiles(this._share);

  final ShareGateway _share;

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static fs.XTypeGroup get _group {
    if (!kIsWeb && Platform.isAndroid) {
      // Files received over Bluetooth / Nearby Share often lose their type:
      // accept any file and check its content.
      return const fs.XTypeGroup(label: 'Insato');
    }
    return const fs.XTypeGroup(
      label: 'حزمة اجتماع إنصاتو',
      extensions: [kPackageExtension],
      mimeTypes: [
        kPackageMimeType,
        'application/zip',
        'application/octet-stream',
      ],
      uniformTypeIdentifiers: [
        'app.insato.meeting-package',
        'public.zip-archive',
        'public.data',
      ],
    );
  }

  @override
  Future<PickedPackageFile?> pick() async {
    final f = await fs.openFile(acceptedTypeGroups: [_group]);
    if (f == null) return null;
    return PickedPackageFile(f.name, await f.readAsBytes());
  }

  @override
  Future<PackageSaveResult> save({
    required Uint8List bytes,
    required String fileName,
    Rect? origin,
  }) async {
    if (_mobile) {
      final r = await _share.shareFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/octet-stream',
        origin: origin,
      );
      return PackageSaveResult(done: r.shared, savedPath: r.savedPath);
    }
    try {
      final loc = await fs.getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const fs.XTypeGroup(
            label: 'حزمة اجتماع إنصاتو',
            extensions: [kPackageExtension],
          ),
        ],
      );
      if (loc == null) return const PackageSaveResult(done: false);
      var path = loc.path;
      if (p.extension(path).toLowerCase() != '.$kPackageExtension') {
        path = '$path.$kPackageExtension';
      }
      await File(path).writeAsBytes(bytes, flush: true);
      return PackageSaveResult(done: true, savedPath: path);
    } on UnimplementedError {
      // No save dialog on this platform: the share gateway keeps a copy.
      final r = await _share.shareFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/octet-stream',
        origin: origin,
      );
      return PackageSaveResult(
        done: r.shared || r.savedPath != null,
        savedPath: r.savedPath,
      );
    }
  }
}

/// The package file seam.
final packageFilesProvider = Provider<PackageFiles>(
  (ref) => DefaultPackageFiles(ref.watch(shareGatewayProvider)),
);

/// Package files handed to Insato by the system (paths of local copies the
/// app may delete after reading).
abstract class IncomingPackages {
  /// Files opened while the app runs, and the one it was launched with.
  Stream<String> get files;

  /// Checks for files that arrived while the app was in the background.
  Future<void> poll();
}

/// No incoming files (tests, unsupported platforms).
class NoIncomingPackages implements IncomingPackages {
  /// Creates the source.
  const NoIncomingPackages();

  @override
  Stream<String> get files => const Stream.empty();

  @override
  Future<void> poll() async {}
}

/// Android: `insato/open_file` (MainActivity copies the shared / opened
/// content into the app cache and reports its path). iOS: "Open in
/// إنصاتو" copies the file into `Documents/Inbox`, which is checked at
/// start and on resume.
class PlatformIncomingPackages implements IncomingPackages {
  /// Creates the source.
  PlatformIncomingPackages() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'opened' && call.arguments is String) {
          _out.add(call.arguments as String);
        }
        return null;
      });
    }
  }

  static const MethodChannel _channel = MethodChannel('insato/open_file');
  final StreamController<String> _out = StreamController<String>.broadcast();
  final Set<String> _seen = {};

  @override
  Stream<String> get files => _out.stream;

  @override
  Future<void> poll() async {
    try {
      if (Platform.isAndroid) {
        final path = await _channel.invokeMethod<String>('initial');
        if (path != null && _seen.add(path)) _out.add(path);
      } else if (Platform.isIOS) {
        final inbox = Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'Inbox'),
        );
        if (!await inbox.exists()) return;
        await for (final e in inbox.list()) {
          if (e is File &&
              p.extension(e.path).toLowerCase() == '.$kPackageExtension' &&
              _seen.add(e.path)) {
            _out.add(e.path);
          }
        }
      }
    } on MissingPluginException {
      // Older native side: only the file picker works.
    } on PlatformException {
      // Nothing usable was handed over.
    } on FileSystemException {
      // Inbox unreadable.
    }
  }

  /// Closes the stream.
  void dispose() => _out.close();
}

/// Source of incoming package files.
final incomingPackagesProvider = Provider<IncomingPackages>((ref) {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return const NoIncomingPackages();
  }
  final s = PlatformIncomingPackages();
  ref.onDispose(s.dispose);
  return s;
});
