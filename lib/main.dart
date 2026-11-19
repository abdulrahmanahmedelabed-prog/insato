// Insato (إنصاتو) entry point: bindings, Arabic date formatting, the
// foreground-task communication port, font licences, the single database
// connection, crash recovery of interrupted meetings, and the provider scope.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/time_format.dart';
import 'data/database.dart';
import 'data/repositories.dart';
import 'session/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  ensureArabicDateFormatting();
  // Required by flutter_foreground_task 11 before any service interaction
  // (pure Dart: a named isolate port, harmless on platforms without the
  // foreground service).
  FlutterForegroundTask.initCommunicationPort();
  LicenseRegistry.addLicense(bundledFontLicenses);

  // One database connection for the whole app.
  final paths = AppPaths();
  final db = await openAppDatabase(paths);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWithValue(paths),
      recordingsDirProvider.overrideWithValue(paths.recordingsDir),
    ],
  );
  // In the foreground (device unlocked): rewrites API keys stored with the
  // old iOS keychain accessibility once. Never throws; a marker makes it a
  // no-op afterwards. Awaited so no key read races the rewrite.
  await container.read(secureSettingsProvider).migrateAccessibility();
  unawaited(recoverInterruptedMeetings(container));

  runApp(
    UncontrolledProviderScope(container: container, child: const InsatoApp()),
  );
}

/// Licences of the bundled Noto fonts (SIL OFL 1.1), shown on the licence
/// page.
Stream<LicenseEntry> bundledFontLicenses() async* {
  final text = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['NotoNaskhArabic', 'NotoSans'], text);
}

/// Opens the app database.
///
/// Android / iOS: `insato.sqlite` in the private app documents directory
/// ([AppDatabase.new]). Windows: the private local app-data directory
/// ([AppPaths.databaseDir]) instead of the user's Documents folder (shared
/// with other apps, often synced to OneDrive); data v1 left in Documents is
/// moved there first. If that move failed, the old location is used so no
/// data ever appears lost.
Future<AppDatabase> openAppDatabase(AppPaths paths) async {
  if (!Platform.isWindows) return AppDatabase();
  var dir = await paths.databaseDir();
  try {
    await paths.migrateLegacyWindowsData();
    final name = '${AppPaths.databaseName}.sqlite';
    final legacyDir = await paths.legacyDatabaseDir();
    if (!File('$dir${Platform.pathSeparator}$name').existsSync() &&
        File('$legacyDir${Platform.pathSeparator}$name').existsSync()) {
      dir = legacyDir;
    }
  } catch (e, st) {
    debugPrint('Insato: database migration failed: $e\n$st');
  }
  return AppDatabase.inDirectory(() async => dir);
}

/// Finalises meetings left `recording` / `processing` by a crash or a killed
/// app (repairs the WAV header, keeps the transcript, marks the meeting).
/// Never throws: recovery problems must not prevent the app from starting.
Future<void> recoverInterruptedMeetings(ProviderContainer container) async {
  try {
    await container.read(postProcessorProvider).recoverInterruptedMeetings();
  } catch (e, st) {
    debugPrint('Insato: meeting recovery failed: $e\n$st');
  }
}
