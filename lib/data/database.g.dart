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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    isNamedByUser,
    createdAt,
    centroid,
    embeddingCount,
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
  const SpeakerRow({
    required this.id,
    required this.name,
    required this.color,
    required this.isNamedByUser,
    required this.createdAt,
    this.centroid,
    required this.embeddingCount,
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
  }) => SpeakerRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    isNamedByUser: isNamedByUser ?? this.isNamedByUser,
    createdAt: createdAt ?? this.createdAt,
    centroid: centroid.present ? centroid.value : this.centroid,
    embeddingCount: embeddingCount ?? this.embeddingCount,
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
          ..write('embeddingCount: $embeddingCount')
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
          other.embeddingCount == this.embeddingCount);
}

class SpeakersCompanion extends UpdateCompanion<SpeakerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<bool> isNamedByUser;
  final Value<DateTime> createdAt;
  final Value<Uint8List?> centroid;
  final Value<int> embeddingCount;
  final Value<int> rowid;
  const SpeakersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.isNamedByUser = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.centroid = const Value.absent(),
    this.embeddingCount = const Value.absent(),
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
  const MeetingRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.status,
    required this.durationMs,
    this.audioPath,
    this.minutesJson,
    this.errorMessage,
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
  }) => MeetingRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    durationMs: durationMs ?? this.durationMs,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    minutesJson: minutesJson.present ? minutesJson.value : this.minutesJson,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
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
          ..write('errorMessage: $errorMessage')
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
          other.errorMessage == this.errorMessage);
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

  /// Confidence (0..1) of the automatic speaker assignment; null when
  /// unknown (rows from schema 1).
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpeakersTable speakers = $SpeakersTable(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $SegmentsTable segments = $SegmentsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index segmentsMeetingIdx = Index(
    'segments_meeting_idx',
    'CREATE INDEX segments_meeting_idx ON segments (meeting_id, idx)',
  );
  late final Index segmentsSpeaker = Index(
    'segments_speaker',
    'CREATE INDEX segments_speaker ON segments (speaker_id)',
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
    segmentsMeetingIdx,
    segmentsSpeaker,
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
          PrefetchHooks Function({bool segmentsRefs})
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
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion(
                id: id,
                name: name,
                color: color,
                isNamedByUser: isNamedByUser,
                createdAt: createdAt,
                centroid: centroid,
                embeddingCount: embeddingCount,
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
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion.insert(
                id: id,
                name: name,
                color: color,
                isNamedByUser: isNamedByUser,
                createdAt: createdAt,
                centroid: centroid,
                embeddingCount: embeddingCount,
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
          prefetchHooksCallback: ({segmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (segmentsRefs) db.segments],
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
                          $$SpeakersTableReferences(db, table, p0).segmentsRefs,
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
      PrefetchHooks Function({bool segmentsRefs})
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
          PrefetchHooks Function({bool segmentsRefs})
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
          prefetchHooksCallback: ({segmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (segmentsRefs) db.segments],
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
                          $$MeetingsTableReferences(db, table, p0).segmentsRefs,
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
      PrefetchHooks Function({bool segmentsRefs})
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
}
