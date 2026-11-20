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

class $TaskDismissalsTable extends TaskDismissals
    with TableInfo<$TaskDismissalsTable, TaskDismissalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskDismissalsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
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
      ).withConverter<DateTime>($TaskDismissalsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [meetingId, kind, itemKey, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_dismissals';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskDismissalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {meetingId, kind, itemKey};
  @override
  TaskDismissalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskDismissalRow(
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      createdAt: $TaskDismissalsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $TaskDismissalsTable createAlias(String alias) {
    return $TaskDismissalsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class TaskDismissalRow extends DataClass
    implements Insertable<TaskDismissalRow> {
  /// Meeting whose minutes proposed the item.
  final String meetingId;

  /// `task` or `update`.
  final String kind;

  /// Dismissed item key (see the class comment).
  final String itemKey;

  /// When it was dismissed (UTC epoch milliseconds in SQL).
  final DateTime createdAt;
  const TaskDismissalRow({
    required this.meetingId,
    required this.kind,
    required this.itemKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meeting_id'] = Variable<String>(meetingId);
    map['kind'] = Variable<String>(kind);
    map['item_key'] = Variable<String>(itemKey);
    {
      map['created_at'] = Variable<int>(
        $TaskDismissalsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  TaskDismissalsCompanion toCompanion(bool nullToAbsent) {
    return TaskDismissalsCompanion(
      meetingId: Value(meetingId),
      kind: Value(kind),
      itemKey: Value(itemKey),
      createdAt: Value(createdAt),
    );
  }

  factory TaskDismissalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskDismissalRow(
      meetingId: serializer.fromJson<String>(json['meetingId']),
      kind: serializer.fromJson<String>(json['kind']),
      itemKey: serializer.fromJson<String>(json['itemKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'meetingId': serializer.toJson<String>(meetingId),
      'kind': serializer.toJson<String>(kind),
      'itemKey': serializer.toJson<String>(itemKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TaskDismissalRow copyWith({
    String? meetingId,
    String? kind,
    String? itemKey,
    DateTime? createdAt,
  }) => TaskDismissalRow(
    meetingId: meetingId ?? this.meetingId,
    kind: kind ?? this.kind,
    itemKey: itemKey ?? this.itemKey,
    createdAt: createdAt ?? this.createdAt,
  );
  TaskDismissalRow copyWithCompanion(TaskDismissalsCompanion data) {
    return TaskDismissalRow(
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      kind: data.kind.present ? data.kind.value : this.kind,
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskDismissalRow(')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('itemKey: $itemKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(meetingId, kind, itemKey, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskDismissalRow &&
          other.meetingId == this.meetingId &&
          other.kind == this.kind &&
          other.itemKey == this.itemKey &&
          other.createdAt == this.createdAt);
}

class TaskDismissalsCompanion extends UpdateCompanion<TaskDismissalRow> {
  final Value<String> meetingId;
  final Value<String> kind;
  final Value<String> itemKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TaskDismissalsCompanion({
    this.meetingId = const Value.absent(),
    this.kind = const Value.absent(),
    this.itemKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskDismissalsCompanion.insert({
    required String meetingId,
    required String kind,
    required String itemKey,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : meetingId = Value(meetingId),
       kind = Value(kind),
       itemKey = Value(itemKey),
       createdAt = Value(createdAt);
  static Insertable<TaskDismissalRow> custom({
    Expression<String>? meetingId,
    Expression<String>? kind,
    Expression<String>? itemKey,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (meetingId != null) 'meeting_id': meetingId,
      if (kind != null) 'kind': kind,
      if (itemKey != null) 'item_key': itemKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskDismissalsCompanion copyWith({
    Value<String>? meetingId,
    Value<String>? kind,
    Value<String>? itemKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TaskDismissalsCompanion(
      meetingId: meetingId ?? this.meetingId,
      kind: kind ?? this.kind,
      itemKey: itemKey ?? this.itemKey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $TaskDismissalsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskDismissalsCompanion(')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('itemKey: $itemKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfficialRecordsTable extends OfficialRecords
    with TableInfo<$OfficialRecordsTable, OfficialRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfficialRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityKeyMeta = const VerificationMeta(
    'entityKey',
  );
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'entity_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _committeeMeta = const VerificationMeta(
    'committee',
  );
  @override
  late final GeneratedColumn<String> committee = GeneratedColumn<String>(
    'committee',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _numberYearMeta = const VerificationMeta(
    'numberYear',
  );
  @override
  late final GeneratedColumn<int> numberYear = GeneratedColumn<int>(
    'number_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meetingNumberMeta = const VerificationMeta(
    'meetingNumber',
  );
  @override
  late final GeneratedColumn<int> meetingNumber = GeneratedColumn<int>(
    'meeting_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _recordJsonMeta = const VerificationMeta(
    'recordJson',
  );
  @override
  late final GeneratedColumn<String> recordJson = GeneratedColumn<String>(
    'record_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($OfficialRecordsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    meetingId,
    entityKey,
    committee,
    numberYear,
    meetingNumber,
    status,
    version,
    recordJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'official_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfficialRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('entity_key')) {
      context.handle(
        _entityKeyMeta,
        entityKey.isAcceptableOrUnknown(data['entity_key']!, _entityKeyMeta),
      );
    }
    if (data.containsKey('committee')) {
      context.handle(
        _committeeMeta,
        committee.isAcceptableOrUnknown(data['committee']!, _committeeMeta),
      );
    }
    if (data.containsKey('number_year')) {
      context.handle(
        _numberYearMeta,
        numberYear.isAcceptableOrUnknown(data['number_year']!, _numberYearMeta),
      );
    }
    if (data.containsKey('meeting_number')) {
      context.handle(
        _meetingNumberMeta,
        meetingNumber.isAcceptableOrUnknown(
          data['meeting_number']!,
          _meetingNumberMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('record_json')) {
      context.handle(
        _recordJsonMeta,
        recordJson.isAcceptableOrUnknown(data['record_json']!, _recordJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_recordJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {meetingId};
  @override
  OfficialRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfficialRecordRow(
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      entityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_key'],
      )!,
      committee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}committee'],
      )!,
      numberYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number_year'],
      ),
      meetingNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_number'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      recordJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_json'],
      )!,
      updatedAt: $OfficialRecordsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $OfficialRecordsTable createAlias(String alias) {
    return $OfficialRecordsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMillisConverter();
}

class OfficialRecordRow extends DataClass
    implements Insertable<OfficialRecordRow> {
  /// Meeting; deleted with the meeting.
  final String meetingId;

  /// Normalised entity name at numbering time.
  final String entityKey;

  /// Normalised committee name ('' = none).
  final String committee;

  /// Year of the meeting number (Hijri or Gregorian).
  final int? numberYear;

  /// Meeting number within entity / committee / year.
  final int? meetingNumber;

  /// `OfficialStatus.name`.
  final String status;

  /// Current version (1-based).
  final int version;

  /// `OfficialRecord.toJson()`.
  final String recordJson;

  /// Last update (UTC epoch milliseconds in SQL).
  final DateTime updatedAt;
  const OfficialRecordRow({
    required this.meetingId,
    required this.entityKey,
    required this.committee,
    this.numberYear,
    this.meetingNumber,
    required this.status,
    required this.version,
    required this.recordJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meeting_id'] = Variable<String>(meetingId);
    map['entity_key'] = Variable<String>(entityKey);
    map['committee'] = Variable<String>(committee);
    if (!nullToAbsent || numberYear != null) {
      map['number_year'] = Variable<int>(numberYear);
    }
    if (!nullToAbsent || meetingNumber != null) {
      map['meeting_number'] = Variable<int>(meetingNumber);
    }
    map['status'] = Variable<String>(status);
    map['version'] = Variable<int>(version);
    map['record_json'] = Variable<String>(recordJson);
    {
      map['updated_at'] = Variable<int>(
        $OfficialRecordsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  OfficialRecordsCompanion toCompanion(bool nullToAbsent) {
    return OfficialRecordsCompanion(
      meetingId: Value(meetingId),
      entityKey: Value(entityKey),
      committee: Value(committee),
      numberYear: numberYear == null && nullToAbsent
          ? const Value.absent()
          : Value(numberYear),
      meetingNumber: meetingNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(meetingNumber),
      status: Value(status),
      version: Value(version),
      recordJson: Value(recordJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory OfficialRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfficialRecordRow(
      meetingId: serializer.fromJson<String>(json['meetingId']),
      entityKey: serializer.fromJson<String>(json['entityKey']),
      committee: serializer.fromJson<String>(json['committee']),
      numberYear: serializer.fromJson<int?>(json['numberYear']),
      meetingNumber: serializer.fromJson<int?>(json['meetingNumber']),
      status: serializer.fromJson<String>(json['status']),
      version: serializer.fromJson<int>(json['version']),
      recordJson: serializer.fromJson<String>(json['recordJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'meetingId': serializer.toJson<String>(meetingId),
      'entityKey': serializer.toJson<String>(entityKey),
      'committee': serializer.toJson<String>(committee),
      'numberYear': serializer.toJson<int?>(numberYear),
      'meetingNumber': serializer.toJson<int?>(meetingNumber),
      'status': serializer.toJson<String>(status),
      'version': serializer.toJson<int>(version),
      'recordJson': serializer.toJson<String>(recordJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OfficialRecordRow copyWith({
    String? meetingId,
    String? entityKey,
    String? committee,
    Value<int?> numberYear = const Value.absent(),
    Value<int?> meetingNumber = const Value.absent(),
    String? status,
    int? version,
    String? recordJson,
    DateTime? updatedAt,
  }) => OfficialRecordRow(
    meetingId: meetingId ?? this.meetingId,
    entityKey: entityKey ?? this.entityKey,
    committee: committee ?? this.committee,
    numberYear: numberYear.present ? numberYear.value : this.numberYear,
    meetingNumber: meetingNumber.present
        ? meetingNumber.value
        : this.meetingNumber,
    status: status ?? this.status,
    version: version ?? this.version,
    recordJson: recordJson ?? this.recordJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OfficialRecordRow copyWithCompanion(OfficialRecordsCompanion data) {
    return OfficialRecordRow(
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      committee: data.committee.present ? data.committee.value : this.committee,
      numberYear: data.numberYear.present
          ? data.numberYear.value
          : this.numberYear,
      meetingNumber: data.meetingNumber.present
          ? data.meetingNumber.value
          : this.meetingNumber,
      status: data.status.present ? data.status.value : this.status,
      version: data.version.present ? data.version.value : this.version,
      recordJson: data.recordJson.present
          ? data.recordJson.value
          : this.recordJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfficialRecordRow(')
          ..write('meetingId: $meetingId, ')
          ..write('entityKey: $entityKey, ')
          ..write('committee: $committee, ')
          ..write('numberYear: $numberYear, ')
          ..write('meetingNumber: $meetingNumber, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('recordJson: $recordJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    meetingId,
    entityKey,
    committee,
    numberYear,
    meetingNumber,
    status,
    version,
    recordJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfficialRecordRow &&
          other.meetingId == this.meetingId &&
          other.entityKey == this.entityKey &&
          other.committee == this.committee &&
          other.numberYear == this.numberYear &&
          other.meetingNumber == this.meetingNumber &&
          other.status == this.status &&
          other.version == this.version &&
          other.recordJson == this.recordJson &&
          other.updatedAt == this.updatedAt);
}

class OfficialRecordsCompanion extends UpdateCompanion<OfficialRecordRow> {
  final Value<String> meetingId;
  final Value<String> entityKey;
  final Value<String> committee;
  final Value<int?> numberYear;
  final Value<int?> meetingNumber;
  final Value<String> status;
  final Value<int> version;
  final Value<String> recordJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OfficialRecordsCompanion({
    this.meetingId = const Value.absent(),
    this.entityKey = const Value.absent(),
    this.committee = const Value.absent(),
    this.numberYear = const Value.absent(),
    this.meetingNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.recordJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfficialRecordsCompanion.insert({
    required String meetingId,
    this.entityKey = const Value.absent(),
    this.committee = const Value.absent(),
    this.numberYear = const Value.absent(),
    this.meetingNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    required String recordJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : meetingId = Value(meetingId),
       recordJson = Value(recordJson),
       updatedAt = Value(updatedAt);
  static Insertable<OfficialRecordRow> custom({
    Expression<String>? meetingId,
    Expression<String>? entityKey,
    Expression<String>? committee,
    Expression<int>? numberYear,
    Expression<int>? meetingNumber,
    Expression<String>? status,
    Expression<int>? version,
    Expression<String>? recordJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (meetingId != null) 'meeting_id': meetingId,
      if (entityKey != null) 'entity_key': entityKey,
      if (committee != null) 'committee': committee,
      if (numberYear != null) 'number_year': numberYear,
      if (meetingNumber != null) 'meeting_number': meetingNumber,
      if (status != null) 'status': status,
      if (version != null) 'version': version,
      if (recordJson != null) 'record_json': recordJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfficialRecordsCompanion copyWith({
    Value<String>? meetingId,
    Value<String>? entityKey,
    Value<String>? committee,
    Value<int?>? numberYear,
    Value<int?>? meetingNumber,
    Value<String>? status,
    Value<int>? version,
    Value<String>? recordJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OfficialRecordsCompanion(
      meetingId: meetingId ?? this.meetingId,
      entityKey: entityKey ?? this.entityKey,
      committee: committee ?? this.committee,
      numberYear: numberYear ?? this.numberYear,
      meetingNumber: meetingNumber ?? this.meetingNumber,
      status: status ?? this.status,
      version: version ?? this.version,
      recordJson: recordJson ?? this.recordJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
    }
    if (committee.present) {
      map['committee'] = Variable<String>(committee.value);
    }
    if (numberYear.present) {
      map['number_year'] = Variable<int>(numberYear.value);
    }
    if (meetingNumber.present) {
      map['meeting_number'] = Variable<int>(meetingNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (recordJson.present) {
      map['record_json'] = Variable<String>(recordJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $OfficialRecordsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfficialRecordsCompanion(')
          ..write('meetingId: $meetingId, ')
          ..write('entityKey: $entityKey, ')
          ..write('committee: $committee, ')
          ..write('numberYear: $numberYear, ')
          ..write('meetingNumber: $meetingNumber, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('recordJson: $recordJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MinutesVersionsTable extends MinutesVersions
    with TableInfo<$MinutesVersionsTable, MinutesVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MinutesVersionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minutesJsonMeta = const VerificationMeta(
    'minutesJson',
  );
  @override
  late final GeneratedColumn<String> minutesJson = GeneratedColumn<String>(
    'minutes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordJsonMeta = const VerificationMeta(
    'recordJson',
  );
  @override
  late final GeneratedColumn<String> recordJson = GeneratedColumn<String>(
    'record_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> approvedAt =
      GeneratedColumn<int>(
        'approved_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MinutesVersionsTable.$converterapprovedAt);
  @override
  List<GeneratedColumn> get $columns => [
    meetingId,
    version,
    minutesJson,
    recordJson,
    contentHash,
    approvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'minutes_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MinutesVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('minutes_json')) {
      context.handle(
        _minutesJsonMeta,
        minutesJson.isAcceptableOrUnknown(
          data['minutes_json']!,
          _minutesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minutesJsonMeta);
    }
    if (data.containsKey('record_json')) {
      context.handle(
        _recordJsonMeta,
        recordJson.isAcceptableOrUnknown(data['record_json']!, _recordJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_recordJsonMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {meetingId, version};
  @override
  MinutesVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MinutesVersionRow(
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      minutesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}minutes_json'],
      )!,
      recordJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_json'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      approvedAt: $MinutesVersionsTable.$converterapprovedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}approved_at'],
        )!,
      ),
    );
  }

  @override
  $MinutesVersionsTable createAlias(String alias) {
    return $MinutesVersionsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterapprovedAt =
      const EpochMillisConverter();
}

class MinutesVersionRow extends DataClass
    implements Insertable<MinutesVersionRow> {
  /// Meeting; deleted with the meeting.
  final String meetingId;

  /// Version number.
  final int version;

  /// `Minutes.toJson()` as approved.
  final String minutesJson;

  /// `OfficialRecord.toJson()` as approved.
  final String recordJson;

  /// SHA-256 of the canonical approved content.
  final String contentHash;

  /// Approval time (UTC epoch milliseconds in SQL).
  final DateTime approvedAt;
  const MinutesVersionRow({
    required this.meetingId,
    required this.version,
    required this.minutesJson,
    required this.recordJson,
    required this.contentHash,
    required this.approvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meeting_id'] = Variable<String>(meetingId);
    map['version'] = Variable<int>(version);
    map['minutes_json'] = Variable<String>(minutesJson);
    map['record_json'] = Variable<String>(recordJson);
    map['content_hash'] = Variable<String>(contentHash);
    {
      map['approved_at'] = Variable<int>(
        $MinutesVersionsTable.$converterapprovedAt.toSql(approvedAt),
      );
    }
    return map;
  }

  MinutesVersionsCompanion toCompanion(bool nullToAbsent) {
    return MinutesVersionsCompanion(
      meetingId: Value(meetingId),
      version: Value(version),
      minutesJson: Value(minutesJson),
      recordJson: Value(recordJson),
      contentHash: Value(contentHash),
      approvedAt: Value(approvedAt),
    );
  }

  factory MinutesVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MinutesVersionRow(
      meetingId: serializer.fromJson<String>(json['meetingId']),
      version: serializer.fromJson<int>(json['version']),
      minutesJson: serializer.fromJson<String>(json['minutesJson']),
      recordJson: serializer.fromJson<String>(json['recordJson']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      approvedAt: serializer.fromJson<DateTime>(json['approvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'meetingId': serializer.toJson<String>(meetingId),
      'version': serializer.toJson<int>(version),
      'minutesJson': serializer.toJson<String>(minutesJson),
      'recordJson': serializer.toJson<String>(recordJson),
      'contentHash': serializer.toJson<String>(contentHash),
      'approvedAt': serializer.toJson<DateTime>(approvedAt),
    };
  }

  MinutesVersionRow copyWith({
    String? meetingId,
    int? version,
    String? minutesJson,
    String? recordJson,
    String? contentHash,
    DateTime? approvedAt,
  }) => MinutesVersionRow(
    meetingId: meetingId ?? this.meetingId,
    version: version ?? this.version,
    minutesJson: minutesJson ?? this.minutesJson,
    recordJson: recordJson ?? this.recordJson,
    contentHash: contentHash ?? this.contentHash,
    approvedAt: approvedAt ?? this.approvedAt,
  );
  MinutesVersionRow copyWithCompanion(MinutesVersionsCompanion data) {
    return MinutesVersionRow(
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      version: data.version.present ? data.version.value : this.version,
      minutesJson: data.minutesJson.present
          ? data.minutesJson.value
          : this.minutesJson,
      recordJson: data.recordJson.present
          ? data.recordJson.value
          : this.recordJson,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MinutesVersionRow(')
          ..write('meetingId: $meetingId, ')
          ..write('version: $version, ')
          ..write('minutesJson: $minutesJson, ')
          ..write('recordJson: $recordJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('approvedAt: $approvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    meetingId,
    version,
    minutesJson,
    recordJson,
    contentHash,
    approvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MinutesVersionRow &&
          other.meetingId == this.meetingId &&
          other.version == this.version &&
          other.minutesJson == this.minutesJson &&
          other.recordJson == this.recordJson &&
          other.contentHash == this.contentHash &&
          other.approvedAt == this.approvedAt);
}

class MinutesVersionsCompanion extends UpdateCompanion<MinutesVersionRow> {
  final Value<String> meetingId;
  final Value<int> version;
  final Value<String> minutesJson;
  final Value<String> recordJson;
  final Value<String> contentHash;
  final Value<DateTime> approvedAt;
  final Value<int> rowid;
  const MinutesVersionsCompanion({
    this.meetingId = const Value.absent(),
    this.version = const Value.absent(),
    this.minutesJson = const Value.absent(),
    this.recordJson = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MinutesVersionsCompanion.insert({
    required String meetingId,
    required int version,
    required String minutesJson,
    required String recordJson,
    required String contentHash,
    required DateTime approvedAt,
    this.rowid = const Value.absent(),
  }) : meetingId = Value(meetingId),
       version = Value(version),
       minutesJson = Value(minutesJson),
       recordJson = Value(recordJson),
       contentHash = Value(contentHash),
       approvedAt = Value(approvedAt);
  static Insertable<MinutesVersionRow> custom({
    Expression<String>? meetingId,
    Expression<int>? version,
    Expression<String>? minutesJson,
    Expression<String>? recordJson,
    Expression<String>? contentHash,
    Expression<int>? approvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (meetingId != null) 'meeting_id': meetingId,
      if (version != null) 'version': version,
      if (minutesJson != null) 'minutes_json': minutesJson,
      if (recordJson != null) 'record_json': recordJson,
      if (contentHash != null) 'content_hash': contentHash,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MinutesVersionsCompanion copyWith({
    Value<String>? meetingId,
    Value<int>? version,
    Value<String>? minutesJson,
    Value<String>? recordJson,
    Value<String>? contentHash,
    Value<DateTime>? approvedAt,
    Value<int>? rowid,
  }) {
    return MinutesVersionsCompanion(
      meetingId: meetingId ?? this.meetingId,
      version: version ?? this.version,
      minutesJson: minutesJson ?? this.minutesJson,
      recordJson: recordJson ?? this.recordJson,
      contentHash: contentHash ?? this.contentHash,
      approvedAt: approvedAt ?? this.approvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (minutesJson.present) {
      map['minutes_json'] = Variable<String>(minutesJson.value);
    }
    if (recordJson.present) {
      map['record_json'] = Variable<String>(recordJson.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<int>(
        $MinutesVersionsTable.$converterapprovedAt.toSql(approvedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MinutesVersionsCompanion(')
          ..write('meetingId: $meetingId, ')
          ..write('version: $version, ')
          ..write('minutesJson: $minutesJson, ')
          ..write('recordJson: $recordJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MinutesSignaturesTable extends MinutesSignatures
    with TableInfo<$MinutesSignaturesTable, MinutesSignatureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MinutesSignaturesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signerNameMeta = const VerificationMeta(
    'signerName',
  );
  @override
  late final GeneratedColumn<String> signerName = GeneratedColumn<String>(
    'signer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signerRoleMeta = const VerificationMeta(
    'signerRole',
  );
  @override
  late final GeneratedColumn<String> signerRole = GeneratedColumn<String>(
    'signer_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _strokesJsonMeta = const VerificationMeta(
    'strokesJson',
  );
  @override
  late final GeneratedColumn<String> strokesJson = GeneratedColumn<String>(
    'strokes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> signedAt =
      GeneratedColumn<int>(
        'signed_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MinutesSignaturesTable.$convertersignedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    version,
    signerName,
    signerRole,
    strokesJson,
    contentHash,
    signedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'minutes_signatures';
  @override
  VerificationContext validateIntegrity(
    Insertable<MinutesSignatureRow> instance, {
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
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('signer_name')) {
      context.handle(
        _signerNameMeta,
        signerName.isAcceptableOrUnknown(data['signer_name']!, _signerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_signerNameMeta);
    }
    if (data.containsKey('signer_role')) {
      context.handle(
        _signerRoleMeta,
        signerRole.isAcceptableOrUnknown(data['signer_role']!, _signerRoleMeta),
      );
    }
    if (data.containsKey('strokes_json')) {
      context.handle(
        _strokesJsonMeta,
        strokesJson.isAcceptableOrUnknown(
          data['strokes_json']!,
          _strokesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_strokesJsonMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MinutesSignatureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MinutesSignatureRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      signerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_name'],
      )!,
      signerRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_role'],
      )!,
      strokesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strokes_json'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      signedAt: $MinutesSignaturesTable.$convertersignedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}signed_at'],
        )!,
      ),
    );
  }

  @override
  $MinutesSignaturesTable createAlias(String alias) {
    return $MinutesSignaturesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertersignedAt =
      const EpochMillisConverter();
}

class MinutesSignatureRow extends DataClass
    implements Insertable<MinutesSignatureRow> {
  /// Auto-increment primary key.
  final int id;

  /// Meeting; deleted with the meeting.
  final String meetingId;

  /// Minutes version signed.
  final int version;

  /// Signer's name.
  final String signerName;

  /// Signer's capacity.
  final String signerRole;

  /// `MinutesSignature.strokesJson()`.
  final String strokesJson;

  /// Hash of the content signed.
  final String contentHash;

  /// Signing time (UTC epoch milliseconds in SQL).
  final DateTime signedAt;
  const MinutesSignatureRow({
    required this.id,
    required this.meetingId,
    required this.version,
    required this.signerName,
    required this.signerRole,
    required this.strokesJson,
    required this.contentHash,
    required this.signedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['version'] = Variable<int>(version);
    map['signer_name'] = Variable<String>(signerName);
    map['signer_role'] = Variable<String>(signerRole);
    map['strokes_json'] = Variable<String>(strokesJson);
    map['content_hash'] = Variable<String>(contentHash);
    {
      map['signed_at'] = Variable<int>(
        $MinutesSignaturesTable.$convertersignedAt.toSql(signedAt),
      );
    }
    return map;
  }

  MinutesSignaturesCompanion toCompanion(bool nullToAbsent) {
    return MinutesSignaturesCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      version: Value(version),
      signerName: Value(signerName),
      signerRole: Value(signerRole),
      strokesJson: Value(strokesJson),
      contentHash: Value(contentHash),
      signedAt: Value(signedAt),
    );
  }

  factory MinutesSignatureRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MinutesSignatureRow(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      version: serializer.fromJson<int>(json['version']),
      signerName: serializer.fromJson<String>(json['signerName']),
      signerRole: serializer.fromJson<String>(json['signerRole']),
      strokesJson: serializer.fromJson<String>(json['strokesJson']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      signedAt: serializer.fromJson<DateTime>(json['signedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'version': serializer.toJson<int>(version),
      'signerName': serializer.toJson<String>(signerName),
      'signerRole': serializer.toJson<String>(signerRole),
      'strokesJson': serializer.toJson<String>(strokesJson),
      'contentHash': serializer.toJson<String>(contentHash),
      'signedAt': serializer.toJson<DateTime>(signedAt),
    };
  }

  MinutesSignatureRow copyWith({
    int? id,
    String? meetingId,
    int? version,
    String? signerName,
    String? signerRole,
    String? strokesJson,
    String? contentHash,
    DateTime? signedAt,
  }) => MinutesSignatureRow(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    version: version ?? this.version,
    signerName: signerName ?? this.signerName,
    signerRole: signerRole ?? this.signerRole,
    strokesJson: strokesJson ?? this.strokesJson,
    contentHash: contentHash ?? this.contentHash,
    signedAt: signedAt ?? this.signedAt,
  );
  MinutesSignatureRow copyWithCompanion(MinutesSignaturesCompanion data) {
    return MinutesSignatureRow(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      version: data.version.present ? data.version.value : this.version,
      signerName: data.signerName.present
          ? data.signerName.value
          : this.signerName,
      signerRole: data.signerRole.present
          ? data.signerRole.value
          : this.signerRole,
      strokesJson: data.strokesJson.present
          ? data.strokesJson.value
          : this.strokesJson,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      signedAt: data.signedAt.present ? data.signedAt.value : this.signedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MinutesSignatureRow(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('version: $version, ')
          ..write('signerName: $signerName, ')
          ..write('signerRole: $signerRole, ')
          ..write('strokesJson: $strokesJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('signedAt: $signedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    version,
    signerName,
    signerRole,
    strokesJson,
    contentHash,
    signedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MinutesSignatureRow &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.version == this.version &&
          other.signerName == this.signerName &&
          other.signerRole == this.signerRole &&
          other.strokesJson == this.strokesJson &&
          other.contentHash == this.contentHash &&
          other.signedAt == this.signedAt);
}

class MinutesSignaturesCompanion extends UpdateCompanion<MinutesSignatureRow> {
  final Value<int> id;
  final Value<String> meetingId;
  final Value<int> version;
  final Value<String> signerName;
  final Value<String> signerRole;
  final Value<String> strokesJson;
  final Value<String> contentHash;
  final Value<DateTime> signedAt;
  const MinutesSignaturesCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.version = const Value.absent(),
    this.signerName = const Value.absent(),
    this.signerRole = const Value.absent(),
    this.strokesJson = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.signedAt = const Value.absent(),
  });
  MinutesSignaturesCompanion.insert({
    this.id = const Value.absent(),
    required String meetingId,
    required int version,
    required String signerName,
    this.signerRole = const Value.absent(),
    required String strokesJson,
    required String contentHash,
    required DateTime signedAt,
  }) : meetingId = Value(meetingId),
       version = Value(version),
       signerName = Value(signerName),
       strokesJson = Value(strokesJson),
       contentHash = Value(contentHash),
       signedAt = Value(signedAt);
  static Insertable<MinutesSignatureRow> custom({
    Expression<int>? id,
    Expression<String>? meetingId,
    Expression<int>? version,
    Expression<String>? signerName,
    Expression<String>? signerRole,
    Expression<String>? strokesJson,
    Expression<String>? contentHash,
    Expression<int>? signedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (version != null) 'version': version,
      if (signerName != null) 'signer_name': signerName,
      if (signerRole != null) 'signer_role': signerRole,
      if (strokesJson != null) 'strokes_json': strokesJson,
      if (contentHash != null) 'content_hash': contentHash,
      if (signedAt != null) 'signed_at': signedAt,
    });
  }

  MinutesSignaturesCompanion copyWith({
    Value<int>? id,
    Value<String>? meetingId,
    Value<int>? version,
    Value<String>? signerName,
    Value<String>? signerRole,
    Value<String>? strokesJson,
    Value<String>? contentHash,
    Value<DateTime>? signedAt,
  }) {
    return MinutesSignaturesCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      version: version ?? this.version,
      signerName: signerName ?? this.signerName,
      signerRole: signerRole ?? this.signerRole,
      strokesJson: strokesJson ?? this.strokesJson,
      contentHash: contentHash ?? this.contentHash,
      signedAt: signedAt ?? this.signedAt,
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
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (signerName.present) {
      map['signer_name'] = Variable<String>(signerName.value);
    }
    if (signerRole.present) {
      map['signer_role'] = Variable<String>(signerRole.value);
    }
    if (strokesJson.present) {
      map['strokes_json'] = Variable<String>(strokesJson.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (signedAt.present) {
      map['signed_at'] = Variable<int>(
        $MinutesSignaturesTable.$convertersignedAt.toSql(signedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MinutesSignaturesCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('version: $version, ')
          ..write('signerName: $signerName, ')
          ..write('signerRole: $signerRole, ')
          ..write('strokesJson: $strokesJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('signedAt: $signedAt')
          ..write(')'))
        .toString();
  }
}

class $ConsistencyFindingsTable extends ConsistencyFindings
    with TableInfo<$ConsistencyFindingsTable, ConsistencyFindingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsistencyFindingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('heuristic'),
  );
  static const VerificationMeta _findingKeyMeta = const VerificationMeta(
    'findingKey',
  );
  @override
  late final GeneratedColumn<String> findingKey = GeneratedColumn<String>(
    'finding_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _newSideJsonMeta = const VerificationMeta(
    'newSideJson',
  );
  @override
  late final GeneratedColumn<String> newSideJson = GeneratedColumn<String>(
    'new_side_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorSideJsonMeta = const VerificationMeta(
    'priorSideJson',
  );
  @override
  late final GeneratedColumn<String> priorSideJson = GeneratedColumn<String>(
    'prior_side_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorMeetingIdMeta = const VerificationMeta(
    'priorMeetingId',
  );
  @override
  late final GeneratedColumn<String> priorMeetingId = GeneratedColumn<String>(
    'prior_meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE SET NULL',
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
      ).withConverter<DateTime>($ConsistencyFindingsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> resolvedAt =
      GeneratedColumn<int>(
        'resolved_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $ConsistencyFindingsTable.$converterresolvedAtn,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    kind,
    severity,
    status,
    origin,
    findingKey,
    explanation,
    newSideJson,
    priorSideJson,
    priorMeetingId,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consistency_findings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsistencyFindingRow> instance, {
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
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('finding_key')) {
      context.handle(
        _findingKeyMeta,
        findingKey.isAcceptableOrUnknown(data['finding_key']!, _findingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_findingKeyMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('new_side_json')) {
      context.handle(
        _newSideJsonMeta,
        newSideJson.isAcceptableOrUnknown(
          data['new_side_json']!,
          _newSideJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_newSideJsonMeta);
    }
    if (data.containsKey('prior_side_json')) {
      context.handle(
        _priorSideJsonMeta,
        priorSideJson.isAcceptableOrUnknown(
          data['prior_side_json']!,
          _priorSideJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_priorSideJsonMeta);
    }
    if (data.containsKey('prior_meeting_id')) {
      context.handle(
        _priorMeetingIdMeta,
        priorMeetingId.isAcceptableOrUnknown(
          data['prior_meeting_id']!,
          _priorMeetingIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConsistencyFindingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsistencyFindingRow(
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
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      findingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finding_key'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      newSideJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_side_json'],
      )!,
      priorSideJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prior_side_json'],
      )!,
      priorMeetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prior_meeting_id'],
      ),
      createdAt: $ConsistencyFindingsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      resolvedAt: $ConsistencyFindingsTable.$converterresolvedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}resolved_at'],
        ),
      ),
    );
  }

  @override
  $ConsistencyFindingsTable createAlias(String alias) {
    return $ConsistencyFindingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime, int> $converterresolvedAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime?, int?> $converterresolvedAtn =
      NullAwareTypeConverter.wrap($converterresolvedAt);
}

class ConsistencyFindingRow extends DataClass
    implements Insertable<ConsistencyFindingRow> {
  /// Auto-increment primary key.
  final int id;

  /// Meeting checked; deleted with the meeting.
  final String meetingId;

  /// `FindingKind.wire`.
  final String kind;

  /// `FindingSeverity.wire`.
  final String severity;

  /// `FindingStatus.wire` — open / dismissed / confirmed.
  final String status;

  /// `heuristic` (pure-Dart rules) or `engine` (minutes engine).
  final String origin;

  /// Stable key (kind + both sides) so a re-check keeps the user's
  /// decisions.
  final String findingKey;

  /// Arabic explanation.
  final String explanation;

  /// The new side (`FindingSide.toJson()`).
  final String newSideJson;

  /// The earlier side (`FindingSide.toJson()`).
  final String priorSideJson;

  /// Meeting of the earlier side (null for a manual task or once that
  /// meeting is deleted).
  final String? priorMeetingId;

  /// Creation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;

  /// When it was dismissed / confirmed.
  final DateTime? resolvedAt;
  const ConsistencyFindingRow({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.severity,
    required this.status,
    required this.origin,
    required this.findingKey,
    required this.explanation,
    required this.newSideJson,
    required this.priorSideJson,
    this.priorMeetingId,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['kind'] = Variable<String>(kind);
    map['severity'] = Variable<String>(severity);
    map['status'] = Variable<String>(status);
    map['origin'] = Variable<String>(origin);
    map['finding_key'] = Variable<String>(findingKey);
    map['explanation'] = Variable<String>(explanation);
    map['new_side_json'] = Variable<String>(newSideJson);
    map['prior_side_json'] = Variable<String>(priorSideJson);
    if (!nullToAbsent || priorMeetingId != null) {
      map['prior_meeting_id'] = Variable<String>(priorMeetingId);
    }
    {
      map['created_at'] = Variable<int>(
        $ConsistencyFindingsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<int>(
        $ConsistencyFindingsTable.$converterresolvedAtn.toSql(resolvedAt),
      );
    }
    return map;
  }

  ConsistencyFindingsCompanion toCompanion(bool nullToAbsent) {
    return ConsistencyFindingsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      kind: Value(kind),
      severity: Value(severity),
      status: Value(status),
      origin: Value(origin),
      findingKey: Value(findingKey),
      explanation: Value(explanation),
      newSideJson: Value(newSideJson),
      priorSideJson: Value(priorSideJson),
      priorMeetingId: priorMeetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(priorMeetingId),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory ConsistencyFindingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsistencyFindingRow(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      kind: serializer.fromJson<String>(json['kind']),
      severity: serializer.fromJson<String>(json['severity']),
      status: serializer.fromJson<String>(json['status']),
      origin: serializer.fromJson<String>(json['origin']),
      findingKey: serializer.fromJson<String>(json['findingKey']),
      explanation: serializer.fromJson<String>(json['explanation']),
      newSideJson: serializer.fromJson<String>(json['newSideJson']),
      priorSideJson: serializer.fromJson<String>(json['priorSideJson']),
      priorMeetingId: serializer.fromJson<String?>(json['priorMeetingId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'kind': serializer.toJson<String>(kind),
      'severity': serializer.toJson<String>(severity),
      'status': serializer.toJson<String>(status),
      'origin': serializer.toJson<String>(origin),
      'findingKey': serializer.toJson<String>(findingKey),
      'explanation': serializer.toJson<String>(explanation),
      'newSideJson': serializer.toJson<String>(newSideJson),
      'priorSideJson': serializer.toJson<String>(priorSideJson),
      'priorMeetingId': serializer.toJson<String?>(priorMeetingId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  ConsistencyFindingRow copyWith({
    int? id,
    String? meetingId,
    String? kind,
    String? severity,
    String? status,
    String? origin,
    String? findingKey,
    String? explanation,
    String? newSideJson,
    String? priorSideJson,
    Value<String?> priorMeetingId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => ConsistencyFindingRow(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    kind: kind ?? this.kind,
    severity: severity ?? this.severity,
    status: status ?? this.status,
    origin: origin ?? this.origin,
    findingKey: findingKey ?? this.findingKey,
    explanation: explanation ?? this.explanation,
    newSideJson: newSideJson ?? this.newSideJson,
    priorSideJson: priorSideJson ?? this.priorSideJson,
    priorMeetingId: priorMeetingId.present
        ? priorMeetingId.value
        : this.priorMeetingId,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  ConsistencyFindingRow copyWithCompanion(ConsistencyFindingsCompanion data) {
    return ConsistencyFindingRow(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      kind: data.kind.present ? data.kind.value : this.kind,
      severity: data.severity.present ? data.severity.value : this.severity,
      status: data.status.present ? data.status.value : this.status,
      origin: data.origin.present ? data.origin.value : this.origin,
      findingKey: data.findingKey.present
          ? data.findingKey.value
          : this.findingKey,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      newSideJson: data.newSideJson.present
          ? data.newSideJson.value
          : this.newSideJson,
      priorSideJson: data.priorSideJson.present
          ? data.priorSideJson.value
          : this.priorSideJson,
      priorMeetingId: data.priorMeetingId.present
          ? data.priorMeetingId.value
          : this.priorMeetingId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsistencyFindingRow(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('severity: $severity, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('findingKey: $findingKey, ')
          ..write('explanation: $explanation, ')
          ..write('newSideJson: $newSideJson, ')
          ..write('priorSideJson: $priorSideJson, ')
          ..write('priorMeetingId: $priorMeetingId, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    kind,
    severity,
    status,
    origin,
    findingKey,
    explanation,
    newSideJson,
    priorSideJson,
    priorMeetingId,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsistencyFindingRow &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.kind == this.kind &&
          other.severity == this.severity &&
          other.status == this.status &&
          other.origin == this.origin &&
          other.findingKey == this.findingKey &&
          other.explanation == this.explanation &&
          other.newSideJson == this.newSideJson &&
          other.priorSideJson == this.priorSideJson &&
          other.priorMeetingId == this.priorMeetingId &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class ConsistencyFindingsCompanion
    extends UpdateCompanion<ConsistencyFindingRow> {
  final Value<int> id;
  final Value<String> meetingId;
  final Value<String> kind;
  final Value<String> severity;
  final Value<String> status;
  final Value<String> origin;
  final Value<String> findingKey;
  final Value<String> explanation;
  final Value<String> newSideJson;
  final Value<String> priorSideJson;
  final Value<String?> priorMeetingId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  const ConsistencyFindingsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.kind = const Value.absent(),
    this.severity = const Value.absent(),
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    this.findingKey = const Value.absent(),
    this.explanation = const Value.absent(),
    this.newSideJson = const Value.absent(),
    this.priorSideJson = const Value.absent(),
    this.priorMeetingId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  ConsistencyFindingsCompanion.insert({
    this.id = const Value.absent(),
    required String meetingId,
    required String kind,
    required String severity,
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    required String findingKey,
    this.explanation = const Value.absent(),
    required String newSideJson,
    required String priorSideJson,
    this.priorMeetingId = const Value.absent(),
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
  }) : meetingId = Value(meetingId),
       kind = Value(kind),
       severity = Value(severity),
       findingKey = Value(findingKey),
       newSideJson = Value(newSideJson),
       priorSideJson = Value(priorSideJson),
       createdAt = Value(createdAt);
  static Insertable<ConsistencyFindingRow> custom({
    Expression<int>? id,
    Expression<String>? meetingId,
    Expression<String>? kind,
    Expression<String>? severity,
    Expression<String>? status,
    Expression<String>? origin,
    Expression<String>? findingKey,
    Expression<String>? explanation,
    Expression<String>? newSideJson,
    Expression<String>? priorSideJson,
    Expression<String>? priorMeetingId,
    Expression<int>? createdAt,
    Expression<int>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (kind != null) 'kind': kind,
      if (severity != null) 'severity': severity,
      if (status != null) 'status': status,
      if (origin != null) 'origin': origin,
      if (findingKey != null) 'finding_key': findingKey,
      if (explanation != null) 'explanation': explanation,
      if (newSideJson != null) 'new_side_json': newSideJson,
      if (priorSideJson != null) 'prior_side_json': priorSideJson,
      if (priorMeetingId != null) 'prior_meeting_id': priorMeetingId,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  ConsistencyFindingsCompanion copyWith({
    Value<int>? id,
    Value<String>? meetingId,
    Value<String>? kind,
    Value<String>? severity,
    Value<String>? status,
    Value<String>? origin,
    Value<String>? findingKey,
    Value<String>? explanation,
    Value<String>? newSideJson,
    Value<String>? priorSideJson,
    Value<String?>? priorMeetingId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
  }) {
    return ConsistencyFindingsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      kind: kind ?? this.kind,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      findingKey: findingKey ?? this.findingKey,
      explanation: explanation ?? this.explanation,
      newSideJson: newSideJson ?? this.newSideJson,
      priorSideJson: priorSideJson ?? this.priorSideJson,
      priorMeetingId: priorMeetingId ?? this.priorMeetingId,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
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
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (findingKey.present) {
      map['finding_key'] = Variable<String>(findingKey.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (newSideJson.present) {
      map['new_side_json'] = Variable<String>(newSideJson.value);
    }
    if (priorSideJson.present) {
      map['prior_side_json'] = Variable<String>(priorSideJson.value);
    }
    if (priorMeetingId.present) {
      map['prior_meeting_id'] = Variable<String>(priorMeetingId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ConsistencyFindingsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<int>(
        $ConsistencyFindingsTable.$converterresolvedAtn.toSql(resolvedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsistencyFindingsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('kind: $kind, ')
          ..write('severity: $severity, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('findingKey: $findingKey, ')
          ..write('explanation: $explanation, ')
          ..write('newSideJson: $newSideJson, ')
          ..write('priorSideJson: $priorSideJson, ')
          ..write('priorMeetingId: $priorMeetingId, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $ResolutionAnnotationsTable extends ResolutionAnnotations
    with TableInfo<$ResolutionAnnotationsTable, ResolutionAnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResolutionAnnotationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _decisionIndexMeta = const VerificationMeta(
    'decisionIndex',
  );
  @override
  late final GeneratedColumn<int> decisionIndex = GeneratedColumn<int>(
    'decision_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decisionKeyMeta = const VerificationMeta(
    'decisionKey',
  );
  @override
  late final GeneratedColumn<String> decisionKey = GeneratedColumn<String>(
    'decision_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('superseded'),
  );
  static const VerificationMeta _byMeetingIdMeta = const VerificationMeta(
    'byMeetingId',
  );
  @override
  late final GeneratedColumn<String> byMeetingId = GeneratedColumn<String>(
    'by_meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _findingIdMeta = const VerificationMeta(
    'findingId',
  );
  @override
  late final GeneratedColumn<int> findingId = GeneratedColumn<int>(
    'finding_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES consistency_findings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bySideJsonMeta = const VerificationMeta(
    'bySideJson',
  );
  @override
  late final GeneratedColumn<String> bySideJson = GeneratedColumn<String>(
    'by_side_json',
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
      ).withConverter<DateTime>(
        $ResolutionAnnotationsTable.$convertercreatedAt,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    decisionIndex,
    decisionKey,
    kind,
    byMeetingId,
    findingId,
    bySideJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resolution_annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResolutionAnnotationRow> instance, {
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
    if (data.containsKey('decision_index')) {
      context.handle(
        _decisionIndexMeta,
        decisionIndex.isAcceptableOrUnknown(
          data['decision_index']!,
          _decisionIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decisionIndexMeta);
    }
    if (data.containsKey('decision_key')) {
      context.handle(
        _decisionKeyMeta,
        decisionKey.isAcceptableOrUnknown(
          data['decision_key']!,
          _decisionKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decisionKeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('by_meeting_id')) {
      context.handle(
        _byMeetingIdMeta,
        byMeetingId.isAcceptableOrUnknown(
          data['by_meeting_id']!,
          _byMeetingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_byMeetingIdMeta);
    }
    if (data.containsKey('finding_id')) {
      context.handle(
        _findingIdMeta,
        findingId.isAcceptableOrUnknown(data['finding_id']!, _findingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_findingIdMeta);
    }
    if (data.containsKey('by_side_json')) {
      context.handle(
        _bySideJsonMeta,
        bySideJson.isAcceptableOrUnknown(
          data['by_side_json']!,
          _bySideJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bySideJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResolutionAnnotationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResolutionAnnotationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      decisionIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}decision_index'],
      )!,
      decisionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decision_key'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      byMeetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_meeting_id'],
      )!,
      findingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finding_id'],
      )!,
      bySideJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_side_json'],
      )!,
      createdAt: $ResolutionAnnotationsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $ResolutionAnnotationsTable createAlias(String alias) {
    return $ResolutionAnnotationsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMillisConverter();
}

class ResolutionAnnotationRow extends DataClass
    implements Insertable<ResolutionAnnotationRow> {
  /// Auto-increment primary key.
  final int id;

  /// Meeting whose resolution is annotated.
  final String meetingId;

  /// 0-based index of the decision when annotated.
  final int decisionIndex;

  /// `decisionKeyOf` of the decision (guards against regeneration).
  final String decisionKey;

  /// `superseded`.
  final String kind;

  /// Meeting whose decision superseded it.
  final String byMeetingId;

  /// The confirmed finding.
  final int findingId;

  /// Snapshot of the superseding side (`FindingSide.toJson()`).
  final String bySideJson;

  /// Annotation time (UTC epoch milliseconds in SQL).
  final DateTime createdAt;
  const ResolutionAnnotationRow({
    required this.id,
    required this.meetingId,
    required this.decisionIndex,
    required this.decisionKey,
    required this.kind,
    required this.byMeetingId,
    required this.findingId,
    required this.bySideJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['decision_index'] = Variable<int>(decisionIndex);
    map['decision_key'] = Variable<String>(decisionKey);
    map['kind'] = Variable<String>(kind);
    map['by_meeting_id'] = Variable<String>(byMeetingId);
    map['finding_id'] = Variable<int>(findingId);
    map['by_side_json'] = Variable<String>(bySideJson);
    {
      map['created_at'] = Variable<int>(
        $ResolutionAnnotationsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  ResolutionAnnotationsCompanion toCompanion(bool nullToAbsent) {
    return ResolutionAnnotationsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      decisionIndex: Value(decisionIndex),
      decisionKey: Value(decisionKey),
      kind: Value(kind),
      byMeetingId: Value(byMeetingId),
      findingId: Value(findingId),
      bySideJson: Value(bySideJson),
      createdAt: Value(createdAt),
    );
  }

  factory ResolutionAnnotationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResolutionAnnotationRow(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      decisionIndex: serializer.fromJson<int>(json['decisionIndex']),
      decisionKey: serializer.fromJson<String>(json['decisionKey']),
      kind: serializer.fromJson<String>(json['kind']),
      byMeetingId: serializer.fromJson<String>(json['byMeetingId']),
      findingId: serializer.fromJson<int>(json['findingId']),
      bySideJson: serializer.fromJson<String>(json['bySideJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'decisionIndex': serializer.toJson<int>(decisionIndex),
      'decisionKey': serializer.toJson<String>(decisionKey),
      'kind': serializer.toJson<String>(kind),
      'byMeetingId': serializer.toJson<String>(byMeetingId),
      'findingId': serializer.toJson<int>(findingId),
      'bySideJson': serializer.toJson<String>(bySideJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ResolutionAnnotationRow copyWith({
    int? id,
    String? meetingId,
    int? decisionIndex,
    String? decisionKey,
    String? kind,
    String? byMeetingId,
    int? findingId,
    String? bySideJson,
    DateTime? createdAt,
  }) => ResolutionAnnotationRow(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    decisionIndex: decisionIndex ?? this.decisionIndex,
    decisionKey: decisionKey ?? this.decisionKey,
    kind: kind ?? this.kind,
    byMeetingId: byMeetingId ?? this.byMeetingId,
    findingId: findingId ?? this.findingId,
    bySideJson: bySideJson ?? this.bySideJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ResolutionAnnotationRow copyWithCompanion(
    ResolutionAnnotationsCompanion data,
  ) {
    return ResolutionAnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      decisionIndex: data.decisionIndex.present
          ? data.decisionIndex.value
          : this.decisionIndex,
      decisionKey: data.decisionKey.present
          ? data.decisionKey.value
          : this.decisionKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      byMeetingId: data.byMeetingId.present
          ? data.byMeetingId.value
          : this.byMeetingId,
      findingId: data.findingId.present ? data.findingId.value : this.findingId,
      bySideJson: data.bySideJson.present
          ? data.bySideJson.value
          : this.bySideJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResolutionAnnotationRow(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('decisionIndex: $decisionIndex, ')
          ..write('decisionKey: $decisionKey, ')
          ..write('kind: $kind, ')
          ..write('byMeetingId: $byMeetingId, ')
          ..write('findingId: $findingId, ')
          ..write('bySideJson: $bySideJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    decisionIndex,
    decisionKey,
    kind,
    byMeetingId,
    findingId,
    bySideJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResolutionAnnotationRow &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.decisionIndex == this.decisionIndex &&
          other.decisionKey == this.decisionKey &&
          other.kind == this.kind &&
          other.byMeetingId == this.byMeetingId &&
          other.findingId == this.findingId &&
          other.bySideJson == this.bySideJson &&
          other.createdAt == this.createdAt);
}

class ResolutionAnnotationsCompanion
    extends UpdateCompanion<ResolutionAnnotationRow> {
  final Value<int> id;
  final Value<String> meetingId;
  final Value<int> decisionIndex;
  final Value<String> decisionKey;
  final Value<String> kind;
  final Value<String> byMeetingId;
  final Value<int> findingId;
  final Value<String> bySideJson;
  final Value<DateTime> createdAt;
  const ResolutionAnnotationsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.decisionIndex = const Value.absent(),
    this.decisionKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.byMeetingId = const Value.absent(),
    this.findingId = const Value.absent(),
    this.bySideJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ResolutionAnnotationsCompanion.insert({
    this.id = const Value.absent(),
    required String meetingId,
    required int decisionIndex,
    required String decisionKey,
    this.kind = const Value.absent(),
    required String byMeetingId,
    required int findingId,
    required String bySideJson,
    required DateTime createdAt,
  }) : meetingId = Value(meetingId),
       decisionIndex = Value(decisionIndex),
       decisionKey = Value(decisionKey),
       byMeetingId = Value(byMeetingId),
       findingId = Value(findingId),
       bySideJson = Value(bySideJson),
       createdAt = Value(createdAt);
  static Insertable<ResolutionAnnotationRow> custom({
    Expression<int>? id,
    Expression<String>? meetingId,
    Expression<int>? decisionIndex,
    Expression<String>? decisionKey,
    Expression<String>? kind,
    Expression<String>? byMeetingId,
    Expression<int>? findingId,
    Expression<String>? bySideJson,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (decisionIndex != null) 'decision_index': decisionIndex,
      if (decisionKey != null) 'decision_key': decisionKey,
      if (kind != null) 'kind': kind,
      if (byMeetingId != null) 'by_meeting_id': byMeetingId,
      if (findingId != null) 'finding_id': findingId,
      if (bySideJson != null) 'by_side_json': bySideJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ResolutionAnnotationsCompanion copyWith({
    Value<int>? id,
    Value<String>? meetingId,
    Value<int>? decisionIndex,
    Value<String>? decisionKey,
    Value<String>? kind,
    Value<String>? byMeetingId,
    Value<int>? findingId,
    Value<String>? bySideJson,
    Value<DateTime>? createdAt,
  }) {
    return ResolutionAnnotationsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      decisionIndex: decisionIndex ?? this.decisionIndex,
      decisionKey: decisionKey ?? this.decisionKey,
      kind: kind ?? this.kind,
      byMeetingId: byMeetingId ?? this.byMeetingId,
      findingId: findingId ?? this.findingId,
      bySideJson: bySideJson ?? this.bySideJson,
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
    if (decisionIndex.present) {
      map['decision_index'] = Variable<int>(decisionIndex.value);
    }
    if (decisionKey.present) {
      map['decision_key'] = Variable<String>(decisionKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (byMeetingId.present) {
      map['by_meeting_id'] = Variable<String>(byMeetingId.value);
    }
    if (findingId.present) {
      map['finding_id'] = Variable<int>(findingId.value);
    }
    if (bySideJson.present) {
      map['by_side_json'] = Variable<String>(bySideJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ResolutionAnnotationsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResolutionAnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('decisionIndex: $decisionIndex, ')
          ..write('decisionKey: $decisionKey, ')
          ..write('kind: $kind, ')
          ..write('byMeetingId: $byMeetingId, ')
          ..write('findingId: $findingId, ')
          ..write('bySideJson: $bySideJson, ')
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
  late final $TaskDismissalsTable taskDismissals = $TaskDismissalsTable(this);
  late final $OfficialRecordsTable officialRecords = $OfficialRecordsTable(
    this,
  );
  late final $MinutesVersionsTable minutesVersions = $MinutesVersionsTable(
    this,
  );
  late final $MinutesSignaturesTable minutesSignatures =
      $MinutesSignaturesTable(this);
  late final $ConsistencyFindingsTable consistencyFindings =
      $ConsistencyFindingsTable(this);
  late final $ResolutionAnnotationsTable resolutionAnnotations =
      $ResolutionAnnotationsTable(this);
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
  late final Index officialRecordsSequence = Index(
    'official_records_sequence',
    'CREATE INDEX official_records_sequence ON official_records (entity_key, committee, number_year)',
  );
  late final Index minutesSignaturesMeeting = Index(
    'minutes_signatures_meeting',
    'CREATE INDEX minutes_signatures_meeting ON minutes_signatures (meeting_id)',
  );
  late final Index consistencyFindingsMeeting = Index(
    'consistency_findings_meeting',
    'CREATE INDEX consistency_findings_meeting ON consistency_findings (meeting_id)',
  );
  late final Index consistencyFindingsPrior = Index(
    'consistency_findings_prior',
    'CREATE INDEX consistency_findings_prior ON consistency_findings (prior_meeting_id)',
  );
  late final Index resolutionAnnotationsMeeting = Index(
    'resolution_annotations_meeting',
    'CREATE INDEX resolution_annotations_meeting ON resolution_annotations (meeting_id)',
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
    taskDismissals,
    officialRecords,
    minutesVersions,
    minutesSignatures,
    consistencyFindings,
    resolutionAnnotations,
    segmentsMeetingIdx,
    segmentsSpeaker,
    glossaryTermsMeeting,
    tasksStatus,
    tasksSourceMeeting,
    taskUpdatesPendingMeeting,
    taskUpdatesPendingTask,
    speakerMeetingNotesMeeting,
    codeFindingsMeeting,
    officialRecordsSequence,
    minutesSignaturesMeeting,
    consistencyFindingsMeeting,
    consistencyFindingsPrior,
    resolutionAnnotationsMeeting,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_dismissals', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('official_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('minutes_versions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('minutes_signatures', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('consistency_findings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('consistency_findings', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('resolution_annotations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('resolution_annotations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'consistency_findings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('resolution_annotations', kind: UpdateKind.delete)],
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

  static MultiTypedResultKey<$TaskDismissalsTable, List<TaskDismissalRow>>
  _taskDismissalsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskDismissals,
    aliasName: 'meetings__id__task_dismissals__meeting_id',
  );

  $$TaskDismissalsTableProcessedTableManager get taskDismissalsRefs {
    final manager = $$TaskDismissalsTableTableManager(
      $_db,
      $_db.taskDismissals,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskDismissalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OfficialRecordsTable, List<OfficialRecordRow>>
  _officialRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.officialRecords,
    aliasName: 'meetings__id__official_records__meeting_id',
  );

  $$OfficialRecordsTableProcessedTableManager get officialRecordsRefs {
    final manager = $$OfficialRecordsTableTableManager(
      $_db,
      $_db.officialRecords,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _officialRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MinutesVersionsTable, List<MinutesVersionRow>>
  _minutesVersionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.minutesVersions,
    aliasName: 'meetings__id__minutes_versions__meeting_id',
  );

  $$MinutesVersionsTableProcessedTableManager get minutesVersionsRefs {
    final manager = $$MinutesVersionsTableTableManager(
      $_db,
      $_db.minutesVersions,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _minutesVersionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MinutesSignaturesTable, List<MinutesSignatureRow>>
  _minutesSignaturesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.minutesSignatures,
        aliasName: 'meetings__id__minutes_signatures__meeting_id',
      );

  $$MinutesSignaturesTableProcessedTableManager get minutesSignaturesRefs {
    final manager = $$MinutesSignaturesTableTableManager(
      $_db,
      $_db.minutesSignatures,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _minutesSignaturesRefsTable($_db),
    );
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

  Expression<bool> taskDismissalsRefs(
    Expression<bool> Function($$TaskDismissalsTableFilterComposer f) f,
  ) {
    final $$TaskDismissalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskDismissals,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskDismissalsTableFilterComposer(
            $db: $db,
            $table: $db.taskDismissals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> officialRecordsRefs(
    Expression<bool> Function($$OfficialRecordsTableFilterComposer f) f,
  ) {
    final $$OfficialRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.officialRecords,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OfficialRecordsTableFilterComposer(
            $db: $db,
            $table: $db.officialRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> minutesVersionsRefs(
    Expression<bool> Function($$MinutesVersionsTableFilterComposer f) f,
  ) {
    final $$MinutesVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.minutesVersions,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MinutesVersionsTableFilterComposer(
            $db: $db,
            $table: $db.minutesVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> minutesSignaturesRefs(
    Expression<bool> Function($$MinutesSignaturesTableFilterComposer f) f,
  ) {
    final $$MinutesSignaturesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.minutesSignatures,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MinutesSignaturesTableFilterComposer(
            $db: $db,
            $table: $db.minutesSignatures,
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

  Expression<T> taskDismissalsRefs<T extends Object>(
    Expression<T> Function($$TaskDismissalsTableAnnotationComposer a) f,
  ) {
    final $$TaskDismissalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskDismissals,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskDismissalsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskDismissals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> officialRecordsRefs<T extends Object>(
    Expression<T> Function($$OfficialRecordsTableAnnotationComposer a) f,
  ) {
    final $$OfficialRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.officialRecords,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OfficialRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.officialRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> minutesVersionsRefs<T extends Object>(
    Expression<T> Function($$MinutesVersionsTableAnnotationComposer a) f,
  ) {
    final $$MinutesVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.minutesVersions,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MinutesVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.minutesVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> minutesSignaturesRefs<T extends Object>(
    Expression<T> Function($$MinutesSignaturesTableAnnotationComposer a) f,
  ) {
    final $$MinutesSignaturesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.minutesSignatures,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MinutesSignaturesTableAnnotationComposer(
                $db: $db,
                $table: $db.minutesSignatures,
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
            bool taskDismissalsRefs,
            bool officialRecordsRefs,
            bool minutesVersionsRefs,
            bool minutesSignaturesRefs,
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
                taskDismissalsRefs = false,
                officialRecordsRefs = false,
                minutesVersionsRefs = false,
                minutesSignaturesRefs = false,
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
                    if (taskDismissalsRefs) db.taskDismissals,
                    if (officialRecordsRefs) db.officialRecords,
                    if (minutesVersionsRefs) db.minutesVersions,
                    if (minutesSignaturesRefs) db.minutesSignatures,
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
                      if (taskDismissalsRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          TaskDismissalRow,
                          $TaskDismissalsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._taskDismissalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).taskDismissalsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (officialRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          OfficialRecordRow,
                          $OfficialRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._officialRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).officialRecordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (minutesVersionsRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          MinutesVersionRow,
                          $MinutesVersionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._minutesVersionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).minutesVersionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (minutesSignaturesRefs)
                        await $_getPrefetchedDataByColumns<
                          MeetingRow,
                          $MeetingsTable,
                          MinutesSignatureRow,
                          $MinutesSignaturesTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._minutesSignaturesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).minutesSignaturesRefs,
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
        bool taskDismissalsRefs,
        bool officialRecordsRefs,
        bool minutesVersionsRefs,
        bool minutesSignaturesRefs,
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
typedef $$TaskDismissalsTableCreateCompanionBuilder =
    TaskDismissalsCompanion Function({
      required String meetingId,
      required String kind,
      required String itemKey,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TaskDismissalsTableUpdateCompanionBuilder =
    TaskDismissalsCompanion Function({
      Value<String> meetingId,
      Value<String> kind,
      Value<String> itemKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TaskDismissalsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskDismissalsTable, TaskDismissalRow> {
  $$TaskDismissalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('task_dismissals__meeting_id__meetings__id');

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

class $$TaskDismissalsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskDismissalsTable> {
  $$TaskDismissalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
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

class $$TaskDismissalsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskDismissalsTable> {
  $$TaskDismissalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
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

class $$TaskDismissalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskDismissalsTable> {
  $$TaskDismissalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

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

class $$TaskDismissalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskDismissalsTable,
          TaskDismissalRow,
          $$TaskDismissalsTableFilterComposer,
          $$TaskDismissalsTableOrderingComposer,
          $$TaskDismissalsTableAnnotationComposer,
          $$TaskDismissalsTableCreateCompanionBuilder,
          $$TaskDismissalsTableUpdateCompanionBuilder,
          (TaskDismissalRow, $$TaskDismissalsTableReferences),
          TaskDismissalRow,
          PrefetchHooks Function({bool meetingId})
        > {
  $$TaskDismissalsTableTableManager(
    _$AppDatabase db,
    $TaskDismissalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskDismissalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskDismissalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskDismissalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> meetingId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> itemKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskDismissalsCompanion(
                meetingId: meetingId,
                kind: kind,
                itemKey: itemKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String meetingId,
                required String kind,
                required String itemKey,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskDismissalsCompanion.insert(
                meetingId: meetingId,
                kind: kind,
                itemKey: itemKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskDismissalsTable, TaskDismissalRow>(table),
                  $$TaskDismissalsTableReferences(db, table, e),
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
                        referencedTable: $$TaskDismissalsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$TaskDismissalsTableReferences
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

typedef $$TaskDismissalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskDismissalsTable,
      TaskDismissalRow,
      $$TaskDismissalsTableFilterComposer,
      $$TaskDismissalsTableOrderingComposer,
      $$TaskDismissalsTableAnnotationComposer,
      $$TaskDismissalsTableCreateCompanionBuilder,
      $$TaskDismissalsTableUpdateCompanionBuilder,
      (TaskDismissalRow, $$TaskDismissalsTableReferences),
      TaskDismissalRow,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$OfficialRecordsTableCreateCompanionBuilder =
    OfficialRecordsCompanion Function({
      required String meetingId,
      Value<String> entityKey,
      Value<String> committee,
      Value<int?> numberYear,
      Value<int?> meetingNumber,
      Value<String> status,
      Value<int> version,
      required String recordJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OfficialRecordsTableUpdateCompanionBuilder =
    OfficialRecordsCompanion Function({
      Value<String> meetingId,
      Value<String> entityKey,
      Value<String> committee,
      Value<int?> numberYear,
      Value<int?> meetingNumber,
      Value<String> status,
      Value<int> version,
      Value<String> recordJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$OfficialRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $OfficialRecordsTable,
          OfficialRecordRow
        > {
  $$OfficialRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('official_records__meeting_id__meetings__id');

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

class $$OfficialRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $OfficialRecordsTable> {
  $$OfficialRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get committee => $composableBuilder(
    column: $table.committee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numberYear => $composableBuilder(
    column: $table.numberYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingNumber => $composableBuilder(
    column: $table.meetingNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
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

class $$OfficialRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfficialRecordsTable> {
  $$OfficialRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityKey => $composableBuilder(
    column: $table.entityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get committee => $composableBuilder(
    column: $table.committee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numberYear => $composableBuilder(
    column: $table.numberYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingNumber => $composableBuilder(
    column: $table.meetingNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$OfficialRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfficialRecordsTable> {
  $$OfficialRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);

  GeneratedColumn<String> get committee =>
      $composableBuilder(column: $table.committee, builder: (column) => column);

  GeneratedColumn<int> get numberYear => $composableBuilder(
    column: $table.numberYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get meetingNumber => $composableBuilder(
    column: $table.meetingNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

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

class $$OfficialRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfficialRecordsTable,
          OfficialRecordRow,
          $$OfficialRecordsTableFilterComposer,
          $$OfficialRecordsTableOrderingComposer,
          $$OfficialRecordsTableAnnotationComposer,
          $$OfficialRecordsTableCreateCompanionBuilder,
          $$OfficialRecordsTableUpdateCompanionBuilder,
          (OfficialRecordRow, $$OfficialRecordsTableReferences),
          OfficialRecordRow,
          PrefetchHooks Function({bool meetingId})
        > {
  $$OfficialRecordsTableTableManager(
    _$AppDatabase db,
    $OfficialRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfficialRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfficialRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfficialRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> meetingId = const Value.absent(),
                Value<String> entityKey = const Value.absent(),
                Value<String> committee = const Value.absent(),
                Value<int?> numberYear = const Value.absent(),
                Value<int?> meetingNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> recordJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfficialRecordsCompanion(
                meetingId: meetingId,
                entityKey: entityKey,
                committee: committee,
                numberYear: numberYear,
                meetingNumber: meetingNumber,
                status: status,
                version: version,
                recordJson: recordJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String meetingId,
                Value<String> entityKey = const Value.absent(),
                Value<String> committee = const Value.absent(),
                Value<int?> numberYear = const Value.absent(),
                Value<int?> meetingNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> version = const Value.absent(),
                required String recordJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OfficialRecordsCompanion.insert(
                meetingId: meetingId,
                entityKey: entityKey,
                committee: committee,
                numberYear: numberYear,
                meetingNumber: meetingNumber,
                status: status,
                version: version,
                recordJson: recordJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfficialRecordsTable, OfficialRecordRow>(table),
                  $$OfficialRecordsTableReferences(db, table, e),
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
                        referencedTable: $$OfficialRecordsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$OfficialRecordsTableReferences
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

typedef $$OfficialRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfficialRecordsTable,
      OfficialRecordRow,
      $$OfficialRecordsTableFilterComposer,
      $$OfficialRecordsTableOrderingComposer,
      $$OfficialRecordsTableAnnotationComposer,
      $$OfficialRecordsTableCreateCompanionBuilder,
      $$OfficialRecordsTableUpdateCompanionBuilder,
      (OfficialRecordRow, $$OfficialRecordsTableReferences),
      OfficialRecordRow,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$MinutesVersionsTableCreateCompanionBuilder =
    MinutesVersionsCompanion Function({
      required String meetingId,
      required int version,
      required String minutesJson,
      required String recordJson,
      required String contentHash,
      required DateTime approvedAt,
      Value<int> rowid,
    });
typedef $$MinutesVersionsTableUpdateCompanionBuilder =
    MinutesVersionsCompanion Function({
      Value<String> meetingId,
      Value<int> version,
      Value<String> minutesJson,
      Value<String> recordJson,
      Value<String> contentHash,
      Value<DateTime> approvedAt,
      Value<int> rowid,
    });

final class $$MinutesVersionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MinutesVersionsTable,
          MinutesVersionRow
        > {
  $$MinutesVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('minutes_versions__meeting_id__meetings__id');

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

class $$MinutesVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $MinutesVersionsTable> {
  $$MinutesVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minutesJson => $composableBuilder(
    column: $table.minutesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get approvedAt =>
      $composableBuilder(
        column: $table.approvedAt,
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

class $$MinutesVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MinutesVersionsTable> {
  $$MinutesVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minutesJson => $composableBuilder(
    column: $table.minutesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get approvedAt => $composableBuilder(
    column: $table.approvedAt,
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

class $$MinutesVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MinutesVersionsTable> {
  $$MinutesVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get minutesJson => $composableBuilder(
    column: $table.minutesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get approvedAt =>
      $composableBuilder(
        column: $table.approvedAt,
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
}

class $$MinutesVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MinutesVersionsTable,
          MinutesVersionRow,
          $$MinutesVersionsTableFilterComposer,
          $$MinutesVersionsTableOrderingComposer,
          $$MinutesVersionsTableAnnotationComposer,
          $$MinutesVersionsTableCreateCompanionBuilder,
          $$MinutesVersionsTableUpdateCompanionBuilder,
          (MinutesVersionRow, $$MinutesVersionsTableReferences),
          MinutesVersionRow,
          PrefetchHooks Function({bool meetingId})
        > {
  $$MinutesVersionsTableTableManager(
    _$AppDatabase db,
    $MinutesVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MinutesVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MinutesVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MinutesVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> meetingId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> minutesJson = const Value.absent(),
                Value<String> recordJson = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<DateTime> approvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MinutesVersionsCompanion(
                meetingId: meetingId,
                version: version,
                minutesJson: minutesJson,
                recordJson: recordJson,
                contentHash: contentHash,
                approvedAt: approvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String meetingId,
                required int version,
                required String minutesJson,
                required String recordJson,
                required String contentHash,
                required DateTime approvedAt,
                Value<int> rowid = const Value.absent(),
              }) => MinutesVersionsCompanion.insert(
                meetingId: meetingId,
                version: version,
                minutesJson: minutesJson,
                recordJson: recordJson,
                contentHash: contentHash,
                approvedAt: approvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MinutesVersionsTable, MinutesVersionRow>(table),
                  $$MinutesVersionsTableReferences(db, table, e),
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
                        referencedTable: $$MinutesVersionsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$MinutesVersionsTableReferences
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

typedef $$MinutesVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MinutesVersionsTable,
      MinutesVersionRow,
      $$MinutesVersionsTableFilterComposer,
      $$MinutesVersionsTableOrderingComposer,
      $$MinutesVersionsTableAnnotationComposer,
      $$MinutesVersionsTableCreateCompanionBuilder,
      $$MinutesVersionsTableUpdateCompanionBuilder,
      (MinutesVersionRow, $$MinutesVersionsTableReferences),
      MinutesVersionRow,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$MinutesSignaturesTableCreateCompanionBuilder =
    MinutesSignaturesCompanion Function({
      Value<int> id,
      required String meetingId,
      required int version,
      required String signerName,
      Value<String> signerRole,
      required String strokesJson,
      required String contentHash,
      required DateTime signedAt,
    });
typedef $$MinutesSignaturesTableUpdateCompanionBuilder =
    MinutesSignaturesCompanion Function({
      Value<int> id,
      Value<String> meetingId,
      Value<int> version,
      Value<String> signerName,
      Value<String> signerRole,
      Value<String> strokesJson,
      Value<String> contentHash,
      Value<DateTime> signedAt,
    });

final class $$MinutesSignaturesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MinutesSignaturesTable,
          MinutesSignatureRow
        > {
  $$MinutesSignaturesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('minutes_signatures__meeting_id__meetings__id');

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

class $$MinutesSignaturesTableFilterComposer
    extends Composer<_$AppDatabase, $MinutesSignaturesTable> {
  $$MinutesSignaturesTableFilterComposer({
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

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerName => $composableBuilder(
    column: $table.signerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerRole => $composableBuilder(
    column: $table.signerRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strokesJson => $composableBuilder(
    column: $table.strokesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get signedAt =>
      $composableBuilder(
        column: $table.signedAt,
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

class $$MinutesSignaturesTableOrderingComposer
    extends Composer<_$AppDatabase, $MinutesSignaturesTable> {
  $$MinutesSignaturesTableOrderingComposer({
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

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerName => $composableBuilder(
    column: $table.signerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerRole => $composableBuilder(
    column: $table.signerRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strokesJson => $composableBuilder(
    column: $table.strokesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get signedAt => $composableBuilder(
    column: $table.signedAt,
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

class $$MinutesSignaturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MinutesSignaturesTable> {
  $$MinutesSignaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get signerName => $composableBuilder(
    column: $table.signerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signerRole => $composableBuilder(
    column: $table.signerRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get strokesJson => $composableBuilder(
    column: $table.strokesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get signedAt =>
      $composableBuilder(column: $table.signedAt, builder: (column) => column);

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

class $$MinutesSignaturesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MinutesSignaturesTable,
          MinutesSignatureRow,
          $$MinutesSignaturesTableFilterComposer,
          $$MinutesSignaturesTableOrderingComposer,
          $$MinutesSignaturesTableAnnotationComposer,
          $$MinutesSignaturesTableCreateCompanionBuilder,
          $$MinutesSignaturesTableUpdateCompanionBuilder,
          (MinutesSignatureRow, $$MinutesSignaturesTableReferences),
          MinutesSignatureRow,
          PrefetchHooks Function({bool meetingId})
        > {
  $$MinutesSignaturesTableTableManager(
    _$AppDatabase db,
    $MinutesSignaturesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MinutesSignaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MinutesSignaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MinutesSignaturesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> signerName = const Value.absent(),
                Value<String> signerRole = const Value.absent(),
                Value<String> strokesJson = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<DateTime> signedAt = const Value.absent(),
              }) => MinutesSignaturesCompanion(
                id: id,
                meetingId: meetingId,
                version: version,
                signerName: signerName,
                signerRole: signerRole,
                strokesJson: strokesJson,
                contentHash: contentHash,
                signedAt: signedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String meetingId,
                required int version,
                required String signerName,
                Value<String> signerRole = const Value.absent(),
                required String strokesJson,
                required String contentHash,
                required DateTime signedAt,
              }) => MinutesSignaturesCompanion.insert(
                id: id,
                meetingId: meetingId,
                version: version,
                signerName: signerName,
                signerRole: signerRole,
                strokesJson: strokesJson,
                contentHash: contentHash,
                signedAt: signedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MinutesSignaturesTable, MinutesSignatureRow>(
                    table,
                  ),
                  $$MinutesSignaturesTableReferences(db, table, e),
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
                        referencedTable: $$MinutesSignaturesTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$MinutesSignaturesTableReferences
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

typedef $$MinutesSignaturesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MinutesSignaturesTable,
      MinutesSignatureRow,
      $$MinutesSignaturesTableFilterComposer,
      $$MinutesSignaturesTableOrderingComposer,
      $$MinutesSignaturesTableAnnotationComposer,
      $$MinutesSignaturesTableCreateCompanionBuilder,
      $$MinutesSignaturesTableUpdateCompanionBuilder,
      (MinutesSignatureRow, $$MinutesSignaturesTableReferences),
      MinutesSignatureRow,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$ConsistencyFindingsTableCreateCompanionBuilder =
    ConsistencyFindingsCompanion Function({
      Value<int> id,
      required String meetingId,
      required String kind,
      required String severity,
      Value<String> status,
      Value<String> origin,
      required String findingKey,
      Value<String> explanation,
      required String newSideJson,
      required String priorSideJson,
      Value<String?> priorMeetingId,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
    });
typedef $$ConsistencyFindingsTableUpdateCompanionBuilder =
    ConsistencyFindingsCompanion Function({
      Value<int> id,
      Value<String> meetingId,
      Value<String> kind,
      Value<String> severity,
      Value<String> status,
      Value<String> origin,
      Value<String> findingKey,
      Value<String> explanation,
      Value<String> newSideJson,
      Value<String> priorSideJson,
      Value<String?> priorMeetingId,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
    });

final class $$ConsistencyFindingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ConsistencyFindingsTable,
          ConsistencyFindingRow
        > {
  $$ConsistencyFindingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('consistency_findings__meeting_id__meetings__id');

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

  static $MeetingsTable _priorMeetingIdTable(_$AppDatabase db) => db.meetings
      .createAlias('consistency_findings__prior_meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager? get priorMeetingId {
    final $_column = $_itemColumn<String>('prior_meeting_id');
    if ($_column == null) return null;
    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_priorMeetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ResolutionAnnotationsTable,
    List<ResolutionAnnotationRow>
  >
  _resolutionAnnotationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.resolutionAnnotations,
        aliasName:
            'consistency_findings__id__resolution_annotations__finding_id',
      );

  $$ResolutionAnnotationsTableProcessedTableManager
  get resolutionAnnotationsRefs {
    final manager = $$ResolutionAnnotationsTableTableManager(
      $_db,
      $_db.resolutionAnnotations,
    ).filter((f) => f.findingId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _resolutionAnnotationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConsistencyFindingsTableFilterComposer
    extends Composer<_$AppDatabase, $ConsistencyFindingsTable> {
  $$ConsistencyFindingsTableFilterComposer({
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

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get findingKey => $composableBuilder(
    column: $table.findingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newSideJson => $composableBuilder(
    column: $table.newSideJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priorSideJson => $composableBuilder(
    column: $table.priorSideJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get resolvedAt =>
      $composableBuilder(
        column: $table.resolvedAt,
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

  $$MeetingsTableFilterComposer get priorMeetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priorMeetingId,
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

  Expression<bool> resolutionAnnotationsRefs(
    Expression<bool> Function($$ResolutionAnnotationsTableFilterComposer f) f,
  ) {
    final $$ResolutionAnnotationsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.resolutionAnnotations,
          getReferencedColumn: (t) => t.findingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ResolutionAnnotationsTableFilterComposer(
                $db: $db,
                $table: $db.resolutionAnnotations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ConsistencyFindingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConsistencyFindingsTable> {
  $$ConsistencyFindingsTableOrderingComposer({
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

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get findingKey => $composableBuilder(
    column: $table.findingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newSideJson => $composableBuilder(
    column: $table.newSideJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priorSideJson => $composableBuilder(
    column: $table.priorSideJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
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

  $$MeetingsTableOrderingComposer get priorMeetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priorMeetingId,
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

class $$ConsistencyFindingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConsistencyFindingsTable> {
  $$ConsistencyFindingsTableAnnotationComposer({
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

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get findingKey => $composableBuilder(
    column: $table.findingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newSideJson => $composableBuilder(
    column: $table.newSideJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priorSideJson => $composableBuilder(
    column: $table.priorSideJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get resolvedAt =>
      $composableBuilder(
        column: $table.resolvedAt,
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

  $$MeetingsTableAnnotationComposer get priorMeetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priorMeetingId,
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

  Expression<T> resolutionAnnotationsRefs<T extends Object>(
    Expression<T> Function($$ResolutionAnnotationsTableAnnotationComposer a) f,
  ) {
    final $$ResolutionAnnotationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.resolutionAnnotations,
          getReferencedColumn: (t) => t.findingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ResolutionAnnotationsTableAnnotationComposer(
                $db: $db,
                $table: $db.resolutionAnnotations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ConsistencyFindingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConsistencyFindingsTable,
          ConsistencyFindingRow,
          $$ConsistencyFindingsTableFilterComposer,
          $$ConsistencyFindingsTableOrderingComposer,
          $$ConsistencyFindingsTableAnnotationComposer,
          $$ConsistencyFindingsTableCreateCompanionBuilder,
          $$ConsistencyFindingsTableUpdateCompanionBuilder,
          (ConsistencyFindingRow, $$ConsistencyFindingsTableReferences),
          ConsistencyFindingRow,
          PrefetchHooks Function({
            bool meetingId,
            bool priorMeetingId,
            bool resolutionAnnotationsRefs,
          })
        > {
  $$ConsistencyFindingsTableTableManager(
    _$AppDatabase db,
    $ConsistencyFindingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConsistencyFindingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConsistencyFindingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConsistencyFindingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> findingKey = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<String> newSideJson = const Value.absent(),
                Value<String> priorSideJson = const Value.absent(),
                Value<String?> priorMeetingId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => ConsistencyFindingsCompanion(
                id: id,
                meetingId: meetingId,
                kind: kind,
                severity: severity,
                status: status,
                origin: origin,
                findingKey: findingKey,
                explanation: explanation,
                newSideJson: newSideJson,
                priorSideJson: priorSideJson,
                priorMeetingId: priorMeetingId,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String meetingId,
                required String kind,
                required String severity,
                Value<String> status = const Value.absent(),
                Value<String> origin = const Value.absent(),
                required String findingKey,
                Value<String> explanation = const Value.absent(),
                required String newSideJson,
                required String priorSideJson,
                Value<String?> priorMeetingId = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => ConsistencyFindingsCompanion.insert(
                id: id,
                meetingId: meetingId,
                kind: kind,
                severity: severity,
                status: status,
                origin: origin,
                findingKey: findingKey,
                explanation: explanation,
                newSideJson: newSideJson,
                priorSideJson: priorSideJson,
                priorMeetingId: priorMeetingId,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConsistencyFindingsTable, ConsistencyFindingRow>(
                    table,
                  ),
                  $$ConsistencyFindingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                meetingId = false,
                priorMeetingId = false,
                resolutionAnnotationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (resolutionAnnotationsRefs) db.resolutionAnnotations,
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
                        if (meetingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.meetingId,
                            referencedTable:
                                $$ConsistencyFindingsTableReferences
                                    ._meetingIdTable(db),
                            referencedColumn:
                                $$ConsistencyFindingsTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (priorMeetingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.priorMeetingId,
                            referencedTable:
                                $$ConsistencyFindingsTableReferences
                                    ._priorMeetingIdTable(db),
                            referencedColumn:
                                $$ConsistencyFindingsTableReferences
                                    ._priorMeetingIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (resolutionAnnotationsRefs)
                        await $_getPrefetchedDataByColumns<
                          ConsistencyFindingRow,
                          $ConsistencyFindingsTable,
                          ResolutionAnnotationRow,
                          $ResolutionAnnotationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ConsistencyFindingsTableReferences
                              ._resolutionAnnotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConsistencyFindingsTableReferences(
                                db,
                                table,
                                p0,
                              ).resolutionAnnotationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'finding_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConsistencyFindingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConsistencyFindingsTable,
      ConsistencyFindingRow,
      $$ConsistencyFindingsTableFilterComposer,
      $$ConsistencyFindingsTableOrderingComposer,
      $$ConsistencyFindingsTableAnnotationComposer,
      $$ConsistencyFindingsTableCreateCompanionBuilder,
      $$ConsistencyFindingsTableUpdateCompanionBuilder,
      (ConsistencyFindingRow, $$ConsistencyFindingsTableReferences),
      ConsistencyFindingRow,
      PrefetchHooks Function({
        bool meetingId,
        bool priorMeetingId,
        bool resolutionAnnotationsRefs,
      })
    >;
typedef $$ResolutionAnnotationsTableCreateCompanionBuilder =
    ResolutionAnnotationsCompanion Function({
      Value<int> id,
      required String meetingId,
      required int decisionIndex,
      required String decisionKey,
      Value<String> kind,
      required String byMeetingId,
      required int findingId,
      required String bySideJson,
      required DateTime createdAt,
    });
typedef $$ResolutionAnnotationsTableUpdateCompanionBuilder =
    ResolutionAnnotationsCompanion Function({
      Value<int> id,
      Value<String> meetingId,
      Value<int> decisionIndex,
      Value<String> decisionKey,
      Value<String> kind,
      Value<String> byMeetingId,
      Value<int> findingId,
      Value<String> bySideJson,
      Value<DateTime> createdAt,
    });

final class $$ResolutionAnnotationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ResolutionAnnotationsTable,
          ResolutionAnnotationRow
        > {
  $$ResolutionAnnotationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) => db.meetings
      .createAlias('resolution_annotations__meeting_id__meetings__id');

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

  static $MeetingsTable _byMeetingIdTable(_$AppDatabase db) => db.meetings
      .createAlias('resolution_annotations__by_meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get byMeetingId {
    final $_column = $_itemColumn<String>('by_meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_byMeetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ConsistencyFindingsTable _findingIdTable(_$AppDatabase db) =>
      db.consistencyFindings.createAlias(
        'resolution_annotations__finding_id__consistency_findings__id',
      );

  $$ConsistencyFindingsTableProcessedTableManager get findingId {
    final $_column = $_itemColumn<int>('finding_id')!;

    final manager = $$ConsistencyFindingsTableTableManager(
      $_db,
      $_db.consistencyFindings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_findingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ResolutionAnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $ResolutionAnnotationsTable> {
  $$ResolutionAnnotationsTableFilterComposer({
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

  ColumnFilters<int> get decisionIndex => $composableBuilder(
    column: $table.decisionIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decisionKey => $composableBuilder(
    column: $table.decisionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bySideJson => $composableBuilder(
    column: $table.bySideJson,
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

  $$MeetingsTableFilterComposer get byMeetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.byMeetingId,
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

  $$ConsistencyFindingsTableFilterComposer get findingId {
    final $$ConsistencyFindingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.findingId,
      referencedTable: $db.consistencyFindings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConsistencyFindingsTableFilterComposer(
            $db: $db,
            $table: $db.consistencyFindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResolutionAnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ResolutionAnnotationsTable> {
  $$ResolutionAnnotationsTableOrderingComposer({
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

  ColumnOrderings<int> get decisionIndex => $composableBuilder(
    column: $table.decisionIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decisionKey => $composableBuilder(
    column: $table.decisionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bySideJson => $composableBuilder(
    column: $table.bySideJson,
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

  $$MeetingsTableOrderingComposer get byMeetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.byMeetingId,
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

  $$ConsistencyFindingsTableOrderingComposer get findingId {
    final $$ConsistencyFindingsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.findingId,
          referencedTable: $db.consistencyFindings,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConsistencyFindingsTableOrderingComposer(
                $db: $db,
                $table: $db.consistencyFindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ResolutionAnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResolutionAnnotationsTable> {
  $$ResolutionAnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get decisionIndex => $composableBuilder(
    column: $table.decisionIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decisionKey => $composableBuilder(
    column: $table.decisionKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get bySideJson => $composableBuilder(
    column: $table.bySideJson,
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

  $$MeetingsTableAnnotationComposer get byMeetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.byMeetingId,
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

  $$ConsistencyFindingsTableAnnotationComposer get findingId {
    final $$ConsistencyFindingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.findingId,
          referencedTable: $db.consistencyFindings,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConsistencyFindingsTableAnnotationComposer(
                $db: $db,
                $table: $db.consistencyFindings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ResolutionAnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResolutionAnnotationsTable,
          ResolutionAnnotationRow,
          $$ResolutionAnnotationsTableFilterComposer,
          $$ResolutionAnnotationsTableOrderingComposer,
          $$ResolutionAnnotationsTableAnnotationComposer,
          $$ResolutionAnnotationsTableCreateCompanionBuilder,
          $$ResolutionAnnotationsTableUpdateCompanionBuilder,
          (ResolutionAnnotationRow, $$ResolutionAnnotationsTableReferences),
          ResolutionAnnotationRow,
          PrefetchHooks Function({
            bool meetingId,
            bool byMeetingId,
            bool findingId,
          })
        > {
  $$ResolutionAnnotationsTableTableManager(
    _$AppDatabase db,
    $ResolutionAnnotationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResolutionAnnotationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ResolutionAnnotationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ResolutionAnnotationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<int> decisionIndex = const Value.absent(),
                Value<String> decisionKey = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> byMeetingId = const Value.absent(),
                Value<int> findingId = const Value.absent(),
                Value<String> bySideJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ResolutionAnnotationsCompanion(
                id: id,
                meetingId: meetingId,
                decisionIndex: decisionIndex,
                decisionKey: decisionKey,
                kind: kind,
                byMeetingId: byMeetingId,
                findingId: findingId,
                bySideJson: bySideJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String meetingId,
                required int decisionIndex,
                required String decisionKey,
                Value<String> kind = const Value.absent(),
                required String byMeetingId,
                required int findingId,
                required String bySideJson,
                required DateTime createdAt,
              }) => ResolutionAnnotationsCompanion.insert(
                id: id,
                meetingId: meetingId,
                decisionIndex: decisionIndex,
                decisionKey: decisionKey,
                kind: kind,
                byMeetingId: byMeetingId,
                findingId: findingId,
                bySideJson: bySideJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ResolutionAnnotationsTable,
                    ResolutionAnnotationRow
                  >(table),
                  $$ResolutionAnnotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({meetingId = false, byMeetingId = false, findingId = false}) {
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
                            referencedTable:
                                $$ResolutionAnnotationsTableReferences
                                    ._meetingIdTable(db),
                            referencedColumn:
                                $$ResolutionAnnotationsTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (byMeetingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.byMeetingId,
                            referencedTable:
                                $$ResolutionAnnotationsTableReferences
                                    ._byMeetingIdTable(db),
                            referencedColumn:
                                $$ResolutionAnnotationsTableReferences
                                    ._byMeetingIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (findingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.findingId,
                            referencedTable:
                                $$ResolutionAnnotationsTableReferences
                                    ._findingIdTable(db),
                            referencedColumn:
                                $$ResolutionAnnotationsTableReferences
                                    ._findingIdTable(db)
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

typedef $$ResolutionAnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResolutionAnnotationsTable,
      ResolutionAnnotationRow,
      $$ResolutionAnnotationsTableFilterComposer,
      $$ResolutionAnnotationsTableOrderingComposer,
      $$ResolutionAnnotationsTableAnnotationComposer,
      $$ResolutionAnnotationsTableCreateCompanionBuilder,
      $$ResolutionAnnotationsTableUpdateCompanionBuilder,
      (ResolutionAnnotationRow, $$ResolutionAnnotationsTableReferences),
      ResolutionAnnotationRow,
      PrefetchHooks Function({bool meetingId, bool byMeetingId, bool findingId})
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
  $$TaskDismissalsTableTableManager get taskDismissals =>
      $$TaskDismissalsTableTableManager(_db, _db.taskDismissals);
  $$OfficialRecordsTableTableManager get officialRecords =>
      $$OfficialRecordsTableTableManager(_db, _db.officialRecords);
  $$MinutesVersionsTableTableManager get minutesVersions =>
      $$MinutesVersionsTableTableManager(_db, _db.minutesVersions);
  $$MinutesSignaturesTableTableManager get minutesSignatures =>
      $$MinutesSignaturesTableTableManager(_db, _db.minutesSignatures);
  $$ConsistencyFindingsTableTableManager get consistencyFindings =>
      $$ConsistencyFindingsTableTableManager(_db, _db.consistencyFindings);
  $$ResolutionAnnotationsTableTableManager get resolutionAnnotations =>
      $$ResolutionAnnotationsTableTableManager(_db, _db.resolutionAnnotations);
}
