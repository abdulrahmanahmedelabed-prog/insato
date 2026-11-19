// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SpeakersTable extends Speakers
    with TableInfo<$SpeakersTable, SpeakerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNamedByUserMeta = const VerificationMeta(
    'isNamedByUser',
  );
  @override
  late final GeneratedColumn<bool> isNamedByUser = GeneratedColumn<bool>(
    'is_named_by_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_named_by_user" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SpeakersTable.$convertercreatedAt);
  static const VerificationMeta _centroidMeta = const VerificationMeta(
    'centroid',
  );
  @override
  late final GeneratedColumn<Uint8List> centroid = GeneratedColumn<Uint8List>(
    'centroid',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _embeddingCountMeta = const VerificationMeta(
    'embeddingCount',
  );
  @override
  late final GeneratedColumn<int> embeddingCount = GeneratedColumn<int>(
    'embedding_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _profileEnabledMeta = const VerificationMeta(
    'profileEnabled',
  );
  @override
  late final GeneratedColumn<bool> profileEnabled = GeneratedColumn<bool>(
    'profile_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("profile_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _voiceDeviceMeta = const VerificationMeta(
    'voiceDevice',
  );
  @override
  late final GeneratedColumn<String> voiceDevice = GeneratedColumn<String>(
    'voice_device',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowConfidenceMeta = const VerificationMeta(
    'lowConfidence',
  );
  @override
  late final GeneratedColumn<bool> lowConfidence = GeneratedColumn<bool>(
    'low_confidence',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("low_confidence" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    isNamedByUser,
    createdAt,
    centroid,
    embeddingCount,
    profileEnabled,
    voiceDevice,
    lowConfidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speakers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeakerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('is_named_by_user')) {
      context.handle(
        _isNamedByUserMeta,
        isNamedByUser.isAcceptableOrUnknown(
          data['is_named_by_user']!,
          _isNamedByUserMeta,
        ),
      );
    }
    if (data.containsKey('centroid')) {
      context.handle(
        _centroidMeta,
        centroid.isAcceptableOrUnknown(data['centroid']!, _centroidMeta),
      );
    }
    if (data.containsKey('embedding_count')) {
      context.handle(
        _embeddingCountMeta,
        embeddingCount.isAcceptableOrUnknown(
          data['embedding_count']!,
          _embeddingCountMeta,
        ),
      );
    }
    if (data.containsKey('profile_enabled')) {
      context.handle(
        _profileEnabledMeta,
        profileEnabled.isAcceptableOrUnknown(
          data['profile_enabled']!,
          _profileEnabledMeta,
        ),
      );
    }
    if (data.containsKey('voice_device')) {
      context.handle(
        _voiceDeviceMeta,
        voiceDevice.isAcceptableOrUnknown(
          data['voice_device']!,
          _voiceDeviceMeta,
        ),
      );
    }
    if (data.containsKey('low_confidence')) {
      context.handle(
        _lowConfidenceMeta,
        lowConfidence.isAcceptableOrUnknown(
          data['low_confidence']!,
          _lowConfidenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpeakerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeakerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      isNamedByUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_named_by_user'],
      )!,
      createdAt: $SpeakersTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      centroid: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}centroid'],
      ),
      embeddingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}embedding_count'],
      )!,
      profileEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}profile_enabled'],
      )!,
      voiceDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_device'],
      ),
      lowConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}low_confidence'],
      )!,
    );
  }

  @override
  $SpeakersTable createAlias(String alias) {
    return $SpeakersTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class SpeakerRow extends DataClass implements Insertable<SpeakerRow> {
  /// UUID primary key.
  final String id;

  /// Display name (auto names look like `متحدث 3`).
  final String name;

  /// ARGB color used for chips and avatars.
  final int color;

  /// True once the user explicitly renamed the speaker.
  final bool isNamedByUser;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;

  /// L2-normalised centroid as little-endian Float32 bytes; null when the
  /// voice was forgotten or never enrolled.
  final Uint8List? centroid;

  /// Number of embeddings averaged into [centroid].
  final int embeddingCount;

  /// v2 (F16): the user opted this speaker in to profiles.
  final bool profileEnabled;

  /// v2 (F18): input device the voiceprint was learned on.
  final String? voiceDevice;

  /// v2 (F15): heard only briefly; voiceprint not used for matching yet.
  final bool lowConfidence;
  const SpeakerRow({
    required this.id,
    required this.name,
    required this.color,
    required this.isNamedByUser,
    required this.createdAt,
    this.centroid,
    required this.embeddingCount,
    required this.profileEnabled,
    this.voiceDevice,
    required this.lowConfidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['is_named_by_user'] = Variable<bool>(isNamedByUser);
    {
      map['created_at'] = Variable<int>(
        $SpeakersTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    if (!nullToAbsent || centroid != null) {
      map['centroid'] = Variable<Uint8List>(centroid);
    }
    map['embedding_count'] = Variable<int>(embeddingCount);
    map['profile_enabled'] = Variable<bool>(profileEnabled);
    if (!nullToAbsent || voiceDevice != null) {
      map['voice_device'] = Variable<String>(voiceDevice);
    }
    map['low_confidence'] = Variable<bool>(lowConfidence);
    return map;
  }

  SpeakersCompanion toCompanion(bool nullToAbsent) {
    return SpeakersCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      isNamedByUser: Value(isNamedByUser),
      createdAt: Value(createdAt),
      centroid: centroid == null && nullToAbsent
          ? const Value.absent()
          : Value(centroid),
      embeddingCount: Value(embeddingCount),
      profileEnabled: Value(profileEnabled),
      voiceDevice: voiceDevice == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceDevice),
      lowConfidence: Value(lowConfidence),
    );
  }

  factory SpeakerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeakerRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      isNamedByUser: serializer.fromJson<bool>(json['isNamedByUser']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      centroid: serializer.fromJson<Uint8List?>(json['centroid']),
      embeddingCount: serializer.fromJson<int>(json['embeddingCount']),
      profileEnabled: serializer.fromJson<bool>(json['profileEnabled']),
      voiceDevice: serializer.fromJson<String?>(json['voiceDevice']),
      lowConfidence: serializer.fromJson<bool>(json['lowConfidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'isNamedByUser': serializer.toJson<bool>(isNamedByUser),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'centroid': serializer.toJson<Uint8List?>(centroid),
      'embeddingCount': serializer.toJson<int>(embeddingCount),
      'profileEnabled': serializer.toJson<bool>(profileEnabled),
      'voiceDevice': serializer.toJson<String?>(voiceDevice),
      'lowConfidence': serializer.toJson<bool>(lowConfidence),
    };
  }

  SpeakerRow copyWith({
    String? id,
    String? name,
    int? color,
    bool? isNamedByUser,
    DateTime? createdAt,
    Value<Uint8List?> centroid = const Value.absent(),
    int? embeddingCount,
    bool? profileEnabled,
    Value<String?> voiceDevice = const Value.absent(),
    bool? lowConfidence,
  }) => SpeakerRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    isNamedByUser: isNamedByUser ?? this.isNamedByUser,
    createdAt: createdAt ?? this.createdAt,
    centroid: centroid.present ? centroid.value : this.centroid,
    embeddingCount: embeddingCount ?? this.embeddingCount,
    profileEnabled: profileEnabled ?? this.profileEnabled,
    voiceDevice: voiceDevice.present ? voiceDevice.value : this.voiceDevice,
    lowConfidence: lowConfidence ?? this.lowConfidence,
  );
  SpeakerRow copyWithCompanion(SpeakersCompanion data) {
    return SpeakerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      isNamedByUser: data.isNamedByUser.present
          ? data.isNamedByUser.value
          : this.isNamedByUser,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      centroid: data.centroid.present ? data.centroid.value : this.centroid,
      embeddingCount: data.embeddingCount.present
          ? data.embeddingCount.value
          : this.embeddingCount,
      profileEnabled: data.profileEnabled.present
          ? data.profileEnabled.value
          : this.profileEnabled,
      voiceDevice: data.voiceDevice.present
          ? data.voiceDevice.value
          : this.voiceDevice,
      lowConfidence: data.lowConfidence.present
          ? data.lowConfidence.value
          : this.lowConfidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isNamedByUser: $isNamedByUser, ')
          ..write('createdAt: $createdAt, ')
          ..write('centroid: $centroid, ')
          ..write('embeddingCount: $embeddingCount, ')
          ..write('profileEnabled: $profileEnabled, ')
          ..write('voiceDevice: $voiceDevice, ')
          ..write('lowConfidence: $lowConfidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    isNamedByUser,
    createdAt,
    $driftBlobEquality.hash(centroid),
    embeddingCount,
    profileEnabled,
    voiceDevice,
    lowConfidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeakerRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.isNamedByUser == this.isNamedByUser &&
          other.createdAt == this.createdAt &&
          $driftBlobEquality.equals(other.centroid, this.centroid) &&
          other.embeddingCount == this.embeddingCount &&
          other.profileEnabled == this.profileEnabled &&
          other.voiceDevice == this.voiceDevice &&
          other.lowConfidence == this.lowConfidence);
}

class SpeakersCompanion extends UpdateCompanion<SpeakerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<bool> isNamedByUser;
  final Value<DateTime> createdAt;
  final Value<Uint8List?> centroid;
  final Value<int> embeddingCount;
  final Value<bool> profileEnabled;
  final Value<String?> voiceDevice;
  final Value<bool> lowConfidence;
  final Value<int> rowid;
  const SpeakersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.isNamedByUser = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.centroid = const Value.absent(),
    this.embeddingCount = const Value.absent(),
    this.profileEnabled = const Value.absent(),
    this.voiceDevice = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeakersCompanion.insert({
    required String id,
    required String name,
    required int color,
    this.isNamedByUser = const Value.absent(),
    required DateTime createdAt,
    this.centroid = const Value.absent(),
    this.embeddingCount = const Value.absent(),
    this.profileEnabled = const Value.absent(),
    this.voiceDevice = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color),
       createdAt = Value(createdAt);
  static Insertable<SpeakerRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<bool>? isNamedByUser,
    Expression<int>? createdAt,
    Expression<Uint8List>? centroid,
    Expression<int>? embeddingCount,
    Expression<bool>? profileEnabled,
    Expression<String>? voiceDevice,
    Expression<bool>? lowConfidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (isNamedByUser != null) 'is_named_by_user': isNamedByUser,
      if (createdAt != null) 'created_at': createdAt,
      if (centroid != null) 'centroid': centroid,
      if (embeddingCount != null) 'embedding_count': embeddingCount,
      if (profileEnabled != null) 'profile_enabled': profileEnabled,
      if (voiceDevice != null) 'voice_device': voiceDevice,
      if (lowConfidence != null) 'low_confidence': lowConfidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeakersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<bool>? isNamedByUser,
    Value<DateTime>? createdAt,
    Value<Uint8List?>? centroid,
    Value<int>? embeddingCount,
    Value<bool>? profileEnabled,
    Value<String?>? voiceDevice,
    Value<bool>? lowConfidence,
    Value<int>? rowid,
  }) {
    return SpeakersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isNamedByUser: isNamedByUser ?? this.isNamedByUser,
      createdAt: createdAt ?? this.createdAt,
      centroid: centroid ?? this.centroid,
      embeddingCount: embeddingCount ?? this.embeddingCount,
      profileEnabled: profileEnabled ?? this.profileEnabled,
      voiceDevice: voiceDevice ?? this.voiceDevice,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (isNamedByUser.present) {
      map['is_named_by_user'] = Variable<bool>(isNamedByUser.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $SpeakersTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (centroid.present) {
      map['centroid'] = Variable<Uint8List>(centroid.value);
    }
    if (embeddingCount.present) {
      map['embedding_count'] = Variable<int>(embeddingCount.value);
    }
    if (profileEnabled.present) {
      map['profile_enabled'] = Variable<bool>(profileEnabled.value);
    }
    if (voiceDevice.present) {
      map['voice_device'] = Variable<String>(voiceDevice.value);
    }
    if (lowConfidence.present) {
      map['low_confidence'] = Variable<bool>(lowConfidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isNamedByUser: $isNamedByUser, ')
          ..write('createdAt: $createdAt, ')
          ..write('centroid: $centroid, ')
          ..write('embeddingCount: $embeddingCount, ')
          ..write('profileEnabled: $profileEnabled, ')
          ..write('voiceDevice: $voiceDevice, ')
          ..write('lowConfidence: $lowConfidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeetingsTable extends Meetings
    with TableInfo<$MeetingsTable, MeetingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MeetingsTable.$convertercreatedAt);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minutesJsonMeta = const VerificationMeta(
    'minutesJson',
  );
  @override
  late final GeneratedColumn<String> minutesJson = GeneratedColumn<String>(
    'minutes_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _agendaJsonMeta = const VerificationMeta(
    'agendaJson',
  );
  @override
  late final GeneratedColumn<String> agendaJson = GeneratedColumn<String>(
    'agenda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _expectedAttendeesJsonMeta =
      const VerificationMeta('expectedAttendeesJson');
  @override
  late final GeneratedColumn<String> expectedAttendeesJson =
      GeneratedColumn<String>(
        'expected_attendees',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _contextNotesMeta = const VerificationMeta(
    'contextNotes',
  );
  @override
  late final GeneratedColumn<String> contextNotes = GeneratedColumn<String>(
    'context_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateMeta = const VerificationMeta(
    'template',
  );
  @override
  late final GeneratedColumn<String> template = GeneratedColumn<String>(
    'template',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inputDeviceMeta = const VerificationMeta(
    'inputDevice',
  );
  @override
  late final GeneratedColumn<String> inputDevice = GeneratedColumn<String>(
    'input_device',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    status,
    durationMs,
    audioPath,
    minutesJson,
    errorMessage,
    agendaJson,
    expectedAttendeesJson,
    contextNotes,
    template,
    inputDevice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeetingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('minutes_json')) {
      context.handle(
        _minutesJsonMeta,
        minutesJson.isAcceptableOrUnknown(
          data['minutes_json']!,
          _minutesJsonMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('agenda')) {
      context.handle(
        _agendaJsonMeta,
        agendaJson.isAcceptableOrUnknown(data['agenda']!, _agendaJsonMeta),
      );
    }
    if (data.containsKey('expected_attendees')) {
      context.handle(
        _expectedAttendeesJsonMeta,
        expectedAttendeesJson.isAcceptableOrUnknown(
          data['expected_attendees']!,
          _expectedAttendeesJsonMeta,
        ),
      );
    }
    if (data.containsKey('context_notes')) {
      context.handle(
        _contextNotesMeta,
        contextNotes.isAcceptableOrUnknown(
          data['context_notes']!,
          _contextNotesMeta,
        ),
      );
    }
    if (data.containsKey('template')) {
      context.handle(
        _templateMeta,
        template.isAcceptableOrUnknown(data['template']!, _templateMeta),
      );
    }
    if (data.containsKey('input_device')) {
      context.handle(
        _inputDeviceMeta,
        inputDevice.isAcceptableOrUnknown(
          data['input_device']!,
          _inputDeviceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeetingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeetingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: $MeetingsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      minutesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}minutes_json'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      agendaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agenda'],
      )!,
      expectedAttendeesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_attendees'],
      )!,
      contextNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_notes'],
      ),
      template: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template'],
      ),
      inputDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_device'],
      ),
    );
  }

  @override
  $MeetingsTable createAlias(String alias) {
    return $MeetingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class MeetingRow extends DataClass implements Insertable<MeetingRow> {
  /// UUID primary key.
  final String id;

  /// User-visible title.
  final String title;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;

  /// `MeetingStatus.name` (recording / processing / ready / failed).
  final String status;

  /// Recorded duration in milliseconds.
  final int durationMs;

  /// Absolute path of the archived WAV file, if kept.
  final String? audioPath;

  /// `Minutes.toJson()` encoded as JSON text.
  final String? minutesJson;

  /// Arabic, user-facing error message when [status] is `failed`.
  final String? errorMessage;

  /// v2 (F3): ordered agenda items as a JSON list of strings.
  final String agendaJson;

  /// v2 (F3): expected attendee names as a JSON list of strings.
  final String expectedAttendeesJson;

  /// v2 (F3): free-text context notes.
  final String? contextNotes;

  /// v2 (F3, reserved for v1.2): minutes template id.
  final String? template;

  /// v2 (F18): input device used for the recording.
  final String? inputDevice;
  const MeetingRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.status,
    required this.durationMs,
    this.audioPath,
    this.minutesJson,
    this.errorMessage,
    required this.agendaJson,
    required this.expectedAttendeesJson,
    this.contextNotes,
    this.template,
    this.inputDevice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['created_at'] = Variable<int>(
        $MeetingsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['status'] = Variable<String>(status);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || minutesJson != null) {
      map['minutes_json'] = Variable<String>(minutesJson);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['agenda'] = Variable<String>(agendaJson);
    map['expected_attendees'] = Variable<String>(expectedAttendeesJson);
    if (!nullToAbsent || contextNotes != null) {
      map['context_notes'] = Variable<String>(contextNotes);
    }
    if (!nullToAbsent || template != null) {
      map['template'] = Variable<String>(template);
    }
    if (!nullToAbsent || inputDevice != null) {
      map['input_device'] = Variable<String>(inputDevice);
    }
    return map;
  }

  MeetingsCompanion toCompanion(bool nullToAbsent) {
    return MeetingsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      status: Value(status),
      durationMs: Value(durationMs),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      minutesJson: minutesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(minutesJson),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      agendaJson: Value(agendaJson),
      expectedAttendeesJson: Value(expectedAttendeesJson),
      contextNotes: contextNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(contextNotes),
      template: template == null && nullToAbsent
          ? const Value.absent()
          : Value(template),
      inputDevice: inputDevice == null && nullToAbsent
          ? const Value.absent()
          : Value(inputDevice),
    );
  }

  factory MeetingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeetingRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      minutesJson: serializer.fromJson<String?>(json['minutesJson']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      agendaJson: serializer.fromJson<String>(json['agendaJson']),
      expectedAttendeesJson: serializer.fromJson<String>(
        json['expectedAttendeesJson'],
      ),
      contextNotes: serializer.fromJson<String?>(json['contextNotes']),
      template: serializer.fromJson<String?>(json['template']),
      inputDevice: serializer.fromJson<String?>(json['inputDevice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'durationMs': serializer.toJson<int>(durationMs),
      'audioPath': serializer.toJson<String?>(audioPath),
      'minutesJson': serializer.toJson<String?>(minutesJson),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'agendaJson': serializer.toJson<String>(agendaJson),
      'expectedAttendeesJson': serializer.toJson<String>(expectedAttendeesJson),
      'contextNotes': serializer.toJson<String?>(contextNotes),
      'template': serializer.toJson<String?>(template),
      'inputDevice': serializer.toJson<String?>(inputDevice),
    };
  }

  MeetingRow copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? status,
    int? durationMs,
    Value<String?> audioPath = const Value.absent(),
    Value<String?> minutesJson = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    String? agendaJson,
    String? expectedAttendeesJson,
    Value<String?> contextNotes = const Value.absent(),
    Value<String?> template = const Value.absent(),
    Value<String?> inputDevice = const Value.absent(),
  }) => MeetingRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    durationMs: durationMs ?? this.durationMs,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    minutesJson: minutesJson.present ? minutesJson.value : this.minutesJson,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    agendaJson: agendaJson ?? this.agendaJson,
    expectedAttendeesJson: expectedAttendeesJson ?? this.expectedAttendeesJson,
    contextNotes: contextNotes.present ? contextNotes.value : this.contextNotes,
    template: template.present ? template.value : this.template,
    inputDevice: inputDevice.present ? inputDevice.value : this.inputDevice,
  );
  MeetingRow copyWithCompanion(MeetingsCompanion data) {
    return MeetingRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      minutesJson: data.minutesJson.present
          ? data.minutesJson.value
          : this.minutesJson,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      agendaJson: data.agendaJson.present
          ? data.agendaJson.value
          : this.agendaJson,
      expectedAttendeesJson: data.expectedAttendeesJson.present
          ? data.expectedAttendeesJson.value
          : this.expectedAttendeesJson,
      contextNotes: data.contextNotes.present
          ? data.contextNotes.value
          : this.contextNotes,
      template: data.template.present ? data.template.value : this.template,
      inputDevice: data.inputDevice.present
          ? data.inputDevice.value
          : this.inputDevice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeetingRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioPath: $audioPath, ')
          ..write('minutesJson: $minutesJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('agendaJson: $agendaJson, ')
          ..write('expectedAttendeesJson: $expectedAttendeesJson, ')
          ..write('contextNotes: $contextNotes, ')
          ..write('template: $template, ')
          ..write('inputDevice: $inputDevice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    status,
    durationMs,
    audioPath,
    minutesJson,
    errorMessage,
    agendaJson,
    expectedAttendeesJson,
    contextNotes,
    template,
    inputDevice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeetingRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.durationMs == this.durationMs &&
          other.audioPath == this.audioPath &&
          other.minutesJson == this.minutesJson &&
          other.errorMessage == this.errorMessage &&
          other.agendaJson == this.agendaJson &&
          other.expectedAttendeesJson == this.expectedAttendeesJson &&
          other.contextNotes == this.contextNotes &&
          other.template == this.template &&
          other.inputDevice == this.inputDevice);
}

class MeetingsCompanion extends UpdateCompanion<MeetingRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> durationMs;
  final Value<String?> audioPath;
  final Value<String?> minutesJson;
  final Value<String?> errorMessage;
  final Value<String> agendaJson;
  final Value<String> expectedAttendeesJson;
  final Value<String?> contextNotes;
  final Value<String?> template;
  final Value<String?> inputDevice;
  final Value<int> rowid;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.minutesJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.agendaJson = const Value.absent(),
    this.expectedAttendeesJson = const Value.absent(),
    this.contextNotes = const Value.absent(),
    this.template = const Value.absent(),
    this.inputDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingsCompanion.insert({
    required String id,
    required String title,
    required DateTime createdAt,
    required String status,
    this.durationMs = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.minutesJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.agendaJson = const Value.absent(),
    this.expectedAttendeesJson = const Value.absent(),
    this.contextNotes = const Value.absent(),
    this.template = const Value.absent(),
    this.inputDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       status = Value(status);
  static Insertable<MeetingRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<String>? status,
    Expression<int>? durationMs,
    Expression<String>? audioPath,
    Expression<String>? minutesJson,
    Expression<String>? errorMessage,
    Expression<String>? agendaJson,
    Expression<String>? expectedAttendeesJson,
    Expression<String>? contextNotes,
    Expression<String>? template,
    Expression<String>? inputDevice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (durationMs != null) 'duration_ms': durationMs,
      if (audioPath != null) 'audio_path': audioPath,
      if (minutesJson != null) 'minutes_json': minutesJson,
      if (errorMessage != null) 'error_message': errorMessage,
      if (agendaJson != null) 'agenda': agendaJson,
      if (expectedAttendeesJson != null)
        'expected_attendees': expectedAttendeesJson,
      if (contextNotes != null) 'context_notes': contextNotes,
      if (template != null) 'template': template,
      if (inputDevice != null) 'input_device': inputDevice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<String>? status,
    Value<int>? durationMs,
    Value<String?>? audioPath,
    Value<String?>? minutesJson,
    Value<String?>? errorMessage,
    Value<String>? agendaJson,
    Value<String>? expectedAttendeesJson,
    Value<String?>? contextNotes,
    Value<String?>? template,
    Value<String?>? inputDevice,
    Value<int>? rowid,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      durationMs: durationMs ?? this.durationMs,
      audioPath: audioPath ?? this.audioPath,
      minutesJson: minutesJson ?? this.minutesJson,
      errorMessage: errorMessage ?? this.errorMessage,
      agendaJson: agendaJson ?? this.agendaJson,
      expectedAttendeesJson:
          expectedAttendeesJson ?? this.expectedAttendeesJson,
      contextNotes: contextNotes ?? this.contextNotes,
      template: template ?? this.template,
      inputDevice: inputDevice ?? this.inputDevice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $MeetingsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (minutesJson.present) {
      map['minutes_json'] = Variable<String>(minutesJson.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (agendaJson.present) {
      map['agenda'] = Variable<String>(agendaJson.value);
    }
    if (expectedAttendeesJson.present) {
      map['expected_attendees'] = Variable<String>(expectedAttendeesJson.value);
    }
    if (contextNotes.present) {
      map['context_notes'] = Variable<String>(contextNotes.value);
    }
    if (template.present) {
      map['template'] = Variable<String>(template.value);
    }
    if (inputDevice.present) {
      map['input_device'] = Variable<String>(inputDevice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioPath: $audioPath, ')
          ..write('minutesJson: $minutesJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('agendaJson: $agendaJson, ')
          ..write('expectedAttendeesJson: $expectedAttendeesJson, ')
          ..write('contextNotes: $contextNotes, ')
          ..write('template: $template, ')
          ..write('inputDevice: $inputDevice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SegmentsTable extends Segments
    with TableInfo<$SegmentsTable, SegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES speakers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speakerLockedMeta = const VerificationMeta(
    'speakerLocked',
  );
  @override
  late final GeneratedColumn<bool> speakerLocked = GeneratedColumn<bool>(
    'speaker_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("speaker_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('speech'),
  );
  static const VerificationMeta _asrConfidenceMeta = const VerificationMeta(
    'asrConfidence',
  );
  @override
  late final GeneratedColumn<double> asrConfidence = GeneratedColumn<double>(
    'asr_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speakerConfidenceMeta = const VerificationMeta(
    'speakerConfidence',
  );
  @override
  late final GeneratedColumn<double> speakerConfidence =
      GeneratedColumn<double>(
        'speaker_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    idx,
    startMs,
    endMs,
    body,
    speakerId,
    language,
    embedding,
    speakerLocked,
    kind,
    asrConfidence,
    speakerConfidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('speaker_locked')) {
      context.handle(
        _speakerLockedMeta,
        speakerLocked.isAcceptableOrUnknown(
          data['speaker_locked']!,
          _speakerLockedMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('asr_confidence')) {
      context.handle(
        _asrConfidenceMeta,
        asrConfidence.isAcceptableOrUnknown(
          data['asr_confidence']!,
          _asrConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('speaker_confidence')) {
      context.handle(
        _speakerConfidenceMeta,
        speakerConfidence.isAcceptableOrUnknown(
          data['speaker_confidence']!,
          _speakerConfidenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      speakerLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}speaker_locked'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      asrConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}asr_confidence'],
      ),
      speakerConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speaker_confidence'],
      ),
    );
  }

  @override
  $SegmentsTable createAlias(String alias) {
    return $SegmentsTable(attachedDatabase, alias);
  }
}

class SegmentRow extends DataClass implements Insertable<SegmentRow> {
  /// UUID primary key.
  final String id;

  /// Owning meeting; segments are deleted with their meeting.
  final String meetingId;

  /// Monotonic index within the meeting (0-based).
  final int idx;

  /// Start offset in milliseconds.
  final int startMs;

  /// End offset in milliseconds.
  final int endMs;

  /// Transcribed text.
  final String body;

  /// Assigned speaker; set to null when the speaker is deleted.
  final String? speakerId;

  /// ISO-639-1 language code reported by the ASR engine.
  final String? language;

  /// L2-normalised speaker embedding as little-endian Float32 bytes.
  final Uint8List? embedding;

  /// True when the user manually assigned the speaker.
  final bool speakerLocked;

  /// v2 (F17): `SegmentKind.wire` — `speech` or `unintelligible`.
  final String kind;

  /// v2: recogniser confidence 0..1 when reported.
  final double? asrConfidence;

  /// Confidence (0..1) of the automatic speaker assignment; null when
  /// unknown (rows from schema 1 and 2).
  final double? speakerConfidence;
  const SegmentRow({
    required this.id,
    required this.meetingId,
    required this.idx,
    required this.startMs,
    required this.endMs,
    required this.body,
    this.speakerId,
    this.language,
    this.embedding,
    required this.speakerLocked,
    required this.kind,
    this.asrConfidence,
    this.speakerConfidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['idx'] = Variable<int>(idx);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    map['speaker_locked'] = Variable<bool>(speakerLocked);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || asrConfidence != null) {
      map['asr_confidence'] = Variable<double>(asrConfidence);
    }
    if (!nullToAbsent || speakerConfidence != null) {
      map['speaker_confidence'] = Variable<double>(speakerConfidence);
    }
    return map;
  }

  SegmentsCompanion toCompanion(bool nullToAbsent) {
    return SegmentsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      idx: Value(idx),
      startMs: Value(startMs),
      endMs: Value(endMs),
      body: Value(body),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      speakerLocked: Value(speakerLocked),
      kind: Value(kind),
      asrConfidence: asrConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(asrConfidence),
      speakerConfidence: speakerConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerConfidence),
    );
  }

  factory SegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SegmentRow(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      idx: serializer.fromJson<int>(json['idx']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      body: serializer.fromJson<String>(json['body']),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      language: serializer.fromJson<String?>(json['language']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      speakerLocked: serializer.fromJson<bool>(json['speakerLocked']),
      kind: serializer.fromJson<String>(json['kind']),
      asrConfidence: serializer.fromJson<double?>(json['asrConfidence']),
      speakerConfidence: serializer.fromJson<double?>(
        json['speakerConfidence'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'idx': serializer.toJson<int>(idx),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'body': serializer.toJson<String>(body),
      'speakerId': serializer.toJson<String?>(speakerId),
      'language': serializer.toJson<String?>(language),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'speakerLocked': serializer.toJson<bool>(speakerLocked),
      'kind': serializer.toJson<String>(kind),
      'asrConfidence': serializer.toJson<double?>(asrConfidence),
      'speakerConfidence': serializer.toJson<double?>(speakerConfidence),
    };
  }

  SegmentRow copyWith({
    String? id,
    String? meetingId,
    int? idx,
    int? startMs,
    int? endMs,
    String? body,
    Value<String?> speakerId = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<Uint8List?> embedding = const Value.absent(),
    bool? speakerLocked,
    String? kind,
    Value<double?> asrConfidence = const Value.absent(),
    Value<double?> speakerConfidence = const Value.absent(),
  }) => SegmentRow(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    idx: idx ?? this.idx,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    body: body ?? this.body,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    language: language.present ? language.value : this.language,
    embedding: embedding.present ? embedding.value : this.embedding,
    speakerLocked: speakerLocked ?? this.speakerLocked,
    kind: kind ?? this.kind,
    asrConfidence: asrConfidence.present
        ? asrConfidence.value
        : this.asrConfidence,
    speakerConfidence: speakerConfidence.present
        ? speakerConfidence.value
        : this.speakerConfidence,
  );
  SegmentRow copyWithCompanion(SegmentsCompanion data) {
    return SegmentRow(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      idx: data.idx.present ? data.idx.value : this.idx,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      body: data.body.present ? data.body.value : this.body,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      language: data.language.present ? data.language.value : this.language,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      speakerLocked: data.speakerLocked.present
          ? data.speakerLocked.value
          : this.speakerLocked,
      kind: data.kind.present ? data.kind.value : this.kind,
      asrConfidence: data.asrConfidence.present
          ? data.asrConfidence.value
          : this.asrConfidence,
      speakerConfidence: data.speakerConfidence.present
          ? data.speakerConfidence.value
          : this.speakerConfidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SegmentRow(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('idx: $idx, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('body: $body, ')
          ..write('speakerId: $speakerId, ')
          ..write('language: $language, ')
          ..write('embedding: $embedding, ')
          ..write('speakerLocked: $speakerLocked, ')
          ..write('kind: $kind, ')
          ..write('asrConfidence: $asrConfidence, ')
          ..write('speakerConfidence: $speakerConfidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    idx,
    startMs,
    endMs,
    body,
    speakerId,
    language,
    $driftBlobEquality.hash(embedding),
    speakerLocked,
    kind,
    asrConfidence,
    speakerConfidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentRow &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.idx == this.idx &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.body == this.body &&
          other.speakerId == this.speakerId &&
          other.language == this.language &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.speakerLocked == this.speakerLocked &&
          other.kind == this.kind &&
          other.asrConfidence == this.asrConfidence &&
          other.speakerConfidence == this.speakerConfidence);
}

class SegmentsCompanion extends UpdateCompanion<SegmentRow> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<int> idx;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> body;
  final Value<String?> speakerId;
  final Value<String?> language;
  final Value<Uint8List?> embedding;
  final Value<bool> speakerLocked;
  final Value<String> kind;
  final Value<double?> asrConfidence;
  final Value<double?> speakerConfidence;
  final Value<int> rowid;
  const SegmentsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.idx = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.body = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.language = const Value.absent(),
    this.embedding = const Value.absent(),
    this.speakerLocked = const Value.absent(),
    this.kind = const Value.absent(),
    this.asrConfidence = const Value.absent(),
    this.speakerConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SegmentsCompanion.insert({
    required String id,
    required String meetingId,
    required int idx,
    required int startMs,
    required int endMs,
    required String body,
    this.speakerId = const Value.absent(),
    this.language = const Value.absent(),
    this.embedding = const Value.absent(),
    this.speakerLocked = const Value.absent(),
    this.kind = const Value.absent(),
    this.asrConfidence = const Value.absent(),
    this.speakerConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       idx = Value(idx),
       startMs = Value(startMs),
       endMs = Value(endMs),
       body = Value(body);
  static Insertable<SegmentRow> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<int>? idx,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? body,
    Expression<String>? speakerId,
    Expression<String>? language,
    Expression<Uint8List>? embedding,
    Expression<bool>? speakerLocked,
    Expression<String>? kind,
    Expression<double>? asrConfidence,
    Expression<double>? speakerConfidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (idx != null) 'idx': idx,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (body != null) 'text': body,
      if (speakerId != null) 'speaker_id': speakerId,
      if (language != null) 'language': language,
      if (embedding != null) 'embedding': embedding,
      if (speakerLocked != null) 'speaker_locked': speakerLocked,
      if (kind != null) 'kind': kind,
      if (asrConfidence != null) 'asr_confidence': asrConfidence,
      if (speakerConfidence != null) 'speaker_confidence': speakerConfidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<int>? idx,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? body,
    Value<String?>? speakerId,
    Value<String?>? language,
    Value<Uint8List?>? embedding,
    Value<bool>? speakerLocked,
    Value<String>? kind,
    Value<double?>? asrConfidence,
    Value<double?>? speakerConfidence,
    Value<int>? rowid,
  }) {
    return SegmentsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      idx: idx ?? this.idx,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      body: body ?? this.body,
      speakerId: speakerId ?? this.speakerId,
      language: language ?? this.language,
      embedding: embedding ?? this.embedding,
      speakerLocked: speakerLocked ?? this.speakerLocked,
      kind: kind ?? this.kind,
      asrConfidence: asrConfidence ?? this.asrConfidence,
      speakerConfidence: speakerConfidence ?? this.speakerConfidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (speakerLocked.present) {
      map['speaker_locked'] = Variable<bool>(speakerLocked.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (asrConfidence.present) {
      map['asr_confidence'] = Variable<double>(asrConfidence.value);
    }
    if (speakerConfidence.present) {
      map['speaker_confidence'] = Variable<double>(speakerConfidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SegmentsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('idx: $idx, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('body: $body, ')
          ..write('speakerId: $speakerId, ')
          ..write('language: $language, ')
          ..write('embedding: $embedding, ')
          ..write('speakerLocked: $speakerLocked, ')
          ..write('kind: $kind, ')
          ..write('asrConfidence: $asrConfidence, ')
          ..write('speakerConfidence: $speakerConfidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  /// Setting key.
  final String key;

  /// Setting value encoded as text.
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GlossaryTermsTable extends GlossaryTerms
    with TableInfo<$GlossaryTermsTable, GlossaryTermRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GlossaryTermsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
    'term',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _arSpellingMeta = const VerificationMeta(
    'arSpelling',
  );
  @override
  late final GeneratedColumn<String> arSpelling = GeneratedColumn<String>(
    'ar_spelling',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($GlossaryTermsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    term,
    arSpelling,
    category,
    meetingId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'glossary_terms';
  @override
  VerificationContext validateIntegrity(
    Insertable<GlossaryTermRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('term')) {
      context.handle(
        _termMeta,
        term.isAcceptableOrUnknown(data['term']!, _termMeta),
      );
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('ar_spelling')) {
      context.handle(
        _arSpellingMeta,
        arSpelling.isAcceptableOrUnknown(data['ar_spelling']!, _arSpellingMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GlossaryTermRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GlossaryTermRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      term: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}term'],
      )!,
      arSpelling: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ar_spelling'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      ),
      createdAt: $GlossaryTermsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $GlossaryTermsTable createAlias(String alias) {
    return $GlossaryTermsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class GlossaryTermRow extends DataClass implements Insertable<GlossaryTermRow> {
  /// Auto-increment primary key.
  final int id;

  /// The term as it should be spelled.
  final String term;

  /// Optional Arabic spelling / translation.
  final String? arSpelling;

  /// `GlossaryCategory.wire`.
  final String category;

  /// Meeting for a meeting-only term (F3); null for a global term.
  final String? meetingId;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;
  const GlossaryTermRow({
    required this.id,
    required this.term,
    this.arSpelling,
    required this.category,
    this.meetingId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['term'] = Variable<String>(term);
    if (!nullToAbsent || arSpelling != null) {
      map['ar_spelling'] = Variable<String>(arSpelling);
    }
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || meetingId != null) {
      map['meeting_id'] = Variable<String>(meetingId);
    }
    {
      map['created_at'] = Variable<int>(
        $GlossaryTermsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  GlossaryTermsCompanion toCompanion(bool nullToAbsent) {
    return GlossaryTermsCompanion(
      id: Value(id),
      term: Value(term),
      arSpelling: arSpelling == null && nullToAbsent
          ? const Value.absent()
          : Value(arSpelling),
      category: Value(category),
      meetingId: meetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(meetingId),
      createdAt: Value(createdAt),
    );
  }

  factory GlossaryTermRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GlossaryTermRow(
      id: serializer.fromJson<int>(json['id']),
      term: serializer.fromJson<String>(json['term']),
      arSpelling: serializer.fromJson<String?>(json['arSpelling']),
      category: serializer.fromJson<String>(json['category']),
      meetingId: serializer.fromJson<String?>(json['meetingId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'term': serializer.toJson<String>(term),
      'arSpelling': serializer.toJson<String?>(arSpelling),
      'category': serializer.toJson<String>(category),
      'meetingId': serializer.toJson<String?>(meetingId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GlossaryTermRow copyWith({
    int? id,
    String? term,
    Value<String?> arSpelling = const Value.absent(),
    String? category,
    Value<String?> meetingId = const Value.absent(),
    DateTime? createdAt,
  }) => GlossaryTermRow(
    id: id ?? this.id,
    term: term ?? this.term,
    arSpelling: arSpelling.present ? arSpelling.value : this.arSpelling,
    category: category ?? this.category,
    meetingId: meetingId.present ? meetingId.value : this.meetingId,
    createdAt: createdAt ?? this.createdAt,
  );
  GlossaryTermRow copyWithCompanion(GlossaryTermsCompanion data) {
    return GlossaryTermRow(
      id: data.id.present ? data.id.value : this.id,
      term: data.term.present ? data.term.value : this.term,
      arSpelling: data.arSpelling.present
          ? data.arSpelling.value
          : this.arSpelling,
      category: data.category.present ? data.category.value : this.category,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GlossaryTermRow(')
          ..write('id: $id, ')
          ..write('term: $term, ')
          ..write('arSpelling: $arSpelling, ')
          ..write('category: $category, ')
          ..write('meetingId: $meetingId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, term, arSpelling, category, meetingId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlossaryTermRow &&
          other.id == this.id &&
          other.term == this.term &&
          other.arSpelling == this.arSpelling &&
          other.category == this.category &&
          other.meetingId == this.meetingId &&
          other.createdAt == this.createdAt);
}

class GlossaryTermsCompanion extends UpdateCompanion<GlossaryTermRow> {
  final Value<int> id;
  final Value<String> term;
  final Value<String?> arSpelling;
  final Value<String> category;
  final Value<String?> meetingId;
  final Value<DateTime> createdAt;
  const GlossaryTermsCompanion({
    this.id = const Value.absent(),
    this.term = const Value.absent(),
    this.arSpelling = const Value.absent(),
    this.category = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GlossaryTermsCompanion.insert({
    this.id = const Value.absent(),
    required String term,
    this.arSpelling = const Value.absent(),
    this.category = const Value.absent(),
    this.meetingId = const Value.absent(),
    required DateTime createdAt,
  }) : term = Value(term),
       createdAt = Value(createdAt);
  static Insertable<GlossaryTermRow> custom({
    Expression<int>? id,
    Expression<String>? term,
    Expression<String>? arSpelling,
    Expression<String>? category,
    Expression<String>? meetingId,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (term != null) 'term': term,
      if (arSpelling != null) 'ar_spelling': arSpelling,
      if (category != null) 'category': category,
      if (meetingId != null) 'meeting_id': meetingId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GlossaryTermsCompanion copyWith({
    Value<int>? id,
    Value<String>? term,
    Value<String?>? arSpelling,
    Value<String>? category,
    Value<String?>? meetingId,
    Value<DateTime>? createdAt,
  }) {
    return GlossaryTermsCompanion(
      id: id ?? this.id,
      term: term ?? this.term,
      arSpelling: arSpelling ?? this.arSpelling,
      category: category ?? this.category,
      meetingId: meetingId ?? this.meetingId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (arSpelling.present) {
      map['ar_spelling'] = Variable<String>(arSpelling.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $GlossaryTermsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GlossaryTermsCompanion(')
          ..write('id: $id, ')
          ..write('term: $term, ')
          ..write('arSpelling: $arSpelling, ')
          ..write('category: $category, ')
          ..write('meetingId: $meetingId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskMeta = const VerificationMeta('task');
  @override
  late final GeneratedColumn<String> task = GeneratedColumn<String>(
    'task',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerSpeakerIdMeta = const VerificationMeta(
    'ownerSpeakerId',
  );
  @override
  late final GeneratedColumn<String> ownerSpeakerId = GeneratedColumn<String>(
    'owner_speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES speakers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _ownerTextMeta = const VerificationMeta(
    'ownerText',
  );
  @override
  late final GeneratedColumn<String> ownerText = GeneratedColumn<String>(
    'owner_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTextMeta = const VerificationMeta(
    'dueText',
  );
  @override
  late final GeneratedColumn<String> dueText = GeneratedColumn<String>(
    'due_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _sourceMeetingIdMeta = const VerificationMeta(
    'sourceMeetingId',
  );
  @override
  late final GeneratedColumn<String> sourceMeetingId = GeneratedColumn<String>(
    'source_meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _evidenceSegmentIdsMeta =
      const VerificationMeta('evidenceSegmentIds');
  @override
  late final GeneratedColumn<String> evidenceSegmentIds =
      GeneratedColumn<String>(
        'evidence_segment_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TasksTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TasksTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    task,
    ownerSpeakerId,
    ownerText,
    dueText,
    status,
    sourceMeetingId,
    evidenceSegmentIds,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task')) {
      context.handle(
        _taskMeta,
        task.isAcceptableOrUnknown(data['task']!, _taskMeta),
      );
    } else if (isInserting) {
      context.missing(_taskMeta);
    }
    if (data.containsKey('owner_speaker_id')) {
      context.handle(
        _ownerSpeakerIdMeta,
        ownerSpeakerId.isAcceptableOrUnknown(
          data['owner_speaker_id']!,
          _ownerSpeakerIdMeta,
        ),
      );
    }
    if (data.containsKey('owner_text')) {
      context.handle(
        _ownerTextMeta,
        ownerText.isAcceptableOrUnknown(data['owner_text']!, _ownerTextMeta),
      );
    }
    if (data.containsKey('due_text')) {
      context.handle(
        _dueTextMeta,
        dueText.isAcceptableOrUnknown(data['due_text']!, _dueTextMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('source_meeting_id')) {
      context.handle(
        _sourceMeetingIdMeta,
        sourceMeetingId.isAcceptableOrUnknown(
          data['source_meeting_id']!,
          _sourceMeetingIdMeta,
        ),
      );
    }
    if (data.containsKey('evidence_segment_ids')) {
      context.handle(
        _evidenceSegmentIdsMeta,
        evidenceSegmentIds.isAcceptableOrUnknown(
          data['evidence_segment_ids']!,
          _evidenceSegmentIdsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      task: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task'],
      )!,
      ownerSpeakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_speaker_id'],
      ),
      ownerText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_text'],
      ),
      dueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_text'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sourceMeetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_meeting_id'],
      ),
      evidenceSegmentIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_segment_ids'],
      )!,
      createdAt: $TasksTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $TasksTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMillisConverter();
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  /// Auto-increment primary key (the `task_id` shown to the minutes engine).
  final int id;

  /// Task description.
  final String task;

  /// Owner speaker, set to null when the speaker is deleted.
  final String? ownerSpeakerId;

  /// Owner as free text.
  final String? ownerText;

  /// Deadline as stated.
  final String? dueText;

  /// `TaskStatus.wire` — open / done / cancelled.
  final String status;

  /// Meeting whose minutes created the task; null when deleted / manual.
  final String? sourceMeetingId;

  /// Evidence segment indices (JSON list of integers).
  final String evidenceSegmentIds;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;

  /// Last update (UTC epoch milliseconds in SQL).
  final DateTime updatedAt;
  const TaskRow({
    required this.id,
    required this.task,
    this.ownerSpeakerId,
    this.ownerText,
    this.dueText,
    required this.status,
    this.sourceMeetingId,
    required this.evidenceSegmentIds,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task'] = Variable<String>(task);
    if (!nullToAbsent || ownerSpeakerId != null) {
      map['owner_speaker_id'] = Variable<String>(ownerSpeakerId);
    }
    if (!nullToAbsent || ownerText != null) {
      map['owner_text'] = Variable<String>(ownerText);
    }
    if (!nullToAbsent || dueText != null) {
      map['due_text'] = Variable<String>(dueText);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || sourceMeetingId != null) {
      map['source_meeting_id'] = Variable<String>(sourceMeetingId);
    }
    map['evidence_segment_ids'] = Variable<String>(evidenceSegmentIds);
    {
      map['created_at'] = Variable<int>(
        $TasksTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $TasksTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      task: Value(task),
      ownerSpeakerId: ownerSpeakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerSpeakerId),
      ownerText: ownerText == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerText),
      dueText: dueText == null && nullToAbsent
          ? const Value.absent()
          : Value(dueText),
      status: Value(status),
      sourceMeetingId: sourceMeetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMeetingId),
      evidenceSegmentIds: Value(evidenceSegmentIds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      task: serializer.fromJson<String>(json['task']),
      ownerSpeakerId: serializer.fromJson<String?>(json['ownerSpeakerId']),
      ownerText: serializer.fromJson<String?>(json['ownerText']),
      dueText: serializer.fromJson<String?>(json['dueText']),
      status: serializer.fromJson<String>(json['status']),
      sourceMeetingId: serializer.fromJson<String?>(json['sourceMeetingId']),
      evidenceSegmentIds: serializer.fromJson<String>(
        json['evidenceSegmentIds'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'task': serializer.toJson<String>(task),
      'ownerSpeakerId': serializer.toJson<String?>(ownerSpeakerId),
      'ownerText': serializer.toJson<String?>(ownerText),
      'dueText': serializer.toJson<String?>(dueText),
      'status': serializer.toJson<String>(status),
      'sourceMeetingId': serializer.toJson<String?>(sourceMeetingId),
      'evidenceSegmentIds': serializer.toJson<String>(evidenceSegmentIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TaskRow copyWith({
    int? id,
    String? task,
    Value<String?> ownerSpeakerId = const Value.absent(),
    Value<String?> ownerText = const Value.absent(),
    Value<String?> dueText = const Value.absent(),
    String? status,
    Value<String?> sourceMeetingId = const Value.absent(),
    String? evidenceSegmentIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaskRow(
    id: id ?? this.id,
    task: task ?? this.task,
    ownerSpeakerId: ownerSpeakerId.present
        ? ownerSpeakerId.value
        : this.ownerSpeakerId,
    ownerText: ownerText.present ? ownerText.value : this.ownerText,
    dueText: dueText.present ? dueText.value : this.dueText,
    status: status ?? this.status,
    sourceMeetingId: sourceMeetingId.present
        ? sourceMeetingId.value
        : this.sourceMeetingId,
    evidenceSegmentIds: evidenceSegmentIds ?? this.evidenceSegmentIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      task: data.task.present ? data.task.value : this.task,
      ownerSpeakerId: data.ownerSpeakerId.present
          ? data.ownerSpeakerId.value
          : this.ownerSpeakerId,
      ownerText: data.ownerText.present ? data.ownerText.value : this.ownerText,
      dueText: data.dueText.present ? data.dueText.value : this.dueText,
      status: data.status.present ? data.status.value : this.status,
      sourceMeetingId: data.sourceMeetingId.present
          ? data.sourceMeetingId.value
          : this.sourceMeetingId,
      evidenceSegmentIds: data.evidenceSegmentIds.present
          ? data.evidenceSegmentIds.value
          : this.evidenceSegmentIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('task: $task, ')
          ..write('ownerSpeakerId: $ownerSpeakerId, ')
          ..write('ownerText: $ownerText, ')
          ..write('dueText: $dueText, ')
          ..write('status: $status, ')
          ..write('sourceMeetingId: $sourceMeetingId, ')
          ..write('evidenceSegmentIds: $evidenceSegmentIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    task,
    ownerSpeakerId,
    ownerText,
    dueText,
    status,
    sourceMeetingId,
    evidenceSegmentIds,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.task == this.task &&
          other.ownerSpeakerId == this.ownerSpeakerId &&
          other.ownerText == this.ownerText &&
          other.dueText == this.dueText &&
          other.status == this.status &&
          other.sourceMeetingId == this.sourceMeetingId &&
          other.evidenceSegmentIds == this.evidenceSegmentIds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<String> task;
  final Value<String?> ownerSpeakerId;
  final Value<String?> ownerText;
  final Value<String?> dueText;
  final Value<String> status;
  final Value<String?> sourceMeetingId;
  final Value<String> evidenceSegmentIds;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.task = const Value.absent(),
    this.ownerSpeakerId = const Value.absent(),
    this.ownerText = const Value.absent(),
    this.dueText = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceMeetingId = const Value.absent(),
    this.evidenceSegmentIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required String task,
    this.ownerSpeakerId = const Value.absent(),
    this.ownerText = const Value.absent(),
    this.dueText = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceMeetingId = const Value.absent(),
    this.evidenceSegmentIds = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : task = Value(task),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<String>? task,
    Expression<String>? ownerSpeakerId,
    Expression<String>? ownerText,
    Expression<String>? dueText,
    Expression<String>? status,
    Expression<String>? sourceMeetingId,
    Expression<String>? evidenceSegmentIds,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (task != null) 'task': task,
      if (ownerSpeakerId != null) 'owner_speaker_id': ownerSpeakerId,
      if (ownerText != null) 'owner_text': ownerText,
      if (dueText != null) 'due_text': dueText,
      if (status != null) 'status': status,
      if (sourceMeetingId != null) 'source_meeting_id': sourceMeetingId,
      if (evidenceSegmentIds != null)
        'evidence_segment_ids': evidenceSegmentIds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String>? task,
    Value<String?>? ownerSpeakerId,
    Value<String?>? ownerText,
    Value<String?>? dueText,
    Value<String>? status,
    Value<String?>? sourceMeetingId,
    Value<String>? evidenceSegmentIds,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      task: task ?? this.task,
      ownerSpeakerId: ownerSpeakerId ?? this.ownerSpeakerId,
      ownerText: ownerText ?? this.ownerText,
      dueText: dueText ?? this.dueText,
      status: status ?? this.status,
      sourceMeetingId: sourceMeetingId ?? this.sourceMeetingId,
      evidenceSegmentIds: evidenceSegmentIds ?? this.evidenceSegmentIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (task.present) {
      map['task'] = Variable<String>(task.value);
    }
    if (ownerSpeakerId.present) {
      map['owner_speaker_id'] = Variable<String>(ownerSpeakerId.value);
    }
    if (ownerText.present) {
      map['owner_text'] = Variable<String>(ownerText.value);
    }
    if (dueText.present) {
      map['due_text'] = Variable<String>(dueText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sourceMeetingId.present) {
      map['source_meeting_id'] = Variable<String>(sourceMeetingId.value);
    }
    if (evidenceSegmentIds.present) {
      map['evidence_segment_ids'] = Variable<String>(evidenceSegmentIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $TasksTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $TasksTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('task: $task, ')
          ..write('ownerSpeakerId: $ownerSpeakerId, ')
          ..write('ownerText: $ownerText, ')
          ..write('dueText: $dueText, ')
          ..write('status: $status, ')
          ..write('sourceMeetingId: $sourceMeetingId, ')
          ..write('evidenceSegmentIds: $evidenceSegmentIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TaskUpdatesPendingTable extends TaskUpdatesPending
    with TableInfo<$TaskUpdatesPendingTable, PendingTaskUpdateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskUpdatesPendingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _newStatusMeta = const VerificationMeta(
    'newStatus',
  );
  @override
  late final GeneratedColumn<String> newStatus = GeneratedColumn<String>(
    'new_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evidenceJsonMeta = const VerificationMeta(
    'evidenceJson',
  );
  @override
  late final GeneratedColumn<String> evidenceJson = GeneratedColumn<String>(
    'evidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TaskUpdatesPendingTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    meetingId,
    newStatus,
    note,
    evidenceJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_updates_pending';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingTaskUpdateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('new_status')) {
      context.handle(
        _newStatusMeta,
        newStatus.isAcceptableOrUnknown(data['new_status']!, _newStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_newStatusMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('evidence')) {
      context.handle(
        _evidenceJsonMeta,
        evidenceJson.isAcceptableOrUnknown(
          data['evidence']!,
          _evidenceJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingTaskUpdateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingTaskUpdateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      newStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      evidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence'],
      )!,
      createdAt: $TaskUpdatesPendingTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $TaskUpdatesPendingTable createAlias(String alias) {
    return $TaskUpdatesPendingTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class PendingTaskUpdateRow extends DataClass
    implements Insertable<PendingTaskUpdateRow> {
  /// Auto-increment primary key.
  final int id;

  /// Task concerned; deleted with the task.
  final int taskId;

  /// Meeting whose minutes proposed it; deleted with the meeting.
  final String meetingId;

  /// Proposed `TaskStatus.wire`.
  final String newStatus;

  /// Arabic note.
  final String? note;

  /// Evidence segment indices (JSON list of integers).
  final String evidenceJson;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;
  const PendingTaskUpdateRow({
    required this.id,
    required this.taskId,
    required this.meetingId,
    required this.newStatus,
    this.note,
    required this.evidenceJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<int>(taskId);
    map['meeting_id'] = Variable<String>(meetingId);
    map['new_status'] = Variable<String>(newStatus);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['evidence'] = Variable<String>(evidenceJson);
    {
      map['created_at'] = Variable<int>(
        $TaskUpdatesPendingTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  TaskUpdatesPendingCompanion toCompanion(bool nullToAbsent) {
    return TaskUpdatesPendingCompanion(
      id: Value(id),
      taskId: Value(taskId),
      meetingId: Value(meetingId),
      newStatus: Value(newStatus),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      evidenceJson: Value(evidenceJson),
      createdAt: Value(createdAt),
    );
  }

  factory PendingTaskUpdateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingTaskUpdateRow(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<int>(json['taskId']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      newStatus: serializer.fromJson<String>(json['newStatus']),
      note: serializer.fromJson<String?>(json['note']),
      evidenceJson: serializer.fromJson<String>(json['evidenceJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<int>(taskId),
      'meetingId': serializer.toJson<String>(meetingId),
      'newStatus': serializer.toJson<String>(newStatus),
      'note': serializer.toJson<String?>(note),
      'evidenceJson': serializer.toJson<String>(evidenceJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingTaskUpdateRow copyWith({
    int? id,
    int? taskId,
    String? meetingId,
    String? newStatus,
    Value<String?> note = const Value.absent(),
    String? evidenceJson,
    DateTime? createdAt,
  }) => PendingTaskUpdateRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    meetingId: meetingId ?? this.meetingId,
    newStatus: newStatus ?? this.newStatus,
    note: note.present ? note.value : this.note,
    evidenceJson: evidenceJson ?? this.evidenceJson,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingTaskUpdateRow copyWithCompanion(TaskUpdatesPendingCompanion data) {
    return PendingTaskUpdateRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      newStatus: data.newStatus.present ? data.newStatus.value : this.newStatus,
      note: data.note.present ? data.note.value : this.note,
      evidenceJson: data.evidenceJson.present
          ? data.evidenceJson.value
          : this.evidenceJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingTaskUpdateRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('meetingId: $meetingId, ')
          ..write('newStatus: $newStatus, ')
          ..write('note: $note, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    meetingId,
    newStatus,
    note,
    evidenceJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingTaskUpdateRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.meetingId == this.meetingId &&
          other.newStatus == this.newStatus &&
          other.note == this.note &&
          other.evidenceJson == this.evidenceJson &&
          other.createdAt == this.createdAt);
}

class TaskUpdatesPendingCompanion
    extends UpdateCompanion<PendingTaskUpdateRow> {
  final Value<int> id;
  final Value<int> taskId;
  final Value<String> meetingId;
  final Value<String> newStatus;
  final Value<String?> note;
  final Value<String> evidenceJson;
  final Value<DateTime> createdAt;
  const TaskUpdatesPendingCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.newStatus = const Value.absent(),
    this.note = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TaskUpdatesPendingCompanion.insert({
    this.id = const Value.absent(),
    required int taskId,
    required String meetingId,
    required String newStatus,
    this.note = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    required DateTime createdAt,
  }) : taskId = Value(taskId),
       meetingId = Value(meetingId),
       newStatus = Value(newStatus),
       createdAt = Value(createdAt);
  static Insertable<PendingTaskUpdateRow> custom({
    Expression<int>? id,
    Expression<int>? taskId,
    Expression<String>? meetingId,
    Expression<String>? newStatus,
    Expression<String>? note,
    Expression<String>? evidenceJson,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (meetingId != null) 'meeting_id': meetingId,
      if (newStatus != null) 'new_status': newStatus,
      if (note != null) 'note': note,
      if (evidenceJson != null) 'evidence': evidenceJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TaskUpdatesPendingCompanion copyWith({
    Value<int>? id,
    Value<int>? taskId,
    Value<String>? meetingId,
    Value<String>? newStatus,
    Value<String?>? note,
    Value<String>? evidenceJson,
    Value<DateTime>? createdAt,
  }) {
    return TaskUpdatesPendingCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      meetingId: meetingId ?? this.meetingId,
      newStatus: newStatus ?? this.newStatus,
      note: note ?? this.note,
      evidenceJson: evidenceJson ?? this.evidenceJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (newStatus.present) {
      map['new_status'] = Variable<String>(newStatus.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (evidenceJson.present) {
      map['evidence'] = Variable<String>(evidenceJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $TaskUpdatesPendingTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskUpdatesPendingCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('meetingId: $meetingId, ')
          ..write('newStatus: $newStatus, ')
          ..write('note: $note, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SpeakerProfilesTable extends SpeakerProfiles
    with TableInfo<$SpeakerProfilesTable, SpeakerProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakerProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES speakers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _profileJsonMeta = const VerificationMeta(
    'profileJson',
  );
  @override
  late final GeneratedColumn<String> profileJson = GeneratedColumn<String>(
    'profile_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceJsonMeta = const VerificationMeta(
    'evidenceJson',
  );
  @override
  late final GeneratedColumn<String> evidenceJson = GeneratedColumn<String>(
    'evidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SpeakerProfilesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    speakerId,
    profileJson,
    evidenceJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speaker_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeakerProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_speakerIdMeta);
    }
    if (data.containsKey('profile_json')) {
      context.handle(
        _profileJsonMeta,
        profileJson.isAcceptableOrUnknown(
          data['profile_json']!,
          _profileJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileJsonMeta);
    }
    if (data.containsKey('evidence')) {
      context.handle(
        _evidenceJsonMeta,
        evidenceJson.isAcceptableOrUnknown(
          data['evidence']!,
          _evidenceJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {speakerId};
  @override
  SpeakerProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeakerProfileRow(
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      )!,
      profileJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_json'],
      )!,
      evidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence'],
      )!,
      updatedAt: $SpeakerProfilesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $SpeakerProfilesTable createAlias(String alias) {
    return $SpeakerProfilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMillisConverter();
}

class SpeakerProfileRow extends DataClass
    implements Insertable<SpeakerProfileRow> {
  /// Speaker; the profile is deleted with the speaker.
  final String speakerId;

  /// Profile JSON (shape owned by lib/features/profiles).
  final String profileJson;

  /// Cited evidence as a JSON list of `{meeting_id, segment}`.
  final String evidenceJson;

  /// Last update (UTC epoch milliseconds in SQL).
  final DateTime updatedAt;
  const SpeakerProfileRow({
    required this.speakerId,
    required this.profileJson,
    required this.evidenceJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['speaker_id'] = Variable<String>(speakerId);
    map['profile_json'] = Variable<String>(profileJson);
    map['evidence'] = Variable<String>(evidenceJson);
    {
      map['updated_at'] = Variable<int>(
        $SpeakerProfilesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  SpeakerProfilesCompanion toCompanion(bool nullToAbsent) {
    return SpeakerProfilesCompanion(
      speakerId: Value(speakerId),
      profileJson: Value(profileJson),
      evidenceJson: Value(evidenceJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SpeakerProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeakerProfileRow(
      speakerId: serializer.fromJson<String>(json['speakerId']),
      profileJson: serializer.fromJson<String>(json['profileJson']),
      evidenceJson: serializer.fromJson<String>(json['evidenceJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'speakerId': serializer.toJson<String>(speakerId),
      'profileJson': serializer.toJson<String>(profileJson),
      'evidenceJson': serializer.toJson<String>(evidenceJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SpeakerProfileRow copyWith({
    String? speakerId,
    String? profileJson,
    String? evidenceJson,
    DateTime? updatedAt,
  }) => SpeakerProfileRow(
    speakerId: speakerId ?? this.speakerId,
    profileJson: profileJson ?? this.profileJson,
    evidenceJson: evidenceJson ?? this.evidenceJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SpeakerProfileRow copyWithCompanion(SpeakerProfilesCompanion data) {
    return SpeakerProfileRow(
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      profileJson: data.profileJson.present
          ? data.profileJson.value
          : this.profileJson,
      evidenceJson: data.evidenceJson.present
          ? data.evidenceJson.value
          : this.evidenceJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerProfileRow(')
          ..write('speakerId: $speakerId, ')
          ..write('profileJson: $profileJson, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(speakerId, profileJson, evidenceJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeakerProfileRow &&
          other.speakerId == this.speakerId &&
          other.profileJson == this.profileJson &&
          other.evidenceJson == this.evidenceJson &&
          other.updatedAt == this.updatedAt);
}

class SpeakerProfilesCompanion extends UpdateCompanion<SpeakerProfileRow> {
  final Value<String> speakerId;
  final Value<String> profileJson;
  final Value<String> evidenceJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SpeakerProfilesCompanion({
    this.speakerId = const Value.absent(),
    this.profileJson = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeakerProfilesCompanion.insert({
    required String speakerId,
    required String profileJson,
    this.evidenceJson = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : speakerId = Value(speakerId),
       profileJson = Value(profileJson),
       updatedAt = Value(updatedAt);
  static Insertable<SpeakerProfileRow> custom({
    Expression<String>? speakerId,
    Expression<String>? profileJson,
    Expression<String>? evidenceJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (speakerId != null) 'speaker_id': speakerId,
      if (profileJson != null) 'profile_json': profileJson,
      if (evidenceJson != null) 'evidence': evidenceJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeakerProfilesCompanion copyWith({
    Value<String>? speakerId,
    Value<String>? profileJson,
    Value<String>? evidenceJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SpeakerProfilesCompanion(
      speakerId: speakerId ?? this.speakerId,
      profileJson: profileJson ?? this.profileJson,
      evidenceJson: evidenceJson ?? this.evidenceJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (profileJson.present) {
      map['profile_json'] = Variable<String>(profileJson.value);
    }
    if (evidenceJson.present) {
      map['evidence'] = Variable<String>(evidenceJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $SpeakerProfilesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerProfilesCompanion(')
          ..write('speakerId: $speakerId, ')
          ..write('profileJson: $profileJson, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeakerMeetingNotesTable extends SpeakerMeetingNotes
    with TableInfo<$SpeakerMeetingNotesTable, SpeakerMeetingNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakerMeetingNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES speakers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _notesJsonMeta = const VerificationMeta(
    'notesJson',
  );
  @override
  late final GeneratedColumn<String> notesJson = GeneratedColumn<String>(
    'notes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [speakerId, meetingId, notesJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speaker_meeting_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeakerMeetingNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_speakerIdMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('notes_json')) {
      context.handle(
        _notesJsonMeta,
        notesJson.isAcceptableOrUnknown(data['notes_json']!, _notesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_notesJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {speakerId, meetingId};
  @override
  SpeakerMeetingNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeakerMeetingNoteRow(
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      notesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes_json'],
      )!,
    );
  }

  @override
  $SpeakerMeetingNotesTable createAlias(String alias) {
    return $SpeakerMeetingNotesTable(attachedDatabase, alias);
  }
}

class SpeakerMeetingNoteRow extends DataClass
    implements Insertable<SpeakerMeetingNoteRow> {
  /// Speaker; deleted with the speaker.
  final String speakerId;

  /// Meeting; deleted with the meeting.
  final String meetingId;

  /// `MinutesSpeakerNote.toJson()`.
  final String notesJson;
  const SpeakerMeetingNoteRow({
    required this.speakerId,
    required this.meetingId,
    required this.notesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['speaker_id'] = Variable<String>(speakerId);
    map['meeting_id'] = Variable<String>(meetingId);
    map['notes_json'] = Variable<String>(notesJson);
    return map;
  }

  SpeakerMeetingNotesCompanion toCompanion(bool nullToAbsent) {
    return SpeakerMeetingNotesCompanion(
      speakerId: Value(speakerId),
      meetingId: Value(meetingId),
      notesJson: Value(notesJson),
    );
  }

  factory SpeakerMeetingNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeakerMeetingNoteRow(
      speakerId: serializer.fromJson<String>(json['speakerId']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      notesJson: serializer.fromJson<String>(json['notesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'speakerId': serializer.toJson<String>(speakerId),
      'meetingId': serializer.toJson<String>(meetingId),
      'notesJson': serializer.toJson<String>(notesJson),
    };
  }

  SpeakerMeetingNoteRow copyWith({
    String? speakerId,
    String? meetingId,
    String? notesJson,
  }) => SpeakerMeetingNoteRow(
    speakerId: speakerId ?? this.speakerId,
    meetingId: meetingId ?? this.meetingId,
    notesJson: notesJson ?? this.notesJson,
  );
  SpeakerMeetingNoteRow copyWithCompanion(SpeakerMeetingNotesCompanion data) {
    return SpeakerMeetingNoteRow(
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      notesJson: data.notesJson.present ? data.notesJson.value : this.notesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerMeetingNoteRow(')
          ..write('speakerId: $speakerId, ')
          ..write('meetingId: $meetingId, ')
          ..write('notesJson: $notesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(speakerId, meetingId, notesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeakerMeetingNoteRow &&
          other.speakerId == this.speakerId &&
          other.meetingId == this.meetingId &&
          other.notesJson == this.notesJson);
}

class SpeakerMeetingNotesCompanion
    extends UpdateCompanion<SpeakerMeetingNoteRow> {
  final Value<String> speakerId;
  final Value<String> meetingId;
  final Value<String> notesJson;
  final Value<int> rowid;
  const SpeakerMeetingNotesCompanion({
    this.speakerId = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.notesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeakerMeetingNotesCompanion.insert({
    required String speakerId,
    required String meetingId,
    required String notesJson,
    this.rowid = const Value.absent(),
  }) : speakerId = Value(speakerId),
       meetingId = Value(meetingId),
       notesJson = Value(notesJson);
  static Insertable<SpeakerMeetingNoteRow> custom({
    Expression<String>? speakerId,
    Expression<String>? meetingId,
    Expression<String>? notesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (speakerId != null) 'speaker_id': speakerId,
      if (meetingId != null) 'meeting_id': meetingId,
      if (notesJson != null) 'notes_json': notesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeakerMeetingNotesCompanion copyWith({
    Value<String>? speakerId,
    Value<String>? meetingId,
    Value<String>? notesJson,
    Value<int>? rowid,
  }) {
    return SpeakerMeetingNotesCompanion(
      speakerId: speakerId ?? this.speakerId,
      meetingId: meetingId ?? this.meetingId,
      notesJson: notesJson ?? this.notesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (notesJson.present) {
      map['notes_json'] = Variable<String>(notesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerMeetingNotesCompanion(')
          ..write('speakerId: $speakerId, ')
          ..write('meetingId: $meetingId, ')
          ..write('notesJson: $notesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CodeFindingsTable extends CodeFindings
    with TableInfo<$CodeFindingsTable, CodeFindingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CodeFindingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES speakers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _segmentIdsJsonMeta = const VerificationMeta(
    'segmentIdsJson',
  );
  @override
  late final GeneratedColumn<String> segmentIdsJson = GeneratedColumn<String>(
    'segment_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($CodeFindingsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    kind,
    speakerId,
    segmentIdsJson,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'code_findings';
  @override
  VerificationContext validateIntegrity(
    Insertable<CodeFindingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    }
    if (data.containsKey('segment_ids')) {
      context.handle(
        _segmentIdsJsonMeta,
        segmentIdsJson.isAcceptableOrUnknown(
          data['segment_ids']!,
          _segmentIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CodeFindingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CodeFindingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      ),
      segmentIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_ids'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: $CodeFindingsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $CodeFindingsTable createAlias(String alias) {
    return $CodeFindingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class CodeFindingRow extends DataClass implements Insertable<CodeFindingRow> {
  /// Auto-increment primary key.
  final int id;

  /// Meeting; deleted with the meeting.
  final String meetingId;

  /// `CodeFindingKind.wire`.
  final String kind;

  /// Speaker who said it; null when unresolved or deleted.
  final String? speakerId;

  /// Evidence segment indices (JSON list of integers).
  final String segmentIdsJson;

  /// Finding JSON.
  final String payloadJson;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;
  const CodeFindingRow({
    required this.id,
    required this.meetingId,
    required this.kind,
    this.speakerId,
    required this.segmentIdsJson,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    map['segment_ids'] = Variable<String>(segmentIdsJson);
    map['payload_json'] = Variable<String>(payloadJson);
    {
      map['created_at'] = Variable<int>(
        $CodeFindingsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  CodeFindingsCompanion toCompanion(bool nullToAbsent) {
    return CodeFindingsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      kind: Value(kind),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      segmentIdsJson: Value(segmentIdsJson),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory CodeFindingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CodeFindingRow(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      kind: serializer.fromJson<String>(json['kind']),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      segmentIdsJson: serializer.fromJson<String>(json['segmentIdsJson']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'kind': serializer.toJson<String>(kind),
      'speakerId': serializer.toJson<String?>(speakerId),
      'segmentIdsJson': serializer.toJson<String>(segmentIdsJson),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CodeFindingRow copyWith({
    int? id,
    String? meetingId,
    String? kind,
    Value<String?> speakerId = const Value.absent(),
    String? segmentIdsJson,
    String? payloadJson,
    DateTime? createdAt,
  }) => CodeFindingRow(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    kind: kind ?? this.kind,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    segmentIdsJson: segmentIdsJson ?? this.segmentIdsJson,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  CodeFindingRow copyWithCompanion(CodeFindingsCompanion data) {
    return CodeFindingRow(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      kind: data.kind.present ? data.kind.value : this.kind,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      segmentIdsJson: data.segmentIdsJson.present
          ? data.segmentIdsJson.value
          : this.segmentIdsJson,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CodeFindingRow(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('speakerId: $speakerId, ')
          ..write('segmentIdsJson: $segmentIdsJson, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    kind,
    speakerId,
    segmentIdsJson,
    payloadJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CodeFindingRow &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.kind == this.kind &&
          other.speakerId == this.speakerId &&
          other.segmentIdsJson == this.segmentIdsJson &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class CodeFindingsCompanion extends UpdateCompanion<CodeFindingRow> {
  final Value<int> id;
  final Value<String> meetingId;
  final Value<String> kind;
  final Value<String?> speakerId;
  final Value<String> segmentIdsJson;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  const CodeFindingsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.kind = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.segmentIdsJson = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CodeFindingsCompanion.insert({
    this.id = const Value.absent(),
    required String meetingId,
    required String kind,
    this.speakerId = const Value.absent(),
    this.segmentIdsJson = const Value.absent(),
    required String payloadJson,
    required DateTime createdAt,
  }) : meetingId = Value(meetingId),
       kind = Value(kind),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<CodeFindingRow> custom({
    Expression<int>? id,
    Expression<String>? meetingId,
    Expression<String>? kind,
    Expression<String>? speakerId,
    Expression<String>? segmentIdsJson,
    Expression<String>? payloadJson,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (kind != null) 'kind': kind,
      if (speakerId != null) 'speaker_id': speakerId,
      if (segmentIdsJson != null) 'segment_ids': segmentIdsJson,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CodeFindingsCompanion copyWith({
    Value<int>? id,
    Value<String>? meetingId,
    Value<String>? kind,
    Value<String?>? speakerId,
    Value<String>? segmentIdsJson,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
  }) {
    return CodeFindingsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      kind: kind ?? this.kind,
      speakerId: speakerId ?? this.speakerId,
      segmentIdsJson: segmentIdsJson ?? this.segmentIdsJson,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (segmentIdsJson.present) {
      map['segment_ids'] = Variable<String>(segmentIdsJson.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $CodeFindingsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CodeFindingsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('speakerId: $speakerId, ')
          ..write('segmentIdsJson: $segmentIdsJson, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpeakersTable speakers = $SpeakersTable(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $SegmentsTable segments = $SegmentsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $GlossaryTermsTable glossaryTerms = $GlossaryTermsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $TaskUpdatesPendingTable taskUpdatesPending =
      $TaskUpdatesPendingTable(this);
  late final $SpeakerProfilesTable speakerProfiles = $SpeakerProfilesTable(
    this,
  );
  late final $SpeakerMeetingNotesTable speakerMeetingNotes =
      $SpeakerMeetingNotesTable(this);
  late final $CodeFindingsTable codeFindings = $CodeFindingsTable(this);
  late final Index segmentsMeetingIdx = Index(
    'segments_meeting_idx',
    'CREATE INDEX segments_meeting_idx ON segments (meeting_id, idx)',
  );
  late final Index segmentsSpeaker = Index(
    'segments_speaker',
    'CREATE INDEX segments_speaker ON segments (speaker_id)',
  );
  late final Index glossaryTermsMeeting = Index(
    'glossary_terms_meeting',
    'CREATE INDEX glossary_terms_meeting ON glossary_terms (meeting_id)',
  );
  late final Index tasksStatus = Index(
    'tasks_status',
    'CREATE INDEX tasks_status ON tasks (status)',
  );
  late final Index tasksSourceMeeting = Index(
    'tasks_source_meeting',
    'CREATE INDEX tasks_source_meeting ON tasks (source_meeting_id)',
  );
  late final Index taskUpdatesPendingMeeting = Index(
    'task_updates_pending_meeting',
    'CREATE INDEX task_updates_pending_meeting ON task_updates_pending (meeting_id)',
  );
  late final Index taskUpdatesPendingTask = Index(
    'task_updates_pending_task',
    'CREATE INDEX task_updates_pending_task ON task_updates_pending (task_id)',
  );
  late final Index speakerMeetingNotesMeeting = Index(
    'speaker_meeting_notes_meeting',
    'CREATE INDEX speaker_meeting_notes_meeting ON speaker_meeting_notes (meeting_id)',
  );
  late final Index codeFindingsMeeting = Index(
    'code_findings_meeting',
    'CREATE INDEX code_findings_meeting ON code_findings (meeting_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    speakers,
    meetings,
    segments,
    settings,
    glossaryTerms,
    tasks,
    taskUpdatesPending,
    speakerProfiles,
    speakerMeetingNotes,
    codeFindings,
    segmentsMeetingIdx,
    segmentsSpeaker,
    glossaryTermsMeeting,
    tasksStatus,
    tasksSourceMeeting,
    taskUpdatesPendingMeeting,
    taskUpdatesPendingTask,
    speakerMeetingNotesMeeting,
    codeFindingsMeeting,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'speakers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('glossary_terms', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'speakers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_updates_pending', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_updates_pending', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'speakers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speaker_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'speakers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speaker_meeting_notes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speaker_meeting_notes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('code_findings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'speakers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('code_findings', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$SpeakersTableCreateCompanionBuilder = SpeakersCompanion Function({
  required String id,
  required String name,
  required int color,
  Value<bool> isNamedByUser,
  required DateTime createdAt,
  Value<Uint8List?> centroid,
  Value<int> embeddingCount,
  Value<bool> profileEnabled,
  Value<String?> voiceDevice,
  Value<bool> lowConfidence,
  Value<int> rowid,
});
typedef $$SpeakersTableUpdateCompanionBuilder = SpeakersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> color,
  Value<bool> isNamedByUser,
  Value<DateTime> createdAt,
  Value<Uint8List?> centroid,
  Value<int> embeddingCount,
  Value<bool> profileEnabled,
  Value<String?> voiceDevice,
  Value<bool> lowConfidence,
  Value<int> rowid,
});

final class $$SpeakersTableReferences
    extends BaseReferences<_$AppDatabase, $SpeakersTable, SpeakerRow> {
  $$SpeakersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SegmentsTable, List<SegmentRow>>
  _segmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.segments,
    aliasName: 'speakers__id__segments__speaker_id',
  );

  $$SegmentsTableProcessedTableManager get segmentsRefs {
    final manager = $$SegmentsTableTableManager(
      $_db,
      $_db.segments,
    ).filter((f) => f.speakerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_segmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'speakers__id__tasks__owner_speaker_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.ownerSpeakerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpeakerProfilesTable, List<SpeakerProfileRow>>
  _speakerProfilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.speakerProfiles,
    aliasName: 'speakers__id__speaker_profiles__speaker_id',
  );

  $$SpeakerProfilesTableProcessedTableManager get speakerProfilesRefs {
    final manager = $$SpeakerProfilesTableTableManager(
      $_db,
      $_db.speakerProfiles,
    ).filter((f) => f.speakerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _speakerProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SpeakerMeetingNotesTable,
    List<SpeakerMeetingNoteRow>
  >
  _speakerMeetingNotesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.speakerMeetingNotes,
        aliasName: 'speakers__id__speaker_meeting_notes__speaker_id',
      );

  $$SpeakerMeetingNotesTableProcessedTableManager get speakerMeetingNotesRefs {
    final manager = $$SpeakerMeetingNotesTableTableManager(
      $_db,
      $_db.speakerMeetingNotes,
    ).filter((f) => f.speakerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _speakerMeetingNotesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CodeFindingsTable, List<CodeFindingRow>>
  _codeFindingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.codeFindings,
    aliasName: 'speakers__id__code_findings__speaker_id',
  );

  $$CodeFindingsTableProcessedTableManager get codeFindingsRefs {
    final manager = $$CodeFindingsTableTableManager(
      $_db,
      $_db.codeFindings,
    ).filter((f) => f.speakerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_codeFindingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SpeakersTableFilterComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNamedByUser => $composableBuilder(
    column: $table.isNamedByUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<Uint8List> get centroid => $composableBuilder(
    column: $table.centroid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get embeddingCount => $composableBuilder(
    column: $table.embeddingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get profileEnabled => $composableBuilder(
    column: $table.profileEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceDevice => $composableBuilder(
    column: $table.voiceDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lowConfidence => $composableBuilder(
    column: $table.lowConfidence,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> segmentsRefs(
    Expression<bool> Function($$SegmentsTableFilterComposer f) f,
  ) {
    final $$SegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableFilterComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.ownerSpeakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakerProfilesRefs(
    Expression<bool> Function($$SpeakerProfilesTableFilterComposer f) f,
  ) {
    final $$SpeakerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakerProfiles,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.speakerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakerMeetingNotesRefs(
    Expression<bool> Function($$SpeakerMeetingNotesTableFilterComposer f) f,
  ) {
    final $$SpeakerMeetingNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakerMeetingNotes,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakerMeetingNotesTableFilterComposer(
            $db: $db,
            $table: $db.speakerMeetingNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> codeFindingsRefs(
    Expression<bool> Function($$CodeFindingsTableFilterComposer f) f,
  ) {
    final $$CodeFindingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.codeFindings,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CodeFindingsTableFilterComposer(
            $db: $db,
            $table: $db.codeFindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SpeakersTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNamedByUser => $composableBuilder(
    column: $table.isNamedByUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get centroid => $composableBuilder(
    column: $table.centroid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get embeddingCount => $composableBuilder(
    column: $table.embeddingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get profileEnabled => $composableBuilder(
    column: $table.profileEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceDevice => $composableBuilder(
    column: $table.voiceDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lowConfidence => $composableBuilder(
    column: $table.lowConfidence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpeakersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isNamedByUser => $composableBuilder(
    column: $table.isNamedByUser,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get centroid =>
      $composableBuilder(column: $table.centroid, builder: (column) => column);

  GeneratedColumn<int> get embeddingCount => $composableBuilder(
    column: $table.embeddingCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get profileEnabled => $composableBuilder(
    column: $table.profileEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceDevice => $composableBuilder(
    column: $table.voiceDevice,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lowConfidence => $composableBuilder(
    column: $table.lowConfidence,
    builder: (column) => column,
  );

  Expression<T> segmentsRefs<T extends Object>(
    Expression<T> Function($$SegmentsTableAnnotationComposer a) f,
  ) {
    final $$SegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.ownerSpeakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> speakerProfilesRefs<T extends Object>(
    Expression<T> Function($$SpeakerProfilesTableAnnotationComposer a) f,
  ) {
    final $$SpeakerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakerProfiles,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.speakerProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> speakerMeetingNotesRefs<T extends Object>(
    Expression<T> Function($$SpeakerMeetingNotesTableAnnotationComposer a) f,
  ) {
    final $$SpeakerMeetingNotesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.speakerMeetingNotes,
          getReferencedColumn: (t) => t.speakerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SpeakerMeetingNotesTableAnnotationComposer(
                $db: $db,
                $table: $db.speakerMeetingNotes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> codeFindingsRefs<T extends Object>(
    Expression<T> Function($$CodeFindingsTableAnnotationComposer a) f,
  ) {
    final $$CodeFindingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.codeFindings,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CodeFindingsTableAnnotationComposer(
            $db: $db,
            $table: $db.codeFindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SpeakersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeakersTable,
          SpeakerRow,
          $$SpeakersTableFilterComposer,
          $$SpeakersTableOrderingComposer,
          $$SpeakersTableAnnotationComposer,
          $$SpeakersTableCreateCompanionBuilder,
          $$SpeakersTableUpdateCompanionBuilder,
          (SpeakerRow, $$SpeakersTableReferences),
          SpeakerRow,
          PrefetchHooks Function({
            bool segmentsRefs,
            bool tasksRefs,
            bool speakerProfilesRefs,
            bool speakerMeetingNotesRefs,
            bool codeFindingsRefs,
          })
        > {
  $$SpeakersTableTableManager(_$AppDatabase db, $SpeakersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeakersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<bool> isNamedByUser = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<Uint8List?> centroid = const Value.absent(),
                Value<int> embeddingCount = const Value.absent(),
                Value<bool> profileEnabled = const Value.absent(),
                Value<String?> voiceDevice = const Value.absent(),
                Value<bool> lowConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion(
                id: id,
                name: name,
                color: color,
                isNamedByUser: isNamedByUser,
                createdAt: createdAt,
                centroid: centroid,
                embeddingCount: embeddingCount,
                profileEnabled: profileEnabled,
                voiceDevice: voiceDevice,
                lowConfidence: lowConfidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int color,
                Value<bool> isNamedByUser = const Value.absent(),
                required DateTime createdAt,
                Value<Uint8List?> centroid = const Value.absent(),
                Value<int> embeddingCount = const Value.absent(),
                Value<bool> profileEnabled = const Value.absent(),
                Value<String?> voiceDevice = const Value.absent(),
                Value<bool> lowConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion.insert(
                id: id,
                name: name,
                color: color,
                isNamedByUser: isNamedByUser,
                createdAt: createdAt,
                centroid: centroid,
                embeddingCount: embeddingCount,
                profileEnabled: profileEnabled,
                voiceDevice: voiceDevice,
                lowConfidence: lowConfidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakersTable, SpeakerRow>(table),
                  $$SpeakersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                segmentsRefs = false,
                tasksRefs = false,
                speakerProfilesRefs = false,
                speakerMeetingNotesRefs = false,
                codeFindingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (segmentsRefs) db.segments,
                    if (tasksRefs) db.tasks,
                    if (speakerProfilesRefs) db.speakerProfiles,
                    if (speakerMeetingNotesRefs) db.speakerMeetingNotes,
                    if (codeFindingsRefs) db.codeFindings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (segmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          SpeakerRow,
                          $SpeakersTable,
                          SegmentRow,
                          $SegmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SpeakersTableReferences
                              ._segmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpeakersTableReferences(
                                db,
                                table,
                                p0,
                              ).segmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'speaker_id',
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedDataByColumns<
                          SpeakerRow,
                          $SpeakersTable,
                          TaskRow,
                          $TasksTable
                        >(
                          currentTable: table,
                          referencedTable: $$SpeakersTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpeakersTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'owner_speaker_id',
                          typedResults: items,
                        ),
                      if (speakerProfilesRefs)
                        await $_getPrefetchedDataByColumns<
                          SpeakerRow,
                          $SpeakersTable,
                          SpeakerProfileRow,
                          $SpeakerProfilesTable
                        >(
                          currentTable: table,
                          referencedTable: $$SpeakersTableReferences
                              ._speakerProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpeakersTableReferences(
                                db,
                                table,
                                p0,
                              ).speakerProfilesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'speaker_id',
                          typedResults: items,
                        ),
                      if (speakerMeetingNotesRefs)
                        await $_getPrefetchedDataByColumns<
                          SpeakerRow,
                          $SpeakersTable,
                          SpeakerMeetingNoteRow,
                          $SpeakerMeetingNotesTable
                        >(
                          currentTable: table,
                          referencedTable: $$SpeakersTableReferences
                              ._speakerMeetingNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpeakersTableReferences(
                                db,
                                table,
                                p0,
                              ).speakerMeetingNotesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'speaker_id',
                          typedResults: items,
                        ),
                      if (codeFindingsRefs)
                        await $_getPrefetchedDataByColumns<
                          SpeakerRow,
                          $SpeakersTable,
                          CodeFindingRow,
                          $CodeFindingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SpeakersTableReferences
                              ._codeFindingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpeakersTableReferences(
                                db,
                                table,
                                p0,
                              ).codeFindingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'speaker_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SpeakersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeakersTable,
      SpeakerRow,
      $$SpeakersTableFilterComposer,
      $$SpeakersTableOrderingComposer,
      $$SpeakersTableAnnotationComposer,
      $$SpeakersTableCreateCompanionBuilder,
      $$SpeakersTableUpdateCompanionBuilder,
      (SpeakerRow, $$SpeakersTableReferences),
      SpeakerRow,
      PrefetchHooks Function({
        bool segmentsRefs,
        bool tasksRefs,
        bool speakerProfilesRefs,
        bool speakerMeetingNotesRefs,
        bool codeFindingsRefs,
      })
    >;
typedef $$MeetingsTableCreateCompanionBuilder = MeetingsCompanion Function({
  required String id,
  required String title,
  required DateTime createdAt,
  required String status,
  Value<int> durationMs,
  Value<String?> audioPath,
  Value<String?> minutesJson,
  Value<String?> errorMessage,
  Value<String> agendaJson,
  Value<String> expectedAttendeesJson,
  Value<String?> contextNotes,
  Value<String?> template,
  Value<String?> inputDevice,
  Value<int> rowid,
});
typedef $$MeetingsTableUpdateCompanionBuilder = MeetingsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> durationMs,
  Value<String?> audioPath,
  Value<String?> minutesJson,
  Value<String?> errorMessage,
  Value<String> agendaJson,
  Value<String> expectedAttendeesJson,
  Value<String?> contextNotes,
  Value<String?> template,
  Value<String?> inputDevice,
  Value<int> rowid,
});

final class $$MeetingsTableReferences
    extends BaseReferences<_$AppDatabase, $MeetingsTable, MeetingRow> {
  $$MeetingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SegmentsTable, List<SegmentRow>>
  _segmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.segments,
    aliasName: 'meetings__id__segments__meeting_id',
  );

  $$SegmentsTableProcessedTableManager get segmentsRefs {
    final manager = $$SegmentsTableTableManager(
      $_db,
      $_db.segments,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_segmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GlossaryTermsTable, List<GlossaryTermRow>>
  _glossaryTermsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.glossaryTerms,
    aliasName: 'meetings__id__glossary_terms__meeting_id',
  );

  $$GlossaryTermsTableProcessedTableManager get glossaryTermsRefs {
    final manager = $$GlossaryTermsTableTableManager(
      $_db,
      $_db.glossaryTerms,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_glossaryTermsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'meetings__id__tasks__source_meeting_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.sourceMeetingId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TaskUpdatesPendingTable,
    List<PendingTaskUpdateRow>
  >
  _taskUpdatesPendingRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskUpdatesPending,
        aliasName: 'meetings__id__task_updates_pending__meeting_id',
      );

  $$TaskUpdatesPendingTableProcessedTableManager get taskUpdatesPendingRefs {
    final manager = $$TaskUpdatesPendingTableTableManager(
      $_db,
      $_db.taskUpdatesPending,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskUpdatesPendingRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SpeakerMeetingNotesTable,
    List<SpeakerMeetingNoteRow>
  >
  _speakerMeetingNotesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.speakerMeetingNotes,
        aliasName: 'meetings__id__speaker_meeting_notes__meeting_id',
      );

  $$SpeakerMeetingNotesTableProcessedTableManager get speakerMeetingNotesRefs {
    final manager = $$SpeakerMeetingNotesTableTableManager(
      $_db,
      $_db.speakerMeetingNotes,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _speakerMeetingNotesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CodeFindingsTable, List<CodeFindingRow>>
  _codeFindingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.codeFindings,
    aliasName: 'meetings__id__code_findings__meeting_id',
  );

  $$CodeFindingsTableProcessedTableManager get codeFindingsRefs {
    final manager = $$CodeFindingsTableTableManager(
      $_db,
      $_db.codeFindings,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_codeFindingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minutesJson => $composableBuilder(
    column: $table.minutesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agendaJson => $composableBuilder(
    column: $table.agendaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedAttendeesJson => $composableBuilder(
    column: $table.expectedAttendeesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextNotes => $composableBuilder(
    column: $table.contextNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputDevice => $composableBuilder(
    column: $table.inputDevice,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> segmentsRefs(
    Expression<bool> Function($$SegmentsTableFilterComposer f) f,
  ) {
    final $$SegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableFilterComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> glossaryTermsRefs(
    Expression<bool> Function($$GlossaryTermsTableFilterComposer f) f,
  ) {
    final $$GlossaryTermsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.glossaryTerms,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GlossaryTermsTableFilterComposer(
            $db: $db,
            $table: $db.glossaryTerms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.sourceMeetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskUpdatesPendingRefs(
    Expression<bool> Function($$TaskUpdatesPendingTableFilterComposer f) f,
  ) {
    final $$TaskUpdatesPendingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskUpdatesPending,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskUpdatesPendingTableFilterComposer(
            $db: $db,
            $table: $db.taskUpdatesPending,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakerMeetingNotesRefs(
    Expression<bool> Function($$SpeakerMeetingNotesTableFilterComposer f) f,
  ) {
    final $$SpeakerMeetingNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakerMeetingNotes,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakerMeetingNotesTableFilterComposer(
            $db: $db,
            $table: $db.speakerMeetingNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> codeFindingsRefs(
    Expression<bool> Function($$CodeFindingsTableFilterComposer f) f,
  ) {
    final $$CodeFindingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.codeFindings,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CodeFindingsTableFilterComposer(
            $db: $db,
            $table: $db.codeFindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minutesJson => $composableBuilder(
    column: $table.minutesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agendaJson => $composableBuilder(
    column: $table.agendaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedAttendeesJson => $composableBuilder(
    column: $table.expectedAttendeesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextNotes => $composableBuilder(
    column: $table.contextNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputDevice => $composableBuilder(
    column: $table.inputDevice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get minutesJson => $composableBuilder(
    column: $table.minutesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agendaJson => $composableBuilder(
    column: $table.agendaJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expectedAttendeesJson => $composableBuilder(
    column: $table.expectedAttendeesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contextNotes => $composableBuilder(
    column: $table.contextNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => column);

  GeneratedColumn<String> get inputDevice => $composableBuilder(
    column: $table.inputDevice,
    builder: (column) => column,
  );

  Expression<T> segmentsRefs<T extends Object>(
    Expression<T> Function($$SegmentsTableAnnotationComposer a) f,
  ) {
    final $$SegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> glossaryTermsRefs<T extends Object>(
    Expression<T> Function($$GlossaryTermsTableAnnotationComposer a) f,
  ) {
    final $$GlossaryTermsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.glossaryTerms,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GlossaryTermsTableAnnotationComposer(
            $db: $db,
            $table: $db.glossaryTerms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.sourceMeetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskUpdatesPendingRefs<T extends Object>(
    Expression<T> Function($$TaskUpdatesPendingTableAnnotationComposer a) f,
  ) {
    final $$TaskUpdatesPendingTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.taskUpdatesPending,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskUpdatesPendingTableAnnotationComposer(
                $db: $db,
                $table: $db.taskUpdatesPending,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> speakerMeetingNotesRefs<T extends Object>(
    Expression<T> Function($$SpeakerMeetingNotesTableAnnotationComposer a) f,
  ) {
    final $$SpeakerMeetingNotesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.speakerMeetingNotes,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SpeakerMeetingNotesTableAnnotationComposer(
                $db: $db,
                $table: $db.speakerMeetingNotes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> codeFindingsRefs<T extends Object>(
    Expression<T> Function($$CodeFindingsTableAnnotationComposer a) f,
  ) {
    final $$CodeFindingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.codeFindings,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CodeFindingsTableAnnotationComposer(
            $db: $db,
            $table: $db.codeFindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingsTable,
          MeetingRow,
          $$MeetingsTableFilterComposer,
          $$MeetingsTableOrderingComposer,
          $$MeetingsTableAnnotationComposer,
          $$MeetingsTableCreateCompanionBuilder,
          $$MeetingsTableUpdateCompanionBuilder,
          (MeetingRow, $$MeetingsTableReferences),
          MeetingRow,
          PrefetchHooks Function({
            bool segmentsRefs,
            bool glossaryTermsRefs,
            bool tasksRefs,
            bool taskUpdatesPendingRefs,
            bool speakerMeetingNotesRefs,
            bool codeFindingsRefs,
          })
        > {
  $$MeetingsTableTableManager(_$AppDatabase db, $MeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> minutesJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> agendaJson = const Value.absent(),
                Value<String> expectedAttendeesJson = const Value.absent(),
                Value<String?> contextNotes = const Value.absent(),
                Value<String?> template = const Value.absent(),
                Value<String?> inputDevice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                status: status,
                durationMs: durationMs,
                audioPath: audioPath,
                minutesJson: minutesJson,
                errorMessage: errorMessage,
                agendaJson: agendaJson,
                expectedAttendeesJson: expectedAttendeesJson,
                contextNotes: contextNotes,
                template: template,
                inputDevice: inputDevice,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime createdAt,
                required String status,
                Value<int> durationMs = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> minutesJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> agendaJson = const Value.absent(),
                Value<String> expectedAttendeesJson = const Value.absent(),
                Value<String?> contextNotes = const Value.absent(),
                Value<String?> template = const Value.absent(),
                Value<String?> inputDevice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                status: status,
                durationMs: durationMs,
                audioPath: audioPath,
                minutesJson: minutesJson,
                errorMessage: errorMessage,
                agendaJson: agendaJson,
                expectedAttendeesJson: expectedAttendeesJson,
                contextNotes: contextNotes,
                template: template,
                inputDevice: inputDevice,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingsTable, MeetingRow>(table),
                  $$MeetingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                segmentsRefs = false,
                glossaryTermsRefs = false,
                tasksRefs = false,
                taskUpdatesPendingRefs = false,
                speakerMeetingNotesRefs = false,
                codeFindingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (segmentsRefs) db.segments,
                    if (glossaryTermsRefs) db.glossaryTerms,
                    if (tasksRefs) db.tasks,
                    if (taskUpdatesPendingRefs) db.taskUpdatesPending,
                    if (speakerMeetingNotesRefs) db.speakerMeetingNotes,
                    if (codeFindingsRefs) db.codeFindings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (segmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          SegmentRow,
                          $SegmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._segmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).segmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (glossaryTermsRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          GlossaryTermRow,
                          $GlossaryTermsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._glossaryTermsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).glossaryTermsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          TaskRow,
                          $TasksTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_meeting_id',
                          typedResults: items,
                        ),
                      if (taskUpdatesPendingRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          PendingTaskUpdateRow,
                          $TaskUpdatesPendingTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._taskUpdatesPendingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).taskUpdatesPendingRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (speakerMeetingNotesRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          SpeakerMeetingNoteRow,
                          $SpeakerMeetingNotesTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._speakerMeetingNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakerMeetingNotesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (codeFindingsRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          CodeFindingRow,
                          $CodeFindingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._codeFindingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).codeFindingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingsTable,
      MeetingRow,
      $$MeetingsTableFilterComposer,
      $$MeetingsTableOrderingComposer,
      $$MeetingsTableAnnotationComposer,
      $$MeetingsTableCreateCompanionBuilder,
      $$MeetingsTableUpdateCompanionBuilder,
      (MeetingRow, $$MeetingsTableReferences),
      MeetingRow,
      PrefetchHooks Function({
        bool segmentsRefs,
        bool glossaryTermsRefs,
        bool tasksRefs,
        bool taskUpdatesPendingRefs,
        bool speakerMeetingNotesRefs,
        bool codeFindingsRefs,
      })
    >;
typedef $$SegmentsTableCreateCompanionBuilder = SegmentsCompanion Function({
  required String id,
  required String meetingId,
  required int idx,
  required int startMs,
  required int endMs,
  required String body,
  Value<String?> speakerId,
  Value<String?> language,
  Value<Uint8List?> embedding,
  Value<bool> speakerLocked,
  Value<String> kind,
  Value<double?> asrConfidence,
  Value<double?> speakerConfidence,
  Value<int> rowid,
});
typedef $$SegmentsTableUpdateCompanionBuilder = SegmentsCompanion Function({
  Value<String> id,
  Value<String> meetingId,
  Value<int> idx,
  Value<int> startMs,
  Value<int> endMs,
  Value<String> body,
  Value<String?> speakerId,
  Value<String?> language,
  Value<Uint8List?> embedding,
  Value<bool> speakerLocked,
  Value<String> kind,
  Value<double?> asrConfidence,
  Value<double?> speakerConfidence,
  Value<int> rowid,
});

final class $$SegmentsTableReferences
    extends BaseReferences<_$AppDatabase, $SegmentsTable, SegmentRow> {
  $$SegmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('segments__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SpeakersTable _speakerIdTable(_$AppDatabase db) =>
      db.speakers.createAlias('segments__speaker_id__speakers__id');

  $$SpeakersTableProcessedTableManager? get speakerId {
    final $_column = $_itemColumn<String>('speaker_id');
    if ($_column == null) return null;
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_speakerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get speakerLocked => $composableBuilder(
    column: $table.speakerLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get asrConfidence => $composableBuilder(
    column: $table.asrConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speakerConfidence => $composableBuilder(
    column: $table.speakerConfidence,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableFilterComposer get speakerId {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get speakerLocked => $composableBuilder(
    column: $table.speakerLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get asrConfidence => $composableBuilder(
    column: $table.asrConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speakerConfidence => $composableBuilder(
    column: $table.speakerConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableOrderingComposer get speakerId {
    final $$SpeakersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableOrderingComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<bool> get speakerLocked => $composableBuilder(
    column: $table.speakerLocked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get asrConfidence => $composableBuilder(
    column: $table.asrConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<double> get speakerConfidence => $composableBuilder(
    column: $table.speakerConfidence,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableAnnotationComposer get speakerId {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SegmentsTable,
          SegmentRow,
          $$SegmentsTableFilterComposer,
          $$SegmentsTableOrderingComposer,
          $$SegmentsTableAnnotationComposer,
          $$SegmentsTableCreateCompanionBuilder,
          $$SegmentsTableUpdateCompanionBuilder,
          (SegmentRow, $$SegmentsTableReferences),
          SegmentRow,
          PrefetchHooks Function({bool meetingId, bool speakerId})
        > {
  $$SegmentsTableTableManager(_$AppDatabase db, $SegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<bool> speakerLocked = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double?> asrConfidence = const Value.absent(),
                Value<double?> speakerConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SegmentsCompanion(
                id: id,
                meetingId: meetingId,
                idx: idx,
                startMs: startMs,
                endMs: endMs,
                body: body,
                speakerId: speakerId,
                language: language,
                embedding: embedding,
                speakerLocked: speakerLocked,
                kind: kind,
                asrConfidence: asrConfidence,
                speakerConfidence: speakerConfidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                required int idx,
                required int startMs,
                required int endMs,
                required String body,
                Value<String?> speakerId = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<bool> speakerLocked = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double?> asrConfidence = const Value.absent(),
                Value<double?> speakerConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SegmentsCompanion.insert(
                id: id,
                meetingId: meetingId,
                idx: idx,
                startMs: startMs,
                endMs: endMs,
                body: body,
                speakerId: speakerId,
                language: language,
                embedding: embedding,
                speakerLocked: speakerLocked,
                kind: kind,
                asrConfidence: asrConfidence,
                speakerConfidence: speakerConfidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SegmentsTable, SegmentRow>(table),
                  $$SegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, speakerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$SegmentsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$SegmentsTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (speakerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.speakerId,
                        referencedTable: $$SegmentsTableReferences
                            ._speakerIdTable(db),
                        referencedColumn: $$SegmentsTableReferences
                            ._speakerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SegmentsTable,
      SegmentRow,
      $$SegmentsTableFilterComposer,
      $$SegmentsTableOrderingComposer,
      $$SegmentsTableAnnotationComposer,
      $$SegmentsTableCreateCompanionBuilder,
      $$SegmentsTableUpdateCompanionBuilder,
      (SegmentRow, $$SegmentsTableReferences),
      SegmentRow,
      PrefetchHooks Function({bool meetingId, bool speakerId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$GlossaryTermsTableCreateCompanionBuilder =
    GlossaryTermsCompanion Function({
      Value<int> id,
      required String term,
      Value<String?> arSpelling,
      Value<String> category,
      Value<String?> meetingId,
      required DateTime createdAt,
    });
typedef $$GlossaryTermsTableUpdateCompanionBuilder =
    GlossaryTermsCompanion Function({
      Value<int> id,
      Value<String> term,
      Value<String?> arSpelling,
      Value<String> category,
      Value<String?> meetingId,
      Value<DateTime> createdAt,
    });

final class $$GlossaryTermsTableReferences
    extends
        BaseReferences<_$AppDatabase, $GlossaryTermsTable, GlossaryTermRow> {
  $$GlossaryTermsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('glossary_terms__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager? get meetingId {
    final $_column = $_itemColumn<String>('meeting_id');
    if ($_column == null) return null;
    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GlossaryTermsTableFilterComposer
    extends Composer<_$AppDatabase, $GlossaryTermsTable> {
  $$GlossaryTermsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arSpelling => $composableBuilder(
    column: $table.arSpelling,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GlossaryTermsTableOrderingComposer
    extends Composer<_$AppDatabase, $GlossaryTermsTable> {
  $$GlossaryTermsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arSpelling => $composableBuilder(
    column: $table.arSpelling,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GlossaryTermsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GlossaryTermsTable> {
  $$GlossaryTermsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get arSpelling => $composableBuilder(
    column: $table.arSpelling,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GlossaryTermsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GlossaryTermsTable,
          GlossaryTermRow,
          $$GlossaryTermsTableFilterComposer,
          $$GlossaryTermsTableOrderingComposer,
          $$GlossaryTermsTableAnnotationComposer,
          $$GlossaryTermsTableCreateCompanionBuilder,
          $$GlossaryTermsTableUpdateCompanionBuilder,
          (GlossaryTermRow, $$GlossaryTermsTableReferences),
          GlossaryTermRow,
          PrefetchHooks Function({bool meetingId})
        > {
  $$GlossaryTermsTableTableManager(_$AppDatabase db, $GlossaryTermsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GlossaryTermsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GlossaryTermsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GlossaryTermsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> term = const Value.absent(),
                Value<String?> arSpelling = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> meetingId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GlossaryTermsCompanion(
                id: id,
                term: term,
                arSpelling: arSpelling,
                category: category,
                meetingId: meetingId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String term,
                Value<String?> arSpelling = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> meetingId = const Value.absent(),
                required DateTime createdAt,
              }) => GlossaryTermsCompanion.insert(
                id: id,
                term: term,
                arSpelling: arSpelling,
                category: category,
                meetingId: meetingId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GlossaryTermsTable, GlossaryTermRow>(table),
                  $$GlossaryTermsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$GlossaryTermsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$GlossaryTermsTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GlossaryTermsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GlossaryTermsTable,
      GlossaryTermRow,
      $$GlossaryTermsTableFilterComposer,
      $$GlossaryTermsTableOrderingComposer,
      $$GlossaryTermsTableAnnotationComposer,
      $$GlossaryTermsTableCreateCompanionBuilder,
      $$GlossaryTermsTableUpdateCompanionBuilder,
      (GlossaryTermRow, $$GlossaryTermsTableReferences),
      GlossaryTermRow,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  required String task,
  Value<String?> ownerSpeakerId,
  Value<String?> ownerText,
  Value<String?> dueText,
  Value<String> status,
  Value<String?> sourceMeetingId,
  Value<String> evidenceSegmentIds,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  Value<String> task,
  Value<String?> ownerSpeakerId,
  Value<String?> ownerText,
  Value<String?> dueText,
  Value<String> status,
  Value<String?> sourceMeetingId,
  Value<String> evidenceSegmentIds,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SpeakersTable _ownerSpeakerIdTable(_$AppDatabase db) =>
      db.speakers.createAlias('tasks__owner_speaker_id__speakers__id');

  $$SpeakersTableProcessedTableManager? get ownerSpeakerId {
    final $_column = $_itemColumn<String>('owner_speaker_id');
    if ($_column == null) return null;
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ownerSpeakerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MeetingsTable _sourceMeetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('tasks__source_meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager? get sourceMeetingId {
    final $_column = $_itemColumn<String>('source_meeting_id');
    if ($_column == null) return null;
    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceMeetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $TaskUpdatesPendingTable,
    List<PendingTaskUpdateRow>
  >
  _taskUpdatesPendingRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskUpdatesPending,
        aliasName: 'tasks__id__task_updates_pending__task_id',
      );

  $$TaskUpdatesPendingTableProcessedTableManager get taskUpdatesPendingRefs {
    final manager = $$TaskUpdatesPendingTableTableManager(
      $_db,
      $_db.taskUpdatesPending,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskUpdatesPendingRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get task => $composableBuilder(
    column: $table.task,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerText => $composableBuilder(
    column: $table.ownerText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueText => $composableBuilder(
    column: $table.dueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceSegmentIds => $composableBuilder(
    column: $table.evidenceSegmentIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$SpeakersTableFilterComposer get ownerSpeakerId {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerSpeakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableFilterComposer get sourceMeetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceMeetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskUpdatesPendingRefs(
    Expression<bool> Function($$TaskUpdatesPendingTableFilterComposer f) f,
  ) {
    final $$TaskUpdatesPendingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskUpdatesPending,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskUpdatesPendingTableFilterComposer(
            $db: $db,
            $table: $db.taskUpdatesPending,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get task => $composableBuilder(
    column: $table.task,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerText => $composableBuilder(
    column: $table.ownerText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueText => $composableBuilder(
    column: $table.dueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceSegmentIds => $composableBuilder(
    column: $table.evidenceSegmentIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SpeakersTableOrderingComposer get ownerSpeakerId {
    final $$SpeakersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerSpeakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableOrderingComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableOrderingComposer get sourceMeetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceMeetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get task =>
      $composableBuilder(column: $table.task, builder: (column) => column);

  GeneratedColumn<String> get ownerText =>
      $composableBuilder(column: $table.ownerText, builder: (column) => column);

  GeneratedColumn<String> get dueText =>
      $composableBuilder(column: $table.dueText, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get evidenceSegmentIds => $composableBuilder(
    column: $table.evidenceSegmentIds,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SpeakersTableAnnotationComposer get ownerSpeakerId {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerSpeakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableAnnotationComposer get sourceMeetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceMeetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskUpdatesPendingRefs<T extends Object>(
    Expression<T> Function($$TaskUpdatesPendingTableAnnotationComposer a) f,
  ) {
    final $$TaskUpdatesPendingTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.taskUpdatesPending,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskUpdatesPendingTableAnnotationComposer(
                $db: $db,
                $table: $db.taskUpdatesPending,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({
            bool ownerSpeakerId,
            bool sourceMeetingId,
            bool taskUpdatesPendingRefs,
          })
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> task = const Value.absent(),
                Value<String?> ownerSpeakerId = const Value.absent(),
                Value<String?> ownerText = const Value.absent(),
                Value<String?> dueText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sourceMeetingId = const Value.absent(),
                Value<String> evidenceSegmentIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                task: task,
                ownerSpeakerId: ownerSpeakerId,
                ownerText: ownerText,
                dueText: dueText,
                status: status,
                sourceMeetingId: sourceMeetingId,
                evidenceSegmentIds: evidenceSegmentIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String task,
                Value<String?> ownerSpeakerId = const Value.absent(),
                Value<String?> ownerText = const Value.absent(),
                Value<String?> dueText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sourceMeetingId = const Value.absent(),
                Value<String> evidenceSegmentIds = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TasksCompanion.insert(
                id: id,
                task: task,
                ownerSpeakerId: ownerSpeakerId,
                ownerText: ownerText,
                dueText: dueText,
                status: status,
                sourceMeetingId: sourceMeetingId,
                evidenceSegmentIds: evidenceSegmentIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  $$TasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ownerSpeakerId = false,
                sourceMeetingId = false,
                taskUpdatesPendingRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskUpdatesPendingRefs) db.taskUpdatesPending,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (ownerSpeakerId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.ownerSpeakerId,
                            referencedTable: $$TasksTableReferences
                                ._ownerSpeakerIdTable(db),
                            referencedColumn: $$TasksTableReferences
                                ._ownerSpeakerIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (sourceMeetingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceMeetingId,
                            referencedTable: $$TasksTableReferences
                                ._sourceMeetingIdTable(db),
                            referencedColumn: $$TasksTableReferences
                                ._sourceMeetingIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskUpdatesPendingRefs)
                        await $_getPrefetchedDataByColumns<
                          TaskRow,
                          $TasksTable,
                          PendingTaskUpdateRow,
                          $TaskUpdatesPendingTable
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskUpdatesPendingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskUpdatesPendingRefs,
                          currentColumn: 'id',
                          referencedColumn: 'task_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({
        bool ownerSpeakerId,
        bool sourceMeetingId,
        bool taskUpdatesPendingRefs,
      })
    >;
typedef $$TaskUpdatesPendingTableCreateCompanionBuilder =
    TaskUpdatesPendingCompanion Function({
      Value<int> id,
      required int taskId,
      required String meetingId,
      required String newStatus,
      Value<String?> note,
      Value<String> evidenceJson,
      required DateTime createdAt,
    });
typedef $$TaskUpdatesPendingTableUpdateCompanionBuilder =
    TaskUpdatesPendingCompanion Function({
      Value<int> id,
      Value<int> taskId,
      Value<String> meetingId,
      Value<String> newStatus,
      Value<String?> note,
      Value<String> evidenceJson,
      Value<DateTime> createdAt,
    });

final class $$TaskUpdatesPendingTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TaskUpdatesPendingTable,
          PendingTaskUpdateRow
        > {
  $$TaskUpdatesPendingTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_updates_pending__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('task_updates_pending__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskUpdatesPendingTableFilterComposer
    extends Composer<_$AppDatabase, $TaskUpdatesPendingTable> {
  $$TaskUpdatesPendingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newStatus => $composableBuilder(
    column: $table.newStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskUpdatesPendingTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskUpdatesPendingTable> {
  $$TaskUpdatesPendingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newStatus => $composableBuilder(
    column: $table.newStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskUpdatesPendingTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskUpdatesPendingTable> {
  $$TaskUpdatesPendingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get newStatus =>
      $composableBuilder(column: $table.newStatus, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskUpdatesPendingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskUpdatesPendingTable,
          PendingTaskUpdateRow,
          $$TaskUpdatesPendingTableFilterComposer,
          $$TaskUpdatesPendingTableOrderingComposer,
          $$TaskUpdatesPendingTableAnnotationComposer,
          $$TaskUpdatesPendingTableCreateCompanionBuilder,
          $$TaskUpdatesPendingTableUpdateCompanionBuilder,
          (PendingTaskUpdateRow, $$TaskUpdatesPendingTableReferences),
          PendingTaskUpdateRow,
          PrefetchHooks Function({bool taskId, bool meetingId})
        > {
  $$TaskUpdatesPendingTableTableManager(
    _$AppDatabase db,
    $TaskUpdatesPendingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskUpdatesPendingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskUpdatesPendingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskUpdatesPendingTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> newStatus = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> evidenceJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TaskUpdatesPendingCompanion(
                id: id,
                taskId: taskId,
                meetingId: meetingId,
                newStatus: newStatus,
                note: note,
                evidenceJson: evidenceJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int taskId,
                required String meetingId,
                required String newStatus,
                Value<String?> note = const Value.absent(),
                Value<String> evidenceJson = const Value.absent(),
                required DateTime createdAt,
              }) => TaskUpdatesPendingCompanion.insert(
                id: id,
                taskId: taskId,
                meetingId: meetingId,
                newStatus: newStatus,
                note: note,
                evidenceJson: evidenceJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskUpdatesPendingTable, PendingTaskUpdateRow>(
                    table,
                  ),
                  $$TaskUpdatesPendingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$TaskUpdatesPendingTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$TaskUpdatesPendingTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$TaskUpdatesPendingTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$TaskUpdatesPendingTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskUpdatesPendingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskUpdatesPendingTable,
      PendingTaskUpdateRow,
      $$TaskUpdatesPendingTableFilterComposer,
      $$TaskUpdatesPendingTableOrderingComposer,
      $$TaskUpdatesPendingTableAnnotationComposer,
      $$TaskUpdatesPendingTableCreateCompanionBuilder,
      $$TaskUpdatesPendingTableUpdateCompanionBuilder,
      (PendingTaskUpdateRow, $$TaskUpdatesPendingTableReferences),
      PendingTaskUpdateRow,
      PrefetchHooks Function({bool taskId, bool meetingId})
    >;
typedef $$SpeakerProfilesTableCreateCompanionBuilder =
    SpeakerProfilesCompanion Function({
      required String speakerId,
      required String profileJson,
      Value<String> evidenceJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SpeakerProfilesTableUpdateCompanionBuilder =
    SpeakerProfilesCompanion Function({
      Value<String> speakerId,
      Value<String> profileJson,
      Value<String> evidenceJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SpeakerProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SpeakerProfilesTable,
          SpeakerProfileRow
        > {
  $$SpeakerProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SpeakersTable _speakerIdTable(_$AppDatabase db) =>
      db.speakers.createAlias('speaker_profiles__speaker_id__speakers__id');

  $$SpeakersTableProcessedTableManager get speakerId {
    final $_column = $_itemColumn<String>('speaker_id')!;

    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_speakerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpeakerProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $SpeakerProfilesTable> {
  $$SpeakerProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$SpeakersTableFilterComposer get speakerId {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeakerProfilesTable> {
  $$SpeakerProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SpeakersTableOrderingComposer get speakerId {
    final $$SpeakersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableOrderingComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeakerProfilesTable> {
  $$SpeakerProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SpeakersTableAnnotationComposer get speakerId {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeakerProfilesTable,
          SpeakerProfileRow,
          $$SpeakerProfilesTableFilterComposer,
          $$SpeakerProfilesTableOrderingComposer,
          $$SpeakerProfilesTableAnnotationComposer,
          $$SpeakerProfilesTableCreateCompanionBuilder,
          $$SpeakerProfilesTableUpdateCompanionBuilder,
          (SpeakerProfileRow, $$SpeakerProfilesTableReferences),
          SpeakerProfileRow,
          PrefetchHooks Function({bool speakerId})
        > {
  $$SpeakerProfilesTableTableManager(
    _$AppDatabase db,
    $SpeakerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeakerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> speakerId = const Value.absent(),
                Value<String> profileJson = const Value.absent(),
                Value<String> evidenceJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakerProfilesCompanion(
                speakerId: speakerId,
                profileJson: profileJson,
                evidenceJson: evidenceJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String speakerId,
                required String profileJson,
                Value<String> evidenceJson = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SpeakerProfilesCompanion.insert(
                speakerId: speakerId,
                profileJson: profileJson,
                evidenceJson: evidenceJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakerProfilesTable, SpeakerProfileRow>(table),
                  $$SpeakerProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({speakerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (speakerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.speakerId,
                        referencedTable: $$SpeakerProfilesTableReferences
                            ._speakerIdTable(db),
                        referencedColumn: $$SpeakerProfilesTableReferences
                            ._speakerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpeakerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeakerProfilesTable,
      SpeakerProfileRow,
      $$SpeakerProfilesTableFilterComposer,
      $$SpeakerProfilesTableOrderingComposer,
      $$SpeakerProfilesTableAnnotationComposer,
      $$SpeakerProfilesTableCreateCompanionBuilder,
      $$SpeakerProfilesTableUpdateCompanionBuilder,
      (SpeakerProfileRow, $$SpeakerProfilesTableReferences),
      SpeakerProfileRow,
      PrefetchHooks Function({bool speakerId})
    >;
typedef $$SpeakerMeetingNotesTableCreateCompanionBuilder =
    SpeakerMeetingNotesCompanion Function({
      required String speakerId,
      required String meetingId,
      required String notesJson,
      Value<int> rowid,
    });
typedef $$SpeakerMeetingNotesTableUpdateCompanionBuilder =
    SpeakerMeetingNotesCompanion Function({
      Value<String> speakerId,
      Value<String> meetingId,
      Value<String> notesJson,
      Value<int> rowid,
    });

final class $$SpeakerMeetingNotesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SpeakerMeetingNotesTable,
          SpeakerMeetingNoteRow
        > {
  $$SpeakerMeetingNotesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SpeakersTable _speakerIdTable(_$AppDatabase db) => db.speakers
      .createAlias('speaker_meeting_notes__speaker_id__speakers__id');

  $$SpeakersTableProcessedTableManager get speakerId {
    final $_column = $_itemColumn<String>('speaker_id')!;

    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_speakerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) => db.meetings
      .createAlias('speaker_meeting_notes__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpeakerMeetingNotesTableFilterComposer
    extends Composer<_$AppDatabase, $SpeakerMeetingNotesTable> {
  $$SpeakerMeetingNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get notesJson => $composableBuilder(
    column: $table.notesJson,
    builder: (column) => ColumnFilters(column),
  );

  $$SpeakersTableFilterComposer get speakerId {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerMeetingNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeakerMeetingNotesTable> {
  $$SpeakerMeetingNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get notesJson => $composableBuilder(
    column: $table.notesJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$SpeakersTableOrderingComposer get speakerId {
    final $$SpeakersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableOrderingComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerMeetingNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeakerMeetingNotesTable> {
  $$SpeakerMeetingNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get notesJson =>
      $composableBuilder(column: $table.notesJson, builder: (column) => column);

  $$SpeakersTableAnnotationComposer get speakerId {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerMeetingNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeakerMeetingNotesTable,
          SpeakerMeetingNoteRow,
          $$SpeakerMeetingNotesTableFilterComposer,
          $$SpeakerMeetingNotesTableOrderingComposer,
          $$SpeakerMeetingNotesTableAnnotationComposer,
          $$SpeakerMeetingNotesTableCreateCompanionBuilder,
          $$SpeakerMeetingNotesTableUpdateCompanionBuilder,
          (SpeakerMeetingNoteRow, $$SpeakerMeetingNotesTableReferences),
          SpeakerMeetingNoteRow,
          PrefetchHooks Function({bool speakerId, bool meetingId})
        > {
  $$SpeakerMeetingNotesTableTableManager(
    _$AppDatabase db,
    $SpeakerMeetingNotesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakerMeetingNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakerMeetingNotesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SpeakerMeetingNotesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> speakerId = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> notesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakerMeetingNotesCompanion(
                speakerId: speakerId,
                meetingId: meetingId,
                notesJson: notesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String speakerId,
                required String meetingId,
                required String notesJson,
                Value<int> rowid = const Value.absent(),
              }) => SpeakerMeetingNotesCompanion.insert(
                speakerId: speakerId,
                meetingId: meetingId,
                notesJson: notesJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakerMeetingNotesTable, SpeakerMeetingNoteRow>(
                    table,
                  ),
                  $$SpeakerMeetingNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({speakerId = false, meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (speakerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.speakerId,
                        referencedTable: $$SpeakerMeetingNotesTableReferences
                            ._speakerIdTable(db),
                        referencedColumn: $$SpeakerMeetingNotesTableReferences
                            ._speakerIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$SpeakerMeetingNotesTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$SpeakerMeetingNotesTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpeakerMeetingNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeakerMeetingNotesTable,
      SpeakerMeetingNoteRow,
      $$SpeakerMeetingNotesTableFilterComposer,
      $$SpeakerMeetingNotesTableOrderingComposer,
      $$SpeakerMeetingNotesTableAnnotationComposer,
      $$SpeakerMeetingNotesTableCreateCompanionBuilder,
      $$SpeakerMeetingNotesTableUpdateCompanionBuilder,
      (SpeakerMeetingNoteRow, $$SpeakerMeetingNotesTableReferences),
      SpeakerMeetingNoteRow,
      PrefetchHooks Function({bool speakerId, bool meetingId})
    >;
typedef $$CodeFindingsTableCreateCompanionBuilder =
    CodeFindingsCompanion Function({
      Value<int> id,
      required String meetingId,
      required String kind,
      Value<String?> speakerId,
      Value<String> segmentIdsJson,
      required String payloadJson,
      required DateTime createdAt,
    });
typedef $$CodeFindingsTableUpdateCompanionBuilder =
    CodeFindingsCompanion Function({
      Value<int> id,
      Value<String> meetingId,
      Value<String> kind,
      Value<String?> speakerId,
      Value<String> segmentIdsJson,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
    });

final class $$CodeFindingsTableReferences
    extends BaseReferences<_$AppDatabase, $CodeFindingsTable, CodeFindingRow> {
  $$CodeFindingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('code_findings__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SpeakersTable _speakerIdTable(_$AppDatabase db) =>
      db.speakers.createAlias('code_findings__speaker_id__speakers__id');

  $$SpeakersTableProcessedTableManager? get speakerId {
    final $_column = $_itemColumn<String>('speaker_id');
    if ($_column == null) return null;
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_speakerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CodeFindingsTableFilterComposer
    extends Composer<_$AppDatabase, $CodeFindingsTable> {
  $$CodeFindingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentIdsJson => $composableBuilder(
    column: $table.segmentIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableFilterComposer get speakerId {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CodeFindingsTableOrderingComposer
    extends Composer<_$AppDatabase, $CodeFindingsTable> {
  $$CodeFindingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentIdsJson => $composableBuilder(
    column: $table.segmentIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableOrderingComposer get speakerId {
    final $$SpeakersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableOrderingComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CodeFindingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CodeFindingsTable> {
  $$CodeFindingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get segmentIdsJson => $composableBuilder(
    column: $table.segmentIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableAnnotationComposer get speakerId {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CodeFindingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CodeFindingsTable,
          CodeFindingRow,
          $$CodeFindingsTableFilterComposer,
          $$CodeFindingsTableOrderingComposer,
          $$CodeFindingsTableAnnotationComposer,
          $$CodeFindingsTableCreateCompanionBuilder,
          $$CodeFindingsTableUpdateCompanionBuilder,
          (CodeFindingRow, $$CodeFindingsTableReferences),
          CodeFindingRow,
          PrefetchHooks Function({bool meetingId, bool speakerId})
        > {
  $$CodeFindingsTableTableManager(_$AppDatabase db, $CodeFindingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CodeFindingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CodeFindingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CodeFindingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<String> segmentIdsJson = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CodeFindingsCompanion(
                id: id,
                meetingId: meetingId,
                kind: kind,
                speakerId: speakerId,
                segmentIdsJson: segmentIdsJson,
                payloadJson: payloadJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String meetingId,
                required String kind,
                Value<String?> speakerId = const Value.absent(),
                Value<String> segmentIdsJson = const Value.absent(),
                required String payloadJson,
                required DateTime createdAt,
              }) => CodeFindingsCompanion.insert(
                id: id,
                meetingId: meetingId,
                kind: kind,
                speakerId: speakerId,
                segmentIdsJson: segmentIdsJson,
                payloadJson: payloadJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CodeFindingsTable, CodeFindingRow>(table),
                  $$CodeFindingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, speakerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$CodeFindingsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$CodeFindingsTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (speakerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.speakerId,
                        referencedTable: $$CodeFindingsTableReferences
                            ._speakerIdTable(db),
                        referencedColumn: $$CodeFindingsTableReferences
                            ._speakerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CodeFindingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CodeFindingsTable,
      CodeFindingRow,
      $$CodeFindingsTableFilterComposer,
      $$CodeFindingsTableOrderingComposer,
      $$CodeFindingsTableAnnotationComposer,
      $$CodeFindingsTableCreateCompanionBuilder,
      $$CodeFindingsTableUpdateCompanionBuilder,
      (CodeFindingRow, $$CodeFindingsTableReferences),
      CodeFindingRow,
      PrefetchHooks Function({bool meetingId, bool speakerId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SpeakersTableTableManager get speakers =>
      $$SpeakersTableTableManager(_db, _db.speakers);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db, _db.meetings);
  $$SegmentsTableTableManager get segments =>
      $$SegmentsTableTableManager(_db, _db.segments);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$GlossaryTermsTableTableManager get glossaryTerms =>
      $$GlossaryTermsTableTableManager(_db, _db.glossaryTerms);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TaskUpdatesPendingTableTableManager get taskUpdatesPending =>
      $$TaskUpdatesPendingTableTableManager(_db, _db.taskUpdatesPending);
  $$SpeakerProfilesTableTableManager get speakerProfiles =>
      $$SpeakerProfilesTableTableManager(_db, _db.speakerProfiles);
  $$SpeakerMeetingNotesTableTableManager get speakerMeetingNotes =>
      $$SpeakerMeetingNotesTableTableManager(_db, _db.speakerMeetingNotes);
  $$CodeFindingsTableTableManager get codeFindings =>
      $$CodeFindingsTableTableManager(_db, _db.codeFindings);
}
