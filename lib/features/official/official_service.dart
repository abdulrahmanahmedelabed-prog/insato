// Orchestrates official minutes (v1.2): creates a meeting's official record
// (number, header defaults, attendance pre-fill), the secretary's vote
// review, the draft → reviewed → approved lifecycle with the content hash,
// new versions after approval, signatures, and the files of the entity
// (logo, uploaded Word templates).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models.dart';
import '../../data/official_repository.dart';
import '../../data/repositories.dart';
import '../../minutes/minutes_prompt.dart' show speakerStats;
import '../../session/providers.dart'
    show
        appPathsProvider,
        meetingRepositoryProvider,
        segmentRepositoryProvider,
        speakerRepositoryProvider;
import 'docx_template.dart';
import 'official_document.dart';
import 'official_logic.dart';
import 'official_models.dart';
import 'official_templates.dart';
import 'signature_raster.dart' show imageSize;
import 'template_placeholders.dart';

/// Largest accepted logo file.
const int kMaxLogoBytes = 4 * 1024 * 1024;

/// A user-facing failure of an official-minutes action.
class OfficialActionException implements Exception {
  /// Creates the exception.
  const OfficialActionException(this.messageAr);

  /// Arabic message.
  final String messageAr;

  @override
  String toString() => 'OfficialActionException: $messageAr';
}

/// Everything an export / screen needs about a meeting's official minutes.
class OfficialBundle {
  /// Creates a bundle.
  const OfficialBundle({
    required this.choice,
    required this.record,
    required this.profile,
    required this.document,
    required this.signatures,
  });

  /// Template.
  final TemplateChoice choice;

  /// Record.
  final OfficialRecord record;

  /// Entity profile.
  final EntityProfile profile;

  /// Render-ready document.
  final OfficialDocument document;

  /// Signatures of the current version.
  final List<MinutesSignature> signatures;
}

/// The official-minutes service.
class OfficialMinutesService {
  /// Creates the service.
  OfficialMinutesService({
    required OfficialMinutesRepository repository,
    required this._settings,
    required this._meetings,
    required this._segments,
    required this._speakers,
    required this._brandingDir,
    required this._templatesDir,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now;

  final OfficialMinutesRepository _repo;
  final OfficialSettingsStore _settings;
  final MeetingRepository _meetings;
  final SegmentRepository _segments;
  final SpeakerRepository _speakers;
  final Future<String> Function() _brandingDir;
  final Future<String> Function() _templatesDir;
  final DateTime Function() _clock;

  /// The repository.
  OfficialMinutesRepository get repository => _repo;

  /// The template chosen for [meeting].
  Future<TemplateChoice> templateOf(Meeting meeting) async =>
      resolveTemplate(meeting.context.template, await _settings.templates());

  /// Speaker names heard in [meetingId], by first appearance.
  Future<List<String>> spokenNames(String meetingId) async {
    final segs = await _segments.getForMeeting(meetingId);
    final speakers = await _speakers.getAllById();
    return [for (final s in speakerStats(segs, speakers)) s.name];
  }

  /// The record of [meeting], created on first use with: the next meeting
  /// number of the entity / first committee / year, the profile's chair,
  /// secretary and place, the recording's start / end time and the
  /// pre-filled attendance.
  Future<OfficialRecord> ensureRecord(Meeting meeting) async {
    final existing = await _repo.get(meeting.id);
    if (existing != null) return existing;
    final profile = await _settings.profile();
    final committee = profile.committees.isEmpty
        ? null
        : profile.committees.first;
    final year = numberYearOf(meeting.createdAt, profile.yearStyle);
    final number = await _repo.nextNumber(
      entityName: profile.entityName,
      committee: committee,
      year: year,
    );
    final record = OfficialRecord(
      meetingId: meeting.id,
      committee: committee,
      meetingNumber: number,
      numberYear: year,
      yearStyle: profile.yearStyle,
      place: profile.defaultPlace,
      startTime: meeting.createdAt,
      endTime: meeting.durationMs > 0
          ? meeting.createdAt.add(Duration(milliseconds: meeting.durationMs))
          : null,
      chair: profile.chairName,
      secretary: profile.secretaryName,
      attendance: prefillAttendance(
        expectedAttendees: meeting.context.expectedAttendees,
        spokenNames: await spokenNames(meeting.id),
      ),
    );
    return _repo.save(record, entityName: profile.entityName);
  }

  /// Saves [record] (draft or reviewed; editing a reviewed record returns it
  /// to draft unless [keepStatus]). Throws [OfficialActionException] when
  /// the minutes are approved.
  Future<OfficialRecord> save(
    OfficialRecord record, {
    bool keepStatus = false,
  }) async {
    final profile = await _settings.profile();
    final next = !keepStatus && record.status == OfficialStatus.reviewed
        ? record.copyWith(status: OfficialStatus.draft)
        : record;
    try {
      return await _repo.save(next, entityName: profile.entityName);
    } on OfficialMinutesLockedException catch (e) {
      throw OfficialActionException(e.messageAr);
    }
  }

  /// Changes the committee and renumbers the meeting in that committee's
  /// sequence.
  Future<OfficialRecord> changeCommittee(
    Meeting meeting,
    OfficialRecord record,
    String? committee,
  ) async {
    final profile = await _settings.profile();
    final year = numberYearOf(meeting.createdAt, record.yearStyle);
    final number = await _repo.nextNumber(
      entityName: profile.entityName,
      committee: committee,
      year: year,
      exceptMeetingId: meeting.id,
    );
    return save(
      record.copyWith(
        committee: committee,
        clearCommittee: committee == null || committee.trim().isEmpty,
        meetingNumber: number,
        numberYear: year,
      ),
    );
  }

  /// Adds newcomers (expected attendees / speakers not yet listed) to the
  /// attendance sheet.
  Future<OfficialRecord> refreshAttendance(
    Meeting meeting,
    OfficialRecord record,
  ) async => save(
    record.copyWith(
      attendance: prefillAttendance(
        expectedAttendees: meeting.context.expectedAttendees,
        spokenNames: await spokenNames(meeting.id),
        existing: record.attendance,
      ),
    ),
  );

  /// Stores the secretary's review of resolution [index].
  Future<OfficialRecord> setVoteReview(
    OfficialRecord record,
    Minutes minutes,
    int index,
    VoteReview review,
  ) => save(
    record.copyWith(voteReviews: {...record.voteReviews, index: review}),
  );

  /// Loads the whole bundle of [meetingId], or null without minutes.
  Future<OfficialBundle?> bundle(String meetingId) async {
    final meeting = await _meetings.get(meetingId);
    final minutes = meeting?.minutes;
    if (meeting == null || minutes == null) return null;
    final record = await ensureRecord(meeting);
    final profile = await _settings.profile();
    final choice = await templateOf(meeting);
    final sigs = await _repo.signatures(meetingId, version: record.version);
    return OfficialBundle(
      choice: choice,
      record: record,
      profile: profile,
      signatures: sigs,
      document: buildOfficialDocument(
        meeting: meeting,
        minutes: minutes,
        record: record,
        profile: profile,
        choice: choice,
        signatures: sigs,
        logo: await logoBytes(profile),
      ),
    );
  }

  /// The document for an export of [meeting], or null when its template is
  /// not official (the v1.1 layout is used then).
  Future<OfficialDocument?> documentForExport(Meeting meeting) async {
    if (meeting.minutes == null) return null;
    final choice = await templateOf(meeting);
    if (!choice.isOfficial) return null;
    return (await bundle(meeting.id))?.document;
  }

  /// Marks the minutes reviewed. Throws when votes with unclear positions
  /// were not confirmed or the quorum data are missing.
  Future<OfficialRecord> markReviewed(String meetingId) async {
    final b = await _require(meetingId);
    final minutes = (await _meetings.get(meetingId))!.minutes!;
    final pending = {
      ...resolutionsNeedingReview(minutes, b.record),
      for (final r in b.document.resolutions)
        if (r.tally.outcome == VoteOutcome.needsReview) r.index,
    };
    if (pending.isNotEmpty) {
      throw OfficialActionException(
        'يجب تأكيد المواقف غير الواضحة في التصويت أولاً '
        '(${pending.length} من القرارات).',
      );
    }
    return save(
      b.record.copyWith(status: OfficialStatus.reviewed),
      keepStatus: true,
    );
  }

  /// Approves the reviewed minutes: computes the canonical hash, locks the
  /// content and stores the version in the history.
  Future<OfficialRecord> approve(String meetingId) async {
    final b = await _require(meetingId);
    if (b.record.status != OfficialStatus.reviewed) {
      throw const OfficialActionException(
        'لا يُعتمد المحضر قبل مراجعته (مسودة ← مراجعة ← اعتماد).',
      );
    }
    final minutes = (await _meetings.get(meetingId))!.minutes!;
    return _repo.approve(
      record: b.record,
      minutes: minutes,
      hash: b.document.contentHash,
      entityName: b.profile.entityName,
    );
  }

  /// Unlocks approved minutes as a new draft version.
  Future<OfficialRecord?> startNewVersion(String meetingId) async =>
      _repo.startNewVersion(
        meetingId,
        entityName: (await _settings.profile()).entityName,
      );

  /// Called after the minutes of [meetingId] were (re)generated: approved
  /// minutes whose content changed become a new draft version, so an
  /// approval never covers content it did not see.
  Future<void> onMinutesChanged(String meetingId) async {
    final record = await _repo.get(meetingId);
    if (record == null || !record.isLocked) return;
    final b = await bundle(meetingId);
    if (b != null && !b.document.hashMatchesApproval) {
      await startNewVersion(meetingId);
    }
  }

  /// Stores a signature of the approved version.
  Future<MinutesSignature> sign({
    required String meetingId,
    required String signerName,
    required String signerRole,
    required List<List<SignaturePoint>> strokes,
    required double aspectRatio,
  }) async {
    final b = await _require(meetingId);
    if (!b.document.isApproved) {
      throw const OfficialActionException('يُوقَّع المحضر بعد اعتماده فقط.');
    }
    if (strokes.every((s) => s.isEmpty)) {
      throw const OfficialActionException('لم يُرسم توقيع.');
    }
    if (signerName.trim().isEmpty) {
      throw const OfficialActionException('اكتب اسم الموقِّع.');
    }
    return _repo.addSignature(
      MinutesSignature(
        meetingId: meetingId,
        version: b.record.version,
        signerName: signerName.trim(),
        signerRole: signerRole.trim(),
        strokes: strokes,
        aspectRatio: aspectRatio,
        signedAt: _clock(),
        contentHash: b.document.contentHash,
      ),
    );
  }

  Future<OfficialBundle> _require(String meetingId) async {
    final b = await bundle(meetingId);
    if (b == null) {
      throw const OfficialActionException('لا يوجد محضر لهذا الاجتماع بعد.');
    }
    return b;
  }

  // -------------------------------------------------------------------------
  // Files: logo and templates
  // -------------------------------------------------------------------------

  /// The logo file content, or null.
  Future<Uint8List?> logoBytes([EntityProfile? profile]) async {
    final name = (profile ?? await _settings.profile()).logoFile;
    if (name == null) return null;
    final f = File(p.join(await _brandingDir(), p.basename(name)));
    try {
      return await f.exists() ? await f.readAsBytes() : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Validates and stores a logo (PNG or JPEG, ≤ 4 MB) and returns the
  /// updated profile. SVG is not accepted (it cannot be embedded in Word
  /// documents without a raster copy).
  Future<EntityProfile> setLogo(Uint8List bytes, String fileName) async {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.svg')) {
      throw const OfficialActionException(
        'صيغة SVG غير مدعومة للشعار. استخدم صورة PNG أو JPG.',
      );
    }
    if (bytes.isEmpty || bytes.length > kMaxLogoBytes) {
      throw const OfficialActionException(
        'حجم صورة الشعار يجب ألا يتجاوز 4 ميغابايت.',
      );
    }
    final image = docxImageOf(bytes);
    if (image == null || imageSize(bytes) == null) {
      throw const OfficialActionException(
        'تعذّرت قراءة الصورة. اختر شعاراً بصيغة PNG أو JPG.',
      );
    }
    final dir = await _brandingDir();
    final name =
        'logo_${_clock().millisecondsSinceEpoch}.${image.extension == 'png' ? 'png' : 'jpg'}';
    await File(p.join(dir, name)).writeAsBytes(bytes, flush: true);
    final profile = await _settings.profile();
    final old = profile.logoFile;
    final next = profile.copyWith(logoFile: name);
    await _settings.saveProfile(next);
    if (old != null && old != name) {
      await _deleteQuietly(File(p.join(dir, p.basename(old))));
    }
    return next;
  }

  /// Removes the logo.
  Future<EntityProfile> clearLogo() async {
    final profile = await _settings.profile();
    final old = profile.logoFile;
    final next = profile.copyWith(clearLogo: true);
    await _settings.saveProfile(next);
    if (old != null) {
      await _deleteQuietly(File(p.join(await _brandingDir(), p.basename(old))));
    }
    return next;
  }

  /// Validates and stores an uploaded Word template. Throws
  /// [DocxTemplateException] / [OfficialActionException] with an Arabic
  /// reason.
  Future<CustomTemplate> uploadTemplate({
    required Uint8List bytes,
    required String fileName,
    required String name,
    required String baseTemplateId,
  }) async {
    if (!fileName.toLowerCase().endsWith('.docx')) {
      throw const OfficialActionException('اختر ملف Word بصيغة .docx.');
    }
    final placeholders = inspectDocxTemplate(
      bytes,
      known: knownPlaceholderNames,
    );
    final id =
        '${_clock().millisecondsSinceEpoch.toRadixString(36)}'
        '${math.Random().nextInt(1 << 20).toRadixString(36)}';
    final file = 'template_$id.docx';
    await File(p.join(await _templatesDir(), file))
        .writeAsBytes(bytes, flush: true);
    final clean = name.trim().isEmpty
        ? p.basenameWithoutExtension(fileName)
        : name.trim();
    final t = CustomTemplate(
      id: id,
      name: clean,
      baseTemplateId: OfficialTemplates.byId(baseTemplateId).id,
      fileName: file,
      placeholders: placeholders,
      uploadedAt: _clock(),
    );
    await _settings.saveTemplates([...await _settings.templates(), t]);
    return t;
  }

  /// Renames / relinks an uploaded template.
  Future<void> updateTemplate(CustomTemplate t) async {
    final list = await _settings.templates();
    await _settings.saveTemplates([for (final e in list) e.id == t.id ? t : e]);
  }

  /// Deletes an uploaded template (meetings using it fall back to the
  /// built-in team template).
  Future<void> deleteTemplate(CustomTemplate t) async {
    final list = await _settings.templates();
    await _settings.saveTemplates([
      for (final e in list)
        if (e.id != t.id) e,
    ]);
    await _deleteQuietly(File(p.join(await _templatesDir(), t.fileName)));
  }

  /// The bytes of an uploaded template, or null when the file is missing.
  Future<Uint8List?> templateBytes(CustomTemplate t) async {
    final f = File(p.join(await _templatesDir(), p.basename(t.fileName)));
    try {
      return await f.exists() ? await f.readAsBytes() : null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Best effort.
    }
  }
}

/// The official-minutes service of the app.
final officialMinutesServiceProvider = Provider<OfficialMinutesService>((ref) {
  final paths = ref.watch(appPathsProvider);
  return OfficialMinutesService(
    repository: ref.watch(officialMinutesRepositoryProvider),
    settings: ref.watch(officialSettingsStoreProvider),
    meetings: ref.watch(meetingRepositoryProvider),
    segments: ref.watch(segmentRepositoryProvider),
    speakers: ref.watch(speakerRepositoryProvider),
    brandingDir: paths.brandingDir,
    templatesDir: paths.templatesDir,
  );
});
