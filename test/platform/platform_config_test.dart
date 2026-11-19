// Regression tests for the native platform configuration.
//
// These files are not Dart, so nothing else would notice if a permission,
// the foreground-service declaration or a privacy setting were lost during
// a template migration or a merge. Each check below guards a requirement
// that would otherwise only fail on a real device (silent recordings,
// crashes when starting the foreground service, permissions compiled out).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file.readAsStringSync();
}

/// Returns the plist value element that follows `<key>[key]</key>`.
String? _plistValue(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*(<(\\w+)\\s*/>|<(\\w+)>([\\s\\S]*?)</\\3>)',
  ).firstMatch(plist);
  return match?.group(1);
}

void main() {
  group('Android manifest', () {
    late String manifest;

    setUpAll(() {
      manifest = _read('android/app/src/main/AndroidManifest.xml');
    });

    test('declares every permission the recorder needs', () {
      const permissions = [
        'RECORD_AUDIO',
        'INTERNET',
        'WAKE_LOCK',
        'FOREGROUND_SERVICE',
        'FOREGROUND_SERVICE_MICROPHONE',
        'POST_NOTIFICATIONS',
      ];
      for (final permission in permissions) {
        expect(
          manifest,
          contains(
            '<uses-permission android:name="android.permission.$permission" />',
          ),
          reason: '$permission is missing',
        );
      }
    });

    test(
      'declares the flutter_foreground_task service as a microphone FGS',
      () {
        final service = RegExp(
          r'<service\s[^>]*android:name="com\.pravera\.flutter_foreground_task\.service\.ForegroundService"[^>]*/>',
        ).firstMatch(manifest)?.group(0);
        expect(service, isNotNull);
        expect(service, contains('android:foregroundServiceType="microphone"'));
        expect(service, contains('android:exported="false"'));
      },
    );

    test('uses the Arabic app label and disables backups', () {
      expect(manifest, contains('android:label="إنصاتو"'));
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(
        File('android/app/src/main/res/xml/data_extraction_rules.xml')
            .existsSync(),
        isTrue,
      );
    });
  });

  group('Android Gradle', () {
    test('pins minSdk to at least 24 and keeps a debug-signing fallback', () {
      final gradle = _read('android/app/build.gradle.kts');
      final minSdk = RegExp(r'minSdk\s*=\s*(\d+)').firstMatch(gradle);
      expect(minSdk, isNotNull, reason: 'minSdk must be set explicitly');
      expect(int.parse(minSdk!.group(1)!), greaterThanOrEqualTo(24));
      expect(gradle, contains('signingConfigs.getByName("debug")'));
      expect(gradle, contains('key.properties'));
    });
  });

  group('iOS Info.plist', () {
    late String plist;

    setUpAll(() {
      plist = _read('ios/Runner/Info.plist');
    });

    test('has a microphone usage description (also enables '
        'permission_handler PERMISSION_MICROPHONE under SwiftPM)', () {
      final value = _plistValue(plist, 'NSMicrophoneUsageDescription');
      expect(value, isNotNull);
      expect(value, contains('الميكروفون'));
    });

    test('allows background audio recording', () {
      final modes = _plistValue(plist, 'UIBackgroundModes');
      expect(modes, contains('<string>audio</string>'));
    });

    test('shows the Arabic display name and declares ar/en localizations', () {
      expect(
        _plistValue(plist, 'CFBundleDisplayName'),
        '<string>إنصاتو</string>',
      );
      final localizations = _plistValue(plist, 'CFBundleLocalizations');
      expect(localizations, contains('<string>ar</string>'));
      expect(localizations, contains('<string>en</string>'));
    });

    test('targets iOS 15.0 or later in every build configuration', () {
      final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(pbxproj)
          .map((m) => double.parse(m.group(1)!))
          .toList();
      expect(targets, isNotEmpty);
      for (final target in targets) {
        expect(target, greaterThanOrEqualTo(15.0));
      }
    });
  });

  group('Windows runner', () {
    test('window title is the Arabic name encoded as UTF-16 escapes', () {
      final main = _read('windows/runner/main.cpp');
      final literal = RegExp(r'kWindowTitle\[\]\s*=\s*([\s\S]*?);')
          .firstMatch(main)
          ?.group(1);
      expect(literal, isNotNull);
      final decoded = RegExp(r'L"([^"]*)"')
          .allMatches(literal!)
          .map((m) => m.group(1)!)
          .join()
          .replaceAllMapped(
            RegExp(r'\\u([0-9A-Fa-f]{4})'),
            (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
          );
      expect(decoded, 'إنصاتو — محاضر الاجتماعات');
      expect(main, contains('Win32Window::Size size(1280, 800)'));
      // The source must stay ASCII: MSVC builds with /WX and no /utf-8.
      expect(main.codeUnits.every((c) => c < 0x80), isTrue);
    });
  });

  group('Bundled font licence', () {
    test('OFL.txt carries both Noto copyright lines and the OFL 1.1 text', () {
      final ofl = _read('assets/fonts/OFL.txt');
      expect(
        ofl,
        contains(
          'Copyright 2022 The Noto Project Authors '
          '(https://github.com/notofonts/arabic)',
        ),
      );
      expect(
        ofl,
        contains(
          'Copyright 2022 The Noto Project Authors '
          '(https://github.com/notofonts/latin-greek-cyrillic)',
        ),
      );
      expect(ofl, contains('SIL OPEN FONT LICENSE Version 1.1'));
    });
  });
}
