// Insato (إنصاتو) entry point: bindings, Arabic date formatting, the
// foreground-task communication port, font licences, the single database
// connection, crash recovery of interrupted meetings, and the provider scope.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/time_format.dart';
import 'data/database.dart';
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
  final db = AppDatabase();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
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
