// Audio files handed to Insato by the operating system: Android "share" /
// "open with" (ACTION_SEND / ACTION_SEND_MULTIPLE / ACTION_VIEW with
// audio/*, see AndroidManifest.xml and SharedAudioChannel.kt) and iOS
// "Open in" / share sheet (CFBundleDocumentTypes in Info.plist, handled in
// AppDelegate.swift). The platform copies each file into the app's cache
// (content:// URIs and Inbox files are not readable paths for Dart) and
// queues it; Dart pulls the queue through the MethodChannel
// `insato/shared_audio`:
//
//   takePending → [{path: String?, name: String, error: String?}]
//   (platform → Dart) onShared → null: new files were queued.
//
// Windows has no share target; the meetings screen's picker is used there.
//
// Why not receive_sharing_intent: on iOS it needs a Share Extension target
// with an App Group (new Xcode target, entitlements and signing that cannot
// be created or verified without Xcode), while plain "Open in" document
// types reach the app without an extension; on Android the few lines of
// intent handling avoid a dependency whose cached-file handling we would
// still have to wrap.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One file received from another app.
class SharedAudioFile {
  /// Creates the entry.
  const SharedAudioFile({required this.name, this.path, this.error});

  /// Readable copy in the app's cache (null on [error]).
  final String? path;

  /// Original file name.
  final String name;

  /// Platform error code (`too_large`, `copy_failed`), null when fine.
  final String? error;

  /// Parses one platform entry; null when malformed.
  static SharedAudioFile? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final path = raw['path'];
    final error = raw['error'];
    if (path is! String? || error is! String?) return null;
    if (path == null && error == null) return null;
    return SharedAudioFile(
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : (path?.split(RegExp(r'[\\/]')).last ?? ''),
      path: path,
      error: error,
    );
  }
}

/// Source of files shared to the app.
abstract interface class SharedAudioInbox {
  /// Files received since the last call (removed from the queue).
  Future<List<SharedAudioFile>> takePending();

  /// Fires when new files were queued.
  Stream<void> get arrivals;
}

/// [SharedAudioInbox] over the MethodChannel `insato/shared_audio`.
class MethodChannelSharedAudioInbox implements SharedAudioInbox {
  /// Creates the inbox and starts listening for arrivals.
  MethodChannelSharedAudioInbox({
    this.channel = const MethodChannel('insato/shared_audio'),
  }) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onShared') _arrivals.add(null);
      return null;
    });
  }

  /// The channel.
  final MethodChannel channel;

  final StreamController<void> _arrivals = StreamController<void>.broadcast();

  @override
  Stream<void> get arrivals => _arrivals.stream;

  @override
  Future<List<SharedAudioFile>> takePending() async {
    try {
      final raw = await channel.invokeListMethod<Object?>('takePending');
      return [
        for (final e in raw ?? const <Object?>[])
          ?SharedAudioFile.fromPlatform(e),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Stops listening.
  void dispose() {
    channel.setMethodCallHandler(null);
    _arrivals.close();
  }
}

/// The share inbox of this platform (null where the OS cannot share files
/// to the app). Overridden in tests.
final sharedAudioInboxProvider = Provider<SharedAudioInbox?>((ref) {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  final inbox = MethodChannelSharedAudioInbox();
  ref.onDispose(inbox.dispose);
  return inbox;
});
