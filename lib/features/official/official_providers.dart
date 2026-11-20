// Riverpod wiring of the official-minutes screens (v1.2).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/providers.dart';
import 'official_service.dart';

/// The official bundle of a meeting (record, profile, template, document),
/// rebuilt whenever the meeting, its record, signatures, the entity profile
/// or the uploaded templates change. Null while the meeting has no minutes.
final officialBundleProvider = FutureProvider.autoDispose
    .family<OfficialBundle?, String>((ref, meetingId) async {
      ref
        ..watch(meetingProvider(meetingId))
        ..watch(officialRecordProvider(meetingId))
        ..watch(minutesSignaturesProvider(meetingId))
        ..watch(entityProfileProvider)
        ..watch(customTemplatesProvider);
      return ref.read(officialMinutesServiceProvider).bundle(meetingId);
    });
