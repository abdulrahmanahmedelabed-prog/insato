// Native configuration of the recording import (not Dart, so nothing else
// would notice a lost intent filter, document type or build entry): the
// Android share / open-with intent filters and channels, the iOS document
// types and AVAssetReader decoder, and the Windows Media Foundation decoder
// (built, linked, registered, ASCII source).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file.readAsStringSync();
}

/// The `<intent-filter>` blocks of the manifest.
List<String> _intentFilters(String manifest) => [
  for (final m in RegExp(
    r'<intent-filter>([\s\S]*?)</intent-filter>',
  ).allMatches(manifest))
    m.group(1)!,
];

const String _decoderChannel = 'insato/audio_decoder';
const String _sharedChannel = 'insato/shared_audio';

void main() {
  group('Android', () {
    const kotlin = 'android/app/src/main/kotlin/app/insato/insato';

    test('share / open-with intent filters accept audio files', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final filters = _intentFilters(manifest);
      bool has(String action, String mime) => filters.any(
        (f) =>
            f.contains('android:name="android.intent.action.$action"') &&
            f.contains('android.intent.category.DEFAULT') &&
            f.contains('android:mimeType="$mime"'),
      );
      expect(has('SEND', 'audio/*'), isTrue);
      expect(has('SEND', 'video/3gpp'), isTrue, reason: '3GP call recordings');
      expect(has('SEND_MULTIPLE', 'audio/*'), isTrue);
      expect(has('VIEW', 'audio/*'), isTrue);
      // Still the launcher activity, single top (onNewIntent for shares
      // while the app runs).
      expect(manifest, contains('android.intent.category.LAUNCHER'));
      expect(manifest, contains('android:launchMode="singleTop"'));
    });

    test('MainActivity registers the decoder and the share inbox', () {
      final activity = _read('$kotlin/MainActivity.kt');
      expect(activity, contains('AudioDecoderChannel(messenger)'));
      expect(activity, contains('SharedAudioChannel(this, messenger)'));
      expect(activity, contains('override fun onNewIntent'));
      expect(activity, contains('shared.handle(intent)'));
      expect(activity, contains('"insato/battery"'), reason: 'kept');

      final decoder = _read('$kotlin/AudioDecoderChannel.kt');
      expect(decoder, contains('"$_decoderChannel"'));
      for (final api in const [
        'MediaExtractor',
        'MediaCodec.createDecoderByType',
        'INFO_OUTPUT_FORMAT_CHANGED',
        'KEY_PCM_ENCODING',
        'METADATA_KEY_DATE',
      ]) {
        expect(decoder, contains(api), reason: api);
      }
      for (final method in const ['"isSupported"', '"open"', '"read"', '"close"']) {
        expect(decoder, contains(method));
      }

      final shared = _read('$kotlin/SharedAudioChannel.kt');
      expect(shared, contains('"$_sharedChannel"'));
      expect(shared, contains('"takePending"'));
      expect(shared, contains('"onShared"'));
      expect(shared, contains('Intent.EXTRA_STREAM'));
      expect(shared, contains('OpenableColumns.DISPLAY_NAME'));
    });
  });

  group('iOS', () {
    test('audio document types ("Open in" / share sheet)', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(plist, contains('<key>CFBundleDocumentTypes</key>'));
      for (final uti in const [
        'public.audio',
        'public.mpeg-4-audio',
        'com.apple.m4a-audio',
        'public.mp3',
        'com.microsoft.waveform-audio',
        'com.apple.coreaudio-format',
        'org.3gpp.adaptive-multi-rate-audio',
        'public.3gpp',
      ]) {
        expect(plist, contains('<string>$uti</string>'), reason: uti);
      }
      expect(
        RegExp(
          r'<key>LSSupportsOpeningDocumentsInPlace</key>\s*<false/>',
        ).hasMatch(plist),
        isTrue,
        reason: 'files are copied into the app (Inbox), never edited in place',
      );
      expect(plist, contains('<string>Alternate</string>'));
    });

    test('AppDelegate registers the AVAssetReader decoder and the inbox', () {
      final delegate = _read('ios/Runner/AppDelegate.swift');
      expect(delegate, contains('import AVFoundation'));
      expect(delegate, contains('registerAudioImportChannels('));
      expect(delegate, contains('"$_decoderChannel"'));
      expect(delegate, contains('"$_sharedChannel"'));
      expect(delegate, contains('AVAssetReader('));
      expect(delegate, contains('kAudioFormatLinearPCM'));
      expect(delegate, contains('registrar.addSceneDelegate(inbox)'));
      expect(delegate, contains('openURLContexts'));
      expect(delegate, contains('startAccessingSecurityScopedResource'));
      expect(delegate, contains('registerBatteryChannel('), reason: 'kept');
    });
  });

  group('Windows', () {
    test('Media Foundation decoder is built, linked and registered', () {
      final cmake = _read('windows/runner/CMakeLists.txt');
      expect(cmake, contains('"audio_decoder_channel.cpp"'));
      for (final lib in const ['mfplat.lib', 'mfreadwrite.lib', 'mfuuid.lib']) {
        expect(cmake, contains('"$lib"'), reason: lib);
      }
      final window = _read('windows/runner/flutter_window.cpp');
      expect(window, contains('std::make_unique<AudioDecoderChannel>('));
      expect(window, contains('audio_decoder_ = nullptr;'));
      final header = _read('windows/runner/flutter_window.h');
      expect(header, contains('#include "audio_decoder_channel.h"'));

      final source = _read('windows/runner/audio_decoder_channel.cpp');
      expect(source, contains('"$_decoderChannel"'));
      for (final api in const [
        'MFStartup',
        'MFCreateSourceReaderFromURL',
        'MFAudioFormat_PCM',
        'MF_PD_DURATION',
        'MF_SOURCE_READERF_ENDOFSTREAM',
        'MFShutdown',
      ]) {
        expect(source, contains(api), reason: api);
      }
    });

    test('decoder sources are ASCII (MSVC /WX without /utf-8)', () {
      for (final path in const [
        'windows/runner/audio_decoder_channel.cpp',
        'windows/runner/audio_decoder_channel.h',
      ]) {
        final bytes = File(path).readAsBytesSync();
        final bad = bytes.indexWhere((b) => b > 0x7F);
        expect(bad, -1, reason: '$path has a non-ASCII byte at $bad');
      }
    });
  });

  test('Dart uses the same channel names', () {
    expect(
      _read('lib/features/import_audio/audio_decoder.dart'),
      contains("MethodChannel('$_decoderChannel')"),
    );
    expect(
      _read('lib/features/import_audio/shared_audio_inbox.dart'),
      contains("MethodChannel('$_sharedChannel')"),
    );
  });
}
