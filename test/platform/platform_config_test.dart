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

/// Returns the text of the workflow step named [name] (from its `- name:`
/// line up to the next step or job), or null.
String? _workflowStep(String workflow, String name) {
  final lines = workflow.split('\n');
  final start = lines.indexWhere(
    (l) => RegExp('^(\\s*)- name: ${RegExp.escape(name)}\\s*\$').hasMatch(l),
  );
  if (start < 0) return null;
  final indent = lines[start].indexOf('-');
  final out = <String>[lines[start]];
  for (final line in lines.skip(start + 1)) {
    final trimmed = line.trimLeft();
    final lineIndent = line.length - trimmed.length;
    if (trimmed.isNotEmpty && lineIndent <= indent) break;
    out.add(line);
  }
  return out.join('\n');
}

/// Returns the dedented body of the `run: |` block of a workflow [step].
String? _runScript(String step) {
  final lines = step.split('\n');
  final start = lines.indexWhere((l) => RegExp(r'^\s*run: \|\s*$').hasMatch(l));
  if (start < 0) return null;
  final keyIndent = lines[start].indexOf('run:');
  final body = <String>[];
  for (final line in lines.skip(start + 1)) {
    final trimmed = line.trimLeft();
    if (trimmed.isNotEmpty && line.length - trimmed.length <= keyIndent) break;
    body.add(line);
  }
  final indent = body
      .where((l) => l.trim().isNotEmpty)
      .map((l) => l.length - l.trimLeft().length)
      .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
  return body
      .map(
        (l) => l.length >= (indent ?? 0) ? l.substring(indent ?? 0) : l.trim(),
      )
      .join('\n');
}

ProcessResult _git(Directory dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir.path);
  expect(result.exitCode, 0, reason: 'git ${args.join(' ')}: ${result.stderr}');
  return result;
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

    test('release signing values can come verbatim from the environment', () {
      // Secrets written into key.properties are mangled by Properties.load
      // (backslash escapes, line continuations, leading whitespace,
      // ISO-8859-1), so CI passes them as environment variables instead.
      final gradle = _read('android/app/build.gradle.kts');
      for (final env in const [
        'ANDROID_KEYSTORE_PATH',
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_ALIAS',
        'ANDROID_KEY_PASSWORD',
      ]) {
        expect(gradle, contains('"$env"'), reason: '$env is not read');
      }
      expect(gradle, contains('providers.environmentVariable('));
      // Env takes precedence over key.properties.
      final helper = RegExp(
        r'fun releaseProperty\([^)]*\)[^=]*=\s*([\s\S]*?)\n\n',
      ).firstMatch(gradle)?.group(1);
      expect(helper, isNotNull);
      expect(
        helper!.indexOf('releaseEnv(name)'),
        lessThan(helper.indexOf('keystoreProperties.getProperty(name)')),
      );
      expect(
        RegExp(r'hasReleaseKeystore\s*=.*releaseEnv\("storeFile"\)')
            .hasMatch(gradle),
        isTrue,
        reason: 'an env-provided keystore must enable release signing',
      );
      // Local key.properties files are decoded as UTF-8, not ISO-8859-1.
      expect(gradle, contains('reader(Charsets.UTF_8)'));
      expect(gradle, isNot(contains('inputStream().use { keystoreProperties')));
    });
  });

  group('GitHub workflows', () {
    test('release workflow never writes signing secrets to key.properties', () {
      final build = _read('.github/workflows/build.yml');
      final signing = _workflowStep(
        build,
        'Configure release signing (optional)',
      );
      expect(signing, isNotNull);
      for (final key in const ['storePassword=', 'keyPassword=', 'keyAlias=']) {
        expect(build, isNot(contains(key)), reason: '$key written to a file');
      }
      expect(signing, isNot(contains('key.properties')));
      // The step may test whether a password secret is set (a boolean), but
      // never receives its value.
      for (final secret in const [
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_PASSWORD',
      ]) {
        expect(
          signing,
          isNot(matches(RegExp(r'secrets\.' + secret + r'\s*}}'))),
          reason: '$secret value passed to the signing step',
        );
        for (final m in RegExp(
          r'secrets\.' + secret + r'\b([^}]*)}}',
        ).allMatches(signing!)) {
          expect(m[1]!.trim(), "!= ''", reason: '$secret used as a value');
        }
      }
      expect(signing, contains('ANDROID_KEYSTORE_PATH='));
      expect(signing, contains(r'>> "$GITHUB_ENV"'));
      for (final stepName in const ['Build split APKs', 'Build app bundle']) {
        final step = _workflowStep(build, stepName);
        expect(step, isNotNull, reason: stepName);
        for (final secret in const [
          'ANDROID_KEYSTORE_PASSWORD',
          'ANDROID_KEY_ALIAS',
          'ANDROID_KEY_PASSWORD',
        ]) {
          expect(
            step,
            contains('$secret: \${{ secrets.$secret }}'),
            reason: '$stepName must pass $secret',
          );
        }
      }
      // Passwords must never be exported job-wide via GITHUB_ENV.
      expect(
        RegExp(r'(PASSWORD|ALIAS)[^\n]*>>\s*"\$GITHUB_ENV"').hasMatch(build),
        isFalse,
      );
    });

    group('stale-codegen check', () {
      late String script;
      late Directory repo;

      setUpAll(() {
        final ci = _read('.github/workflows/ci.yml');
        final step = _workflowStep(ci, 'Check generated code is up to date');
        expect(step, isNotNull);
        final run = _runScript(step!);
        expect(run, isNotNull);
        expect(run, contains('dart run build_runner build'));
        script = run!;
      });

      setUp(() {
        repo = Directory.systemTemp.createTempSync('codegen_check_');
        _git(repo, ['init', '-q']);
        _git(repo, ['config', 'user.email', 'ci@example.invalid']);
        _git(repo, ['config', 'user.name', 'ci']);
        Directory('${repo.path}/lib/data').createSync(recursive: true);
        File('${repo.path}/lib/data/database.g.dart')
            .writeAsStringSync('// generated v1\n');
        _git(repo, ['add', '.']);
        _git(repo, ['commit', '-q', '-m', 'init']);
      });

      tearDown(() => repo.deleteSync(recursive: true));

      /// Runs the CI step with build_runner replaced by [codegen].
      int runCheck(String codegen) {
        final patched = script.replaceAll(
          RegExp(r'^dart run build_runner build.*$', multiLine: true),
          codegen,
        );
        final result = Process.runSync('bash', [
          '-c',
          patched,
        ], workingDirectory: repo.path);
        return result.exitCode;
      }

      test('passes when generated files are committed and current', () {
        expect(runCheck('true'), 0);
      });

      test('fails when a tracked generated file is stale', () {
        expect(
          runCheck("echo '// generated v2' > lib/data/database.g.dart"),
          isNot(0),
        );
      });

      test('fails when a new generated file was never committed', () {
        expect(runCheck("echo '// new' > lib/data/foo.g.dart"), isNot(0));
      });

      test('ignores unrelated untracked files', () {
        expect(runCheck('echo x > lib/data/notes.txt'), 0);
      });
    }, skip: Platform.isWindows ? 'needs bash and git' : false);
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

    test('targets iOS 16.4 or later (llamadart floor) in every build configuration', () {
      final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(pbxproj)
          .map((m) => double.parse(m.group(1)!))
          .toList();
      expect(targets, isNotEmpty);
      for (final target in targets) {
        expect(target, greaterThanOrEqualTo(16.4));
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

    test('version resource names the private data folders Insato\\Insato', () {
      // path_provider_windows builds %LOCALAPPDATA%\<CompanyName>\
      // <ProductName> (meetings, database) and the %APPDATA% equivalent
      // from these values; an empty or changed name would move the data.
      final rc = _read('windows/runner/Runner.rc');
      String? value(String key) =>
          RegExp('VALUE "$key", "([^"]*)"').firstMatch(rc)?.group(1);
      expect(value('CompanyName'), 'Insato');
      expect(value('ProductName'), 'Insato');
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
