// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TripsTable extends Trips with TableInfo<$TripsTable, TripRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultUserId),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPausedSecondsMeta =
      const VerificationMeta('totalPausedSeconds');
  @override
  late final GeneratedColumn<int> totalPausedSeconds = GeneratedColumn<int>(
    'total_paused_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routePolylineMeta = const VerificationMeta(
    'routePolyline',
  );
  @override
  late final GeneratedColumn<String> routePolyline = GeneratedColumn<String>(
    'route_polyline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionSourceMeta = const VerificationMeta(
    'directionSource',
  );
  @override
  late final GeneratedColumn<String> directionSource = GeneratedColumn<String>(
    'direction_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDirectionSourceTime),
  );
  static const VerificationMeta _timeMovingSecondsMeta = const VerificationMeta(
    'timeMovingSeconds',
  );
  @override
  late final GeneratedColumn<int> timeMovingSeconds = GeneratedColumn<int>(
    'time_moving_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeStuckSecondsMeta = const VerificationMeta(
    'timeStuckSeconds',
  );
  @override
  late final GeneratedColumn<int> timeStuckSeconds = GeneratedColumn<int>(
    'time_stuck_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isManualEntryMeta = const VerificationMeta(
    'isManualEntry',
  );
  @override
  late final GeneratedColumn<bool> isManualEntry = GeneratedColumn<bool>(
    'is_manual_entry',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual_entry" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEditedMeta = const VerificationMeta(
    'isEdited',
  );
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
    'is_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    startTime,
    endTime,
    durationSeconds,
    totalPausedSeconds,
    distanceMeters,
    routePolyline,
    direction,
    directionSource,
    timeMovingSeconds,
    timeStuckSeconds,
    isManualEntry,
    isEdited,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('total_paused_seconds')) {
      context.handle(
        _totalPausedSecondsMeta,
        totalPausedSeconds.isAcceptableOrUnknown(
          data['total_paused_seconds']!,
          _totalPausedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_distanceMetersMeta);
    }
    if (data.containsKey('route_polyline')) {
      context.handle(
        _routePolylineMeta,
        routePolyline.isAcceptableOrUnknown(
          data['route_polyline']!,
          _routePolylineMeta,
        ),
      );
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('direction_source')) {
      context.handle(
        _directionSourceMeta,
        directionSource.isAcceptableOrUnknown(
          data['direction_source']!,
          _directionSourceMeta,
        ),
      );
    }
    if (data.containsKey('time_moving_seconds')) {
      context.handle(
        _timeMovingSecondsMeta,
        timeMovingSeconds.isAcceptableOrUnknown(
          data['time_moving_seconds']!,
          _timeMovingSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeMovingSecondsMeta);
    }
    if (data.containsKey('time_stuck_seconds')) {
      context.handle(
        _timeStuckSecondsMeta,
        timeStuckSeconds.isAcceptableOrUnknown(
          data['time_stuck_seconds']!,
          _timeStuckSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeStuckSecondsMeta);
    }
    if (data.containsKey('is_manual_entry')) {
      context.handle(
        _isManualEntryMeta,
        isManualEntry.isAcceptableOrUnknown(
          data['is_manual_entry']!,
          _isManualEntryMeta,
        ),
      );
    }
    if (data.containsKey('is_edited')) {
      context.handle(
        _isEditedMeta,
        isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      totalPausedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_paused_seconds'],
      )!,
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      )!,
      routePolyline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_polyline'],
      ),
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      directionSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction_source'],
      )!,
      timeMovingSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_moving_seconds'],
      )!,
      timeStuckSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_stuck_seconds'],
      )!,
      isManualEntry: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual_entry'],
      )!,
      isEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edited'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class TripRow extends DataClass implements Insertable<TripRow> {
  /// Client-generated UUID v4. Never null.
  final String id;

  /// Owning user. Defaults to `kDefaultUserId`. Phase 8 auth rewrites
  /// existing rows with the Cognito subject when authentication lands.
  final String userId;

  /// Trip start timestamp, stored in UTC.
  final DateTime startTime;

  /// Trip end timestamp, stored in UTC.
  final DateTime endTime;

  /// ACTIVE trip duration in seconds (D-03). From Phase 18 onward this
  /// means wall-clock time MINUS `totalPausedSeconds` (time spent paused),
  /// computed by finalize. STORAGE is unchanged from Phase 1 — only the
  /// MEANING is redefined. Historical rows are unaffected: with no breaks
  /// `totalPausedSeconds` is 0, so active duration equals wall-clock.
  final int durationSeconds;

  /// Denormalized aggregate of all paused time for this trip, in seconds
  /// (D-02). Default 0 keeps every existing v1/v2 row safe across the
  /// v3 migration — rows that never paused read 0. Written by finalize
  /// (Plan 02) from the sum of `trip_breaks` segment durations, and stored
  /// here so the daily-log list and stats render without a JOIN.
  final int totalPausedSeconds;

  /// Distance from the GPS provider, in meters.
  final double distanceMeters;

  /// Encoded polyline string (Google polyline algorithm). D-01 keeps this
  /// on the trips table; list DAOs MUST project into `TripSummary` so
  /// the column does not load for daily-log renders (Pitfall 7).
  final String? routePolyline;

  /// `'to_office'` or `'to_home'`. Auto-labeled from the morning/evening
  /// cutoff, always user-editable from the trip detail screen.
  final String direction;

  /// Durable record of WHO set [direction] (Phase 21, D-02): one of
  /// [kDirectionSourceManual], [kDirectionSourceGeofence], or
  /// [kDirectionSourceTime].
  ///
  /// Default `'time'` keeps every existing v5 row safe and correct across the
  /// additive v6 migration — historical rows were all time-labeled (SC#5).
  /// Finalize writes `geofence` when the END coord matched a saved anchor,
  /// `manual` when the user overrode, else `time` (D-10). Every manual write
  /// path stamps `manual` (D-03). The Plan 03 backfill re-labels ONLY rows
  /// where this is NOT `manual`, so a user's pick is never clobbered (SC#4).
  final String directionSource;

  /// Time the device reported speed ≥ 10 km/h (kSpeedThresholdKmh).
  final int timeMovingSeconds;

  /// Time the device reported speed < 10 km/h. This is the "stuck in
  /// traffic" signal that drives the weekly stats dashboard.
  final int timeStuckSeconds;

  /// `true` for trips the user typed in by hand (no GPS capture). Manual
  /// entries never have a polyline.
  final bool isManualEntry;

  /// `true` once the user has saved a full edit of this trip (Phase 19,
  /// D-04). Set true by any successful full edit; the default `false`
  /// keeps every historical v1/v2/v3 row safe across the additive v4
  /// migration (no UPDATE/DROP of existing rows). The trip detail / row
  /// UI shows a "~ estimated" hint on the moving/stuck figures when this
  /// is true, because Phase 18 deletes raw speed samples at finalize, so
  /// re-edited moving/stuck are DERIVED via proportional rescale (D-01),
  /// not measured from GPS.
  final bool isEdited;

  /// Insertion time. Defaults to `CURRENT_TIMESTAMP` so the DAO does
  /// not have to set it explicitly.
  final DateTime createdAt;

  /// Last-modified time. Currently updated manually by the DAO on
  /// every write; future Phase 3 code may move this to a trigger.
  final DateTime updatedAt;
  const TripRow({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalPausedSeconds,
    required this.distanceMeters,
    this.routePolyline,
    required this.direction,
    required this.directionSource,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
    required this.isManualEntry,
    required this.isEdited,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['total_paused_seconds'] = Variable<int>(totalPausedSeconds);
    map['distance_meters'] = Variable<double>(distanceMeters);
    if (!nullToAbsent || routePolyline != null) {
      map['route_polyline'] = Variable<String>(routePolyline);
    }
    map['direction'] = Variable<String>(direction);
    map['direction_source'] = Variable<String>(directionSource);
    map['time_moving_seconds'] = Variable<int>(timeMovingSeconds);
    map['time_stuck_seconds'] = Variable<int>(timeStuckSeconds);
    map['is_manual_entry'] = Variable<bool>(isManualEntry);
    map['is_edited'] = Variable<bool>(isEdited);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      userId: Value(userId),
      startTime: Value(startTime),
      endTime: Value(endTime),
      durationSeconds: Value(durationSeconds),
      totalPausedSeconds: Value(totalPausedSeconds),
      distanceMeters: Value(distanceMeters),
      routePolyline: routePolyline == null && nullToAbsent
          ? const Value.absent()
          : Value(routePolyline),
      direction: Value(direction),
      directionSource: Value(directionSource),
      timeMovingSeconds: Value(timeMovingSeconds),
      timeStuckSeconds: Value(timeStuckSeconds),
      isManualEntry: Value(isManualEntry),
      isEdited: Value(isEdited),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TripRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      totalPausedSeconds: serializer.fromJson<int>(json['totalPausedSeconds']),
      distanceMeters: serializer.fromJson<double>(json['distanceMeters']),
      routePolyline: serializer.fromJson<String?>(json['routePolyline']),
      direction: serializer.fromJson<String>(json['direction']),
      directionSource: serializer.fromJson<String>(json['directionSource']),
      timeMovingSeconds: serializer.fromJson<int>(json['timeMovingSeconds']),
      timeStuckSeconds: serializer.fromJson<int>(json['timeStuckSeconds']),
      isManualEntry: serializer.fromJson<bool>(json['isManualEntry']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'totalPausedSeconds': serializer.toJson<int>(totalPausedSeconds),
      'distanceMeters': serializer.toJson<double>(distanceMeters),
      'routePolyline': serializer.toJson<String?>(routePolyline),
      'direction': serializer.toJson<String>(direction),
      'directionSource': serializer.toJson<String>(directionSource),
      'timeMovingSeconds': serializer.toJson<int>(timeMovingSeconds),
      'timeStuckSeconds': serializer.toJson<int>(timeStuckSeconds),
      'isManualEntry': serializer.toJson<bool>(isManualEntry),
      'isEdited': serializer.toJson<bool>(isEdited),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TripRow copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? totalPausedSeconds,
    double? distanceMeters,
    Value<String?> routePolyline = const Value.absent(),
    String? direction,
    String? directionSource,
    int? timeMovingSeconds,
    int? timeStuckSeconds,
    bool? isManualEntry,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TripRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    routePolyline: routePolyline.present
        ? routePolyline.value
        : this.routePolyline,
    direction: direction ?? this.direction,
    directionSource: directionSource ?? this.directionSource,
    timeMovingSeconds: timeMovingSeconds ?? this.timeMovingSeconds,
    timeStuckSeconds: timeStuckSeconds ?? this.timeStuckSeconds,
    isManualEntry: isManualEntry ?? this.isManualEntry,
    isEdited: isEdited ?? this.isEdited,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TripRow copyWithCompanion(TripsCompanion data) {
    return TripRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      totalPausedSeconds: data.totalPausedSeconds.present
          ? data.totalPausedSeconds.value
          : this.totalPausedSeconds,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      routePolyline: data.routePolyline.present
          ? data.routePolyline.value
          : this.routePolyline,
      direction: data.direction.present ? data.direction.value : this.direction,
      directionSource: data.directionSource.present
          ? data.directionSource.value
          : this.directionSource,
      timeMovingSeconds: data.timeMovingSeconds.present
          ? data.timeMovingSeconds.value
          : this.timeMovingSeconds,
      timeStuckSeconds: data.timeStuckSeconds.present
          ? data.timeStuckSeconds.value
          : this.timeStuckSeconds,
      isManualEntry: data.isManualEntry.present
          ? data.isManualEntry.value
          : this.isManualEntry,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalPausedSeconds: $totalPausedSeconds, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('routePolyline: $routePolyline, ')
          ..write('direction: $direction, ')
          ..write('directionSource: $directionSource, ')
          ..write('timeMovingSeconds: $timeMovingSeconds, ')
          ..write('timeStuckSeconds: $timeStuckSeconds, ')
          ..write('isManualEntry: $isManualEntry, ')
          ..write('isEdited: $isEdited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    startTime,
    endTime,
    durationSeconds,
    totalPausedSeconds,
    distanceMeters,
    routePolyline,
    direction,
    directionSource,
    timeMovingSeconds,
    timeStuckSeconds,
    isManualEntry,
    isEdited,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.durationSeconds == this.durationSeconds &&
          other.totalPausedSeconds == this.totalPausedSeconds &&
          other.distanceMeters == this.distanceMeters &&
          other.routePolyline == this.routePolyline &&
          other.direction == this.direction &&
          other.directionSource == this.directionSource &&
          other.timeMovingSeconds == this.timeMovingSeconds &&
          other.timeStuckSeconds == this.timeStuckSeconds &&
          other.isManualEntry == this.isManualEntry &&
          other.isEdited == this.isEdited &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TripsCompanion extends UpdateCompanion<TripRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<int> durationSeconds;
  final Value<int> totalPausedSeconds;
  final Value<double> distanceMeters;
  final Value<String?> routePolyline;
  final Value<String> direction;
  final Value<String> directionSource;
  final Value<int> timeMovingSeconds;
  final Value<int> timeStuckSeconds;
  final Value<bool> isManualEntry;
  final Value<bool> isEdited;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.totalPausedSeconds = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.routePolyline = const Value.absent(),
    this.direction = const Value.absent(),
    this.directionSource = const Value.absent(),
    this.timeMovingSeconds = const Value.absent(),
    this.timeStuckSeconds = const Value.absent(),
    this.isManualEntry = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required DateTime startTime,
    required DateTime endTime,
    required int durationSeconds,
    this.totalPausedSeconds = const Value.absent(),
    required double distanceMeters,
    this.routePolyline = const Value.absent(),
    required String direction,
    this.directionSource = const Value.absent(),
    required int timeMovingSeconds,
    required int timeStuckSeconds,
    this.isManualEntry = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startTime = Value(startTime),
       endTime = Value(endTime),
       durationSeconds = Value(durationSeconds),
       distanceMeters = Value(distanceMeters),
       direction = Value(direction),
       timeMovingSeconds = Value(timeMovingSeconds),
       timeStuckSeconds = Value(timeStuckSeconds);
  static Insertable<TripRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<int>? durationSeconds,
    Expression<int>? totalPausedSeconds,
    Expression<double>? distanceMeters,
    Expression<String>? routePolyline,
    Expression<String>? direction,
    Expression<String>? directionSource,
    Expression<int>? timeMovingSeconds,
    Expression<int>? timeStuckSeconds,
    Expression<bool>? isManualEntry,
    Expression<bool>? isEdited,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (totalPausedSeconds != null)
        'total_paused_seconds': totalPausedSeconds,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (routePolyline != null) 'route_polyline': routePolyline,
      if (direction != null) 'direction': direction,
      if (directionSource != null) 'direction_source': directionSource,
      if (timeMovingSeconds != null) 'time_moving_seconds': timeMovingSeconds,
      if (timeStuckSeconds != null) 'time_stuck_seconds': timeStuckSeconds,
      if (isManualEntry != null) 'is_manual_entry': isManualEntry,
      if (isEdited != null) 'is_edited': isEdited,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<DateTime>? startTime,
    Value<DateTime>? endTime,
    Value<int>? durationSeconds,
    Value<int>? totalPausedSeconds,
    Value<double>? distanceMeters,
    Value<String?>? routePolyline,
    Value<String>? direction,
    Value<String>? directionSource,
    Value<int>? timeMovingSeconds,
    Value<int>? timeStuckSeconds,
    Value<bool>? isManualEntry,
    Value<bool>? isEdited,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      routePolyline: routePolyline ?? this.routePolyline,
      direction: direction ?? this.direction,
      directionSource: directionSource ?? this.directionSource,
      timeMovingSeconds: timeMovingSeconds ?? this.timeMovingSeconds,
      timeStuckSeconds: timeStuckSeconds ?? this.timeStuckSeconds,
      isManualEntry: isManualEntry ?? this.isManualEntry,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (totalPausedSeconds.present) {
      map['total_paused_seconds'] = Variable<int>(totalPausedSeconds.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (routePolyline.present) {
      map['route_polyline'] = Variable<String>(routePolyline.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (directionSource.present) {
      map['direction_source'] = Variable<String>(directionSource.value);
    }
    if (timeMovingSeconds.present) {
      map['time_moving_seconds'] = Variable<int>(timeMovingSeconds.value);
    }
    if (timeStuckSeconds.present) {
      map['time_stuck_seconds'] = Variable<int>(timeStuckSeconds.value);
    }
    if (isManualEntry.present) {
      map['is_manual_entry'] = Variable<bool>(isManualEntry.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalPausedSeconds: $totalPausedSeconds, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('routePolyline: $routePolyline, ')
          ..write('direction: $direction, ')
          ..write('directionSource: $directionSource, ')
          ..write('timeMovingSeconds: $timeMovingSeconds, ')
          ..write('timeStuckSeconds: $timeStuckSeconds, ')
          ..write('isManualEntry: $isManualEntry, ')
          ..write('isEdited: $isEdited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
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
    defaultValue: const Constant(kSyncStatusPending),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    action,
    payload,
    status,
    retryCount,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueRow extends DataClass implements Insertable<SyncQueueRow> {
  /// Auto-increment primary key. Distinct from the trip UUID so the
  /// same trip can have multiple queued actions (e.g. create → update).
  final int id;

  /// Foreign-key-ish reference to `trips.id`. Not a hard FK because the
  /// trip row may be deleted before the delete action is flushed.
  final String tripId;

  /// `'create'`, `'update'`, or `'delete'`. Consumer code should use the
  /// `kSyncActionCreate/Update/Delete` constants from `constants.dart`
  /// once plan 01-02 lands.
  final String action;

  /// D-13: nullable text. Populated ONLY for delete actions with a JSON
  /// snapshot `{id, user_id}` so the server can tombstone without the
  /// now-missing trip row. Null for create/update.
  final String? payload;

  /// Defaults to `kSyncStatusPending`. Moves to synced / failed via the
  /// sync engine (Phase 9).
  final String status;

  /// Monotonic retry counter; the sync engine gives up after 3 attempts
  /// and promotes the row to `'failed'`.
  final int retryCount;

  /// Insertion time of the queue row, not of the underlying trip.
  final DateTime createdAt;

  /// Set when the row transitions to `'synced'`. Null while pending/failed.
  final DateTime? syncedAt;
  const SyncQueueRow({
    required this.id,
    required this.tripId,
    required this.action,
    this.payload,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      tripId: Value(tripId),
      action: Value(action),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      status: Value(status),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory SyncQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueRow(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      action: serializer.fromJson<String>(json['action']),
      payload: serializer.fromJson<String?>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<String>(tripId),
      'action': serializer.toJson<String>(action),
      'payload': serializer.toJson<String?>(payload),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  SyncQueueRow copyWith({
    int? id,
    String? tripId,
    String? action,
    Value<String?> payload = const Value.absent(),
    String? status,
    int? retryCount,
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => SyncQueueRow(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    action: action ?? this.action,
    payload: payload.present ? payload.value : this.payload,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  SyncQueueRow copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      action: data.action.present ? data.action.value : this.action,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    action,
    payload,
    status,
    retryCount,
    createdAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.action == this.action &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueRow> {
  final Value<int> id;
  final Value<String> tripId;
  final Value<String> action;
  final Value<String?> payload;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.action = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String tripId,
    required String action,
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : tripId = Value(tripId),
       action = Value(action);
  static Insertable<SyncQueueRow> custom({
    Expression<int>? id,
    Expression<String>? tripId,
    Expression<String>? action,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (action != null) 'action': action,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? tripId,
    Value<String>? action,
    Value<String?>? payload,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreferencesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultUserId),
  );
  static const VerificationMeta _darkModeMeta = const VerificationMeta(
    'darkMode',
  );
  @override
  late final GeneratedColumn<String> darkMode = GeneratedColumn<String>(
    'dark_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDarkModeSystem),
  );
  static const VerificationMeta _morningCutoffHourMeta = const VerificationMeta(
    'morningCutoffHour',
  );
  @override
  late final GeneratedColumn<int> morningCutoffHour = GeneratedColumn<int>(
    'morning_cutoff_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultDirectionCutoffHour),
  );
  static const VerificationMeta _eveningCutoffHourMeta = const VerificationMeta(
    'eveningCutoffHour',
  );
  @override
  late final GeneratedColumn<int> eveningCutoffHour = GeneratedColumn<int>(
    'evening_cutoff_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultDirectionCutoffHour),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderTimeMeta = const VerificationMeta(
    'reminderTime',
  );
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
    'reminder_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekendReminderMeta = const VerificationMeta(
    'weekendReminder',
  );
  @override
  late final GeneratedColumn<bool> weekendReminder = GeneratedColumn<bool>(
    'weekend_reminder',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("weekend_reminder" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _weeklyNotificationEnabledMeta =
      const VerificationMeta('weeklyNotificationEnabled');
  @override
  late final GeneratedColumn<bool> weeklyNotificationEnabled =
      GeneratedColumn<bool>(
        'weekly_notification_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("weekly_notification_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _autoPauseEnabledMeta = const VerificationMeta(
    'autoPauseEnabled',
  );
  @override
  late final GeneratedColumn<bool> autoPauseEnabled = GeneratedColumn<bool>(
    'auto_pause_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_pause_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _hasSeenOnboardingMeta = const VerificationMeta(
    'hasSeenOnboarding',
  );
  @override
  late final GeneratedColumn<bool> hasSeenOnboarding = GeneratedColumn<bool>(
    'has_seen_onboarding',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_seen_onboarding" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _homeLatMeta = const VerificationMeta(
    'homeLat',
  );
  @override
  late final GeneratedColumn<double> homeLat = GeneratedColumn<double>(
    'home_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeLngMeta = const VerificationMeta(
    'homeLng',
  );
  @override
  late final GeneratedColumn<double> homeLng = GeneratedColumn<double>(
    'home_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officeLatMeta = const VerificationMeta(
    'officeLat',
  );
  @override
  late final GeneratedColumn<double> officeLat = GeneratedColumn<double>(
    'office_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officeLngMeta = const VerificationMeta(
    'officeLng',
  );
  @override
  late final GeneratedColumn<double> officeLng = GeneratedColumn<double>(
    'office_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backfillMarkerVersionMeta =
      const VerificationMeta('backfillMarkerVersion');
  @override
  late final GeneratedColumn<int> backfillMarkerVersion = GeneratedColumn<int>(
    'backfill_marker_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seenToursMeta = const VerificationMeta(
    'seenTours',
  );
  @override
  late final GeneratedColumn<String> seenTours = GeneratedColumn<String>(
    'seen_tours',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    darkMode,
    morningCutoffHour,
    eveningCutoffHour,
    reminderEnabled,
    reminderTime,
    weekendReminder,
    weeklyNotificationEnabled,
    autoPauseEnabled,
    hasSeenOnboarding,
    homeLat,
    homeLng,
    officeLat,
    officeLng,
    backfillMarkerVersion,
    seenTours,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreferencesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('dark_mode')) {
      context.handle(
        _darkModeMeta,
        darkMode.isAcceptableOrUnknown(data['dark_mode']!, _darkModeMeta),
      );
    }
    if (data.containsKey('morning_cutoff_hour')) {
      context.handle(
        _morningCutoffHourMeta,
        morningCutoffHour.isAcceptableOrUnknown(
          data['morning_cutoff_hour']!,
          _morningCutoffHourMeta,
        ),
      );
    }
    if (data.containsKey('evening_cutoff_hour')) {
      context.handle(
        _eveningCutoffHourMeta,
        eveningCutoffHour.isAcceptableOrUnknown(
          data['evening_cutoff_hour']!,
          _eveningCutoffHourMeta,
        ),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
        _reminderTimeMeta,
        reminderTime.isAcceptableOrUnknown(
          data['reminder_time']!,
          _reminderTimeMeta,
        ),
      );
    }
    if (data.containsKey('weekend_reminder')) {
      context.handle(
        _weekendReminderMeta,
        weekendReminder.isAcceptableOrUnknown(
          data['weekend_reminder']!,
          _weekendReminderMeta,
        ),
      );
    }
    if (data.containsKey('weekly_notification_enabled')) {
      context.handle(
        _weeklyNotificationEnabledMeta,
        weeklyNotificationEnabled.isAcceptableOrUnknown(
          data['weekly_notification_enabled']!,
          _weeklyNotificationEnabledMeta,
        ),
      );
    }
    if (data.containsKey('auto_pause_enabled')) {
      context.handle(
        _autoPauseEnabledMeta,
        autoPauseEnabled.isAcceptableOrUnknown(
          data['auto_pause_enabled']!,
          _autoPauseEnabledMeta,
        ),
      );
    }
    if (data.containsKey('has_seen_onboarding')) {
      context.handle(
        _hasSeenOnboardingMeta,
        hasSeenOnboarding.isAcceptableOrUnknown(
          data['has_seen_onboarding']!,
          _hasSeenOnboardingMeta,
        ),
      );
    }
    if (data.containsKey('home_lat')) {
      context.handle(
        _homeLatMeta,
        homeLat.isAcceptableOrUnknown(data['home_lat']!, _homeLatMeta),
      );
    }
    if (data.containsKey('home_lng')) {
      context.handle(
        _homeLngMeta,
        homeLng.isAcceptableOrUnknown(data['home_lng']!, _homeLngMeta),
      );
    }
    if (data.containsKey('office_lat')) {
      context.handle(
        _officeLatMeta,
        officeLat.isAcceptableOrUnknown(data['office_lat']!, _officeLatMeta),
      );
    }
    if (data.containsKey('office_lng')) {
      context.handle(
        _officeLngMeta,
        officeLng.isAcceptableOrUnknown(data['office_lng']!, _officeLngMeta),
      );
    }
    if (data.containsKey('backfill_marker_version')) {
      context.handle(
        _backfillMarkerVersionMeta,
        backfillMarkerVersion.isAcceptableOrUnknown(
          data['backfill_marker_version']!,
          _backfillMarkerVersionMeta,
        ),
      );
    }
    if (data.containsKey('seen_tours')) {
      context.handle(
        _seenToursMeta,
        seenTours.isAcceptableOrUnknown(data['seen_tours']!, _seenToursMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreferencesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreferencesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      darkMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dark_mode'],
      )!,
      morningCutoffHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}morning_cutoff_hour'],
      )!,
      eveningCutoffHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evening_cutoff_hour'],
      )!,
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time'],
      ),
      weekendReminder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}weekend_reminder'],
      )!,
      weeklyNotificationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}weekly_notification_enabled'],
      )!,
      autoPauseEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_pause_enabled'],
      )!,
      hasSeenOnboarding: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_seen_onboarding'],
      )!,
      homeLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}home_lat'],
      ),
      homeLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}home_lng'],
      ),
      officeLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}office_lat'],
      ),
      officeLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}office_lng'],
      ),
      backfillMarkerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backfill_marker_version'],
      )!,
      seenTours: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seen_tours'],
      )!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreferencesRow extends DataClass
    implements Insertable<UserPreferencesRow> {
  /// Non-auto-increment integer so callers always write `id = 1`. There
  /// is exactly one row per app install in Phase 1.
  final int id;

  /// Owning user. Defaults to `kDefaultUserId`; Phase 8 replaces this
  /// with the Cognito sub.
  final String userId;

  /// `'system'`, `'light'`, or `'dark'`. Default: `kDarkModeSystem`.
  final String darkMode;

  /// Hour (0-23) before which starting trips auto-label as `'to_office'`.
  /// Default: `kDefaultDirectionCutoffHour`.
  final int morningCutoffHour;

  /// Hour (0-23) after which starting trips auto-label as `'to_home'`.
  /// Default: `kDefaultDirectionCutoffHour`.
  final int eveningCutoffHour;

  /// True if the user has opted into the daily tracking reminder.
  final bool reminderEnabled;

  /// `HH:mm` formatted local time. Null when no reminder is scheduled.
  final String? reminderTime;

  /// True if the reminder should also fire on Saturday and Sunday.
  final bool weekendReminder;

  /// True if the user has opted into the weekly commute summary notification.
  ///
  /// Default false so no notification fires until the user enables it.
  /// Added by schema migration v1 → v2 (D-07, D-13).
  final bool weeklyNotificationEnabled;

  /// True if the user has opted into auto-pause (Phase 18, D-10; default
  /// flipped Phase 27, UX-08).
  ///
  /// Added by schema migration v2 → v3 with a `false` (opt-in) default.
  /// Phase 27 (UX-08) flips the DEFAULT to `true` — auto-pause is now ON
  /// out of the box for fresh installs — while the v7 → v8 migration
  /// explicitly backfills every EXISTING row to `true` too, so upgraded
  /// installs get the same behaviour change (see `database.dart` v8
  /// branch). `withDefault(const Constant(true))` covers the `onCreate`
  /// (fresh-install, no row) path only; it does NOT retroactively change
  /// already-created rows, hence the explicit backfill.
  final bool autoPauseEnabled;

  /// True once the user has cleared the first-run login wall (Phase 20,
  /// D-01/D-02). Drives the root gate in `lib/app.dart`: while false a guest
  /// sees the `LoginScreen`; after Skip or a successful Google sign-in it
  /// flips true and the gate routes to the main shell.
  ///
  /// Default false. Added by schema migration v4 → v5; the migration's
  /// returning-user guard (D-02) flips the EXISTING single row to true so a
  /// pre-update install is NEVER walled — the login screen is first-INSTALL
  /// only. Fresh installs run `onCreate` (no row) → `getOrDefault()` returns
  /// false → the wall shows exactly once.
  final bool hasSeenOnboarding;

  /// Saved Home latitude (Phase 21, D-01). Null = not set; single-row table.
  ///
  /// PII-adjacent — this coordinate reveals where the user lives. NEVER log it
  /// (T-21-03). Stored locally in Drift only; no sync field carries it.
  /// Added by schema migration v5 → v6 (additive); existing rows read null.
  final double? homeLat;

  /// Saved Home longitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// NEVER log (T-21-03). Added by schema migration v5 → v6 (additive).
  final double? homeLng;

  /// Saved Office latitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// NEVER log (T-21-03). Added by schema migration v5 → v6 (additive).
  final double? officeLat;

  /// Saved Office longitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// NEVER log (T-21-03). Added by schema migration v5 → v6 (additive).
  final double? officeLng;

  /// Version-keyed backfill marker (Phase 26, D-03): tracks "backfill done
  /// for payload schema v{N}" so the one-time re-sync for trips with breaks
  /// or edits runs at most once per target schema version, not once per app
  /// launch. `0` = backfill has never run on this install. Compared against
  /// `kBackfillMarkerVersion` (`lib/config/constants.dart`) by
  /// `UserPreferencesDao.getBackfillMarkerVersion()`. Added by schema
  /// migration v6 → v7 (additive).
  final int backfillMarkerVersion;

  /// CSV of page keys whose one-time guided tour has already been shown
  /// (Phase 27, UX-07 tour persistence scaffold). Empty string = no tour
  /// seen yet. Parsed into a `Set<String>` by
  /// `UserPreferencesValue.seenTourKeys`; mutated one key at a time by
  /// `UserPreferencesDao.markTourSeen()`. Added by schema migration v7 →
  /// v8 (additive) — existing rows read `''` (no tours seen), so every
  /// upgraded install still sees each page's tour once, same as a fresh
  /// install.
  final String seenTours;
  const UserPreferencesRow({
    required this.id,
    required this.userId,
    required this.darkMode,
    required this.morningCutoffHour,
    required this.eveningCutoffHour,
    required this.reminderEnabled,
    this.reminderTime,
    required this.weekendReminder,
    required this.weeklyNotificationEnabled,
    required this.autoPauseEnabled,
    required this.hasSeenOnboarding,
    this.homeLat,
    this.homeLng,
    this.officeLat,
    this.officeLng,
    required this.backfillMarkerVersion,
    required this.seenTours,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['dark_mode'] = Variable<String>(darkMode);
    map['morning_cutoff_hour'] = Variable<int>(morningCutoffHour);
    map['evening_cutoff_hour'] = Variable<int>(eveningCutoffHour);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    if (!nullToAbsent || reminderTime != null) {
      map['reminder_time'] = Variable<String>(reminderTime);
    }
    map['weekend_reminder'] = Variable<bool>(weekendReminder);
    map['weekly_notification_enabled'] = Variable<bool>(
      weeklyNotificationEnabled,
    );
    map['auto_pause_enabled'] = Variable<bool>(autoPauseEnabled);
    map['has_seen_onboarding'] = Variable<bool>(hasSeenOnboarding);
    if (!nullToAbsent || homeLat != null) {
      map['home_lat'] = Variable<double>(homeLat);
    }
    if (!nullToAbsent || homeLng != null) {
      map['home_lng'] = Variable<double>(homeLng);
    }
    if (!nullToAbsent || officeLat != null) {
      map['office_lat'] = Variable<double>(officeLat);
    }
    if (!nullToAbsent || officeLng != null) {
      map['office_lng'] = Variable<double>(officeLng);
    }
    map['backfill_marker_version'] = Variable<int>(backfillMarkerVersion);
    map['seen_tours'] = Variable<String>(seenTours);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      id: Value(id),
      userId: Value(userId),
      darkMode: Value(darkMode),
      morningCutoffHour: Value(morningCutoffHour),
      eveningCutoffHour: Value(eveningCutoffHour),
      reminderEnabled: Value(reminderEnabled),
      reminderTime: reminderTime == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTime),
      weekendReminder: Value(weekendReminder),
      weeklyNotificationEnabled: Value(weeklyNotificationEnabled),
      autoPauseEnabled: Value(autoPauseEnabled),
      hasSeenOnboarding: Value(hasSeenOnboarding),
      homeLat: homeLat == null && nullToAbsent
          ? const Value.absent()
          : Value(homeLat),
      homeLng: homeLng == null && nullToAbsent
          ? const Value.absent()
          : Value(homeLng),
      officeLat: officeLat == null && nullToAbsent
          ? const Value.absent()
          : Value(officeLat),
      officeLng: officeLng == null && nullToAbsent
          ? const Value.absent()
          : Value(officeLng),
      backfillMarkerVersion: Value(backfillMarkerVersion),
      seenTours: Value(seenTours),
    );
  }

  factory UserPreferencesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreferencesRow(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      darkMode: serializer.fromJson<String>(json['darkMode']),
      morningCutoffHour: serializer.fromJson<int>(json['morningCutoffHour']),
      eveningCutoffHour: serializer.fromJson<int>(json['eveningCutoffHour']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderTime: serializer.fromJson<String?>(json['reminderTime']),
      weekendReminder: serializer.fromJson<bool>(json['weekendReminder']),
      weeklyNotificationEnabled: serializer.fromJson<bool>(
        json['weeklyNotificationEnabled'],
      ),
      autoPauseEnabled: serializer.fromJson<bool>(json['autoPauseEnabled']),
      hasSeenOnboarding: serializer.fromJson<bool>(json['hasSeenOnboarding']),
      homeLat: serializer.fromJson<double?>(json['homeLat']),
      homeLng: serializer.fromJson<double?>(json['homeLng']),
      officeLat: serializer.fromJson<double?>(json['officeLat']),
      officeLng: serializer.fromJson<double?>(json['officeLng']),
      backfillMarkerVersion: serializer.fromJson<int>(
        json['backfillMarkerVersion'],
      ),
      seenTours: serializer.fromJson<String>(json['seenTours']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'darkMode': serializer.toJson<String>(darkMode),
      'morningCutoffHour': serializer.toJson<int>(morningCutoffHour),
      'eveningCutoffHour': serializer.toJson<int>(eveningCutoffHour),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderTime': serializer.toJson<String?>(reminderTime),
      'weekendReminder': serializer.toJson<bool>(weekendReminder),
      'weeklyNotificationEnabled': serializer.toJson<bool>(
        weeklyNotificationEnabled,
      ),
      'autoPauseEnabled': serializer.toJson<bool>(autoPauseEnabled),
      'hasSeenOnboarding': serializer.toJson<bool>(hasSeenOnboarding),
      'homeLat': serializer.toJson<double?>(homeLat),
      'homeLng': serializer.toJson<double?>(homeLng),
      'officeLat': serializer.toJson<double?>(officeLat),
      'officeLng': serializer.toJson<double?>(officeLng),
      'backfillMarkerVersion': serializer.toJson<int>(backfillMarkerVersion),
      'seenTours': serializer.toJson<String>(seenTours),
    };
  }

  UserPreferencesRow copyWith({
    int? id,
    String? userId,
    String? darkMode,
    int? morningCutoffHour,
    int? eveningCutoffHour,
    bool? reminderEnabled,
    Value<String?> reminderTime = const Value.absent(),
    bool? weekendReminder,
    bool? weeklyNotificationEnabled,
    bool? autoPauseEnabled,
    bool? hasSeenOnboarding,
    Value<double?> homeLat = const Value.absent(),
    Value<double?> homeLng = const Value.absent(),
    Value<double?> officeLat = const Value.absent(),
    Value<double?> officeLng = const Value.absent(),
    int? backfillMarkerVersion,
    String? seenTours,
  }) => UserPreferencesRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    darkMode: darkMode ?? this.darkMode,
    morningCutoffHour: morningCutoffHour ?? this.morningCutoffHour,
    eveningCutoffHour: eveningCutoffHour ?? this.eveningCutoffHour,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderTime: reminderTime.present ? reminderTime.value : this.reminderTime,
    weekendReminder: weekendReminder ?? this.weekendReminder,
    weeklyNotificationEnabled:
        weeklyNotificationEnabled ?? this.weeklyNotificationEnabled,
    autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
    hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    homeLat: homeLat.present ? homeLat.value : this.homeLat,
    homeLng: homeLng.present ? homeLng.value : this.homeLng,
    officeLat: officeLat.present ? officeLat.value : this.officeLat,
    officeLng: officeLng.present ? officeLng.value : this.officeLng,
    backfillMarkerVersion: backfillMarkerVersion ?? this.backfillMarkerVersion,
    seenTours: seenTours ?? this.seenTours,
  );
  UserPreferencesRow copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreferencesRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      darkMode: data.darkMode.present ? data.darkMode.value : this.darkMode,
      morningCutoffHour: data.morningCutoffHour.present
          ? data.morningCutoffHour.value
          : this.morningCutoffHour,
      eveningCutoffHour: data.eveningCutoffHour.present
          ? data.eveningCutoffHour.value
          : this.eveningCutoffHour,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
      weekendReminder: data.weekendReminder.present
          ? data.weekendReminder.value
          : this.weekendReminder,
      weeklyNotificationEnabled: data.weeklyNotificationEnabled.present
          ? data.weeklyNotificationEnabled.value
          : this.weeklyNotificationEnabled,
      autoPauseEnabled: data.autoPauseEnabled.present
          ? data.autoPauseEnabled.value
          : this.autoPauseEnabled,
      hasSeenOnboarding: data.hasSeenOnboarding.present
          ? data.hasSeenOnboarding.value
          : this.hasSeenOnboarding,
      homeLat: data.homeLat.present ? data.homeLat.value : this.homeLat,
      homeLng: data.homeLng.present ? data.homeLng.value : this.homeLng,
      officeLat: data.officeLat.present ? data.officeLat.value : this.officeLat,
      officeLng: data.officeLng.present ? data.officeLng.value : this.officeLng,
      backfillMarkerVersion: data.backfillMarkerVersion.present
          ? data.backfillMarkerVersion.value
          : this.backfillMarkerVersion,
      seenTours: data.seenTours.present ? data.seenTours.value : this.seenTours,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('darkMode: $darkMode, ')
          ..write('morningCutoffHour: $morningCutoffHour, ')
          ..write('eveningCutoffHour: $eveningCutoffHour, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('weekendReminder: $weekendReminder, ')
          ..write('weeklyNotificationEnabled: $weeklyNotificationEnabled, ')
          ..write('autoPauseEnabled: $autoPauseEnabled, ')
          ..write('hasSeenOnboarding: $hasSeenOnboarding, ')
          ..write('homeLat: $homeLat, ')
          ..write('homeLng: $homeLng, ')
          ..write('officeLat: $officeLat, ')
          ..write('officeLng: $officeLng, ')
          ..write('backfillMarkerVersion: $backfillMarkerVersion, ')
          ..write('seenTours: $seenTours')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    darkMode,
    morningCutoffHour,
    eveningCutoffHour,
    reminderEnabled,
    reminderTime,
    weekendReminder,
    weeklyNotificationEnabled,
    autoPauseEnabled,
    hasSeenOnboarding,
    homeLat,
    homeLng,
    officeLat,
    officeLng,
    backfillMarkerVersion,
    seenTours,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreferencesRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.darkMode == this.darkMode &&
          other.morningCutoffHour == this.morningCutoffHour &&
          other.eveningCutoffHour == this.eveningCutoffHour &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderTime == this.reminderTime &&
          other.weekendReminder == this.weekendReminder &&
          other.weeklyNotificationEnabled == this.weeklyNotificationEnabled &&
          other.autoPauseEnabled == this.autoPauseEnabled &&
          other.hasSeenOnboarding == this.hasSeenOnboarding &&
          other.homeLat == this.homeLat &&
          other.homeLng == this.homeLng &&
          other.officeLat == this.officeLat &&
          other.officeLng == this.officeLng &&
          other.backfillMarkerVersion == this.backfillMarkerVersion &&
          other.seenTours == this.seenTours);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreferencesRow> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> darkMode;
  final Value<int> morningCutoffHour;
  final Value<int> eveningCutoffHour;
  final Value<bool> reminderEnabled;
  final Value<String?> reminderTime;
  final Value<bool> weekendReminder;
  final Value<bool> weeklyNotificationEnabled;
  final Value<bool> autoPauseEnabled;
  final Value<bool> hasSeenOnboarding;
  final Value<double?> homeLat;
  final Value<double?> homeLng;
  final Value<double?> officeLat;
  final Value<double?> officeLng;
  final Value<int> backfillMarkerVersion;
  final Value<String> seenTours;
  const UserPreferencesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.darkMode = const Value.absent(),
    this.morningCutoffHour = const Value.absent(),
    this.eveningCutoffHour = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.weekendReminder = const Value.absent(),
    this.weeklyNotificationEnabled = const Value.absent(),
    this.autoPauseEnabled = const Value.absent(),
    this.hasSeenOnboarding = const Value.absent(),
    this.homeLat = const Value.absent(),
    this.homeLng = const Value.absent(),
    this.officeLat = const Value.absent(),
    this.officeLng = const Value.absent(),
    this.backfillMarkerVersion = const Value.absent(),
    this.seenTours = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.darkMode = const Value.absent(),
    this.morningCutoffHour = const Value.absent(),
    this.eveningCutoffHour = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.weekendReminder = const Value.absent(),
    this.weeklyNotificationEnabled = const Value.absent(),
    this.autoPauseEnabled = const Value.absent(),
    this.hasSeenOnboarding = const Value.absent(),
    this.homeLat = const Value.absent(),
    this.homeLng = const Value.absent(),
    this.officeLat = const Value.absent(),
    this.officeLng = const Value.absent(),
    this.backfillMarkerVersion = const Value.absent(),
    this.seenTours = const Value.absent(),
  });
  static Insertable<UserPreferencesRow> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? darkMode,
    Expression<int>? morningCutoffHour,
    Expression<int>? eveningCutoffHour,
    Expression<bool>? reminderEnabled,
    Expression<String>? reminderTime,
    Expression<bool>? weekendReminder,
    Expression<bool>? weeklyNotificationEnabled,
    Expression<bool>? autoPauseEnabled,
    Expression<bool>? hasSeenOnboarding,
    Expression<double>? homeLat,
    Expression<double>? homeLng,
    Expression<double>? officeLat,
    Expression<double>? officeLng,
    Expression<int>? backfillMarkerVersion,
    Expression<String>? seenTours,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (darkMode != null) 'dark_mode': darkMode,
      if (morningCutoffHour != null) 'morning_cutoff_hour': morningCutoffHour,
      if (eveningCutoffHour != null) 'evening_cutoff_hour': eveningCutoffHour,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (weekendReminder != null) 'weekend_reminder': weekendReminder,
      if (weeklyNotificationEnabled != null)
        'weekly_notification_enabled': weeklyNotificationEnabled,
      if (autoPauseEnabled != null) 'auto_pause_enabled': autoPauseEnabled,
      if (hasSeenOnboarding != null) 'has_seen_onboarding': hasSeenOnboarding,
      if (homeLat != null) 'home_lat': homeLat,
      if (homeLng != null) 'home_lng': homeLng,
      if (officeLat != null) 'office_lat': officeLat,
      if (officeLng != null) 'office_lng': officeLng,
      if (backfillMarkerVersion != null)
        'backfill_marker_version': backfillMarkerVersion,
      if (seenTours != null) 'seen_tours': seenTours,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<int>? id,
    Value<String>? userId,
    Value<String>? darkMode,
    Value<int>? morningCutoffHour,
    Value<int>? eveningCutoffHour,
    Value<bool>? reminderEnabled,
    Value<String?>? reminderTime,
    Value<bool>? weekendReminder,
    Value<bool>? weeklyNotificationEnabled,
    Value<bool>? autoPauseEnabled,
    Value<bool>? hasSeenOnboarding,
    Value<double?>? homeLat,
    Value<double?>? homeLng,
    Value<double?>? officeLat,
    Value<double?>? officeLng,
    Value<int>? backfillMarkerVersion,
    Value<String>? seenTours,
  }) {
    return UserPreferencesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      darkMode: darkMode ?? this.darkMode,
      morningCutoffHour: morningCutoffHour ?? this.morningCutoffHour,
      eveningCutoffHour: eveningCutoffHour ?? this.eveningCutoffHour,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      weekendReminder: weekendReminder ?? this.weekendReminder,
      weeklyNotificationEnabled:
          weeklyNotificationEnabled ?? this.weeklyNotificationEnabled,
      autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      officeLat: officeLat ?? this.officeLat,
      officeLng: officeLng ?? this.officeLng,
      backfillMarkerVersion:
          backfillMarkerVersion ?? this.backfillMarkerVersion,
      seenTours: seenTours ?? this.seenTours,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (darkMode.present) {
      map['dark_mode'] = Variable<String>(darkMode.value);
    }
    if (morningCutoffHour.present) {
      map['morning_cutoff_hour'] = Variable<int>(morningCutoffHour.value);
    }
    if (eveningCutoffHour.present) {
      map['evening_cutoff_hour'] = Variable<int>(eveningCutoffHour.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (weekendReminder.present) {
      map['weekend_reminder'] = Variable<bool>(weekendReminder.value);
    }
    if (weeklyNotificationEnabled.present) {
      map['weekly_notification_enabled'] = Variable<bool>(
        weeklyNotificationEnabled.value,
      );
    }
    if (autoPauseEnabled.present) {
      map['auto_pause_enabled'] = Variable<bool>(autoPauseEnabled.value);
    }
    if (hasSeenOnboarding.present) {
      map['has_seen_onboarding'] = Variable<bool>(hasSeenOnboarding.value);
    }
    if (homeLat.present) {
      map['home_lat'] = Variable<double>(homeLat.value);
    }
    if (homeLng.present) {
      map['home_lng'] = Variable<double>(homeLng.value);
    }
    if (officeLat.present) {
      map['office_lat'] = Variable<double>(officeLat.value);
    }
    if (officeLng.present) {
      map['office_lng'] = Variable<double>(officeLng.value);
    }
    if (backfillMarkerVersion.present) {
      map['backfill_marker_version'] = Variable<int>(
        backfillMarkerVersion.value,
      );
    }
    if (seenTours.present) {
      map['seen_tours'] = Variable<String>(seenTours.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('darkMode: $darkMode, ')
          ..write('morningCutoffHour: $morningCutoffHour, ')
          ..write('eveningCutoffHour: $eveningCutoffHour, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('weekendReminder: $weekendReminder, ')
          ..write('weeklyNotificationEnabled: $weeklyNotificationEnabled, ')
          ..write('autoPauseEnabled: $autoPauseEnabled, ')
          ..write('hasSeenOnboarding: $hasSeenOnboarding, ')
          ..write('homeLat: $homeLat, ')
          ..write('homeLng: $homeLng, ')
          ..write('officeLat: $officeLat, ')
          ..write('officeLng: $officeLng, ')
          ..write('backfillMarkerVersion: $backfillMarkerVersion, ')
          ..write('seenTours: $seenTours')
          ..write(')'))
        .toString();
  }
}

class $TripBreaksTable extends TripBreaks
    with TableInfo<$TripBreaksTable, TripBreakRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripBreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id)',
    ),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tripId, startTime, endTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_breaks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripBreakRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripBreakRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripBreakRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
    );
  }

  @override
  $TripBreaksTable createAlias(String alias) {
    return $TripBreaksTable(attachedDatabase, alias);
  }
}

class TripBreakRow extends DataClass implements Insertable<TripBreakRow> {
  /// Client-generated UUID v4 primary key. Never null.
  final String id;

  /// Owning trip. Hard FK to `trips.id`, enforced by
  /// `PRAGMA foreign_keys = ON` (D-01, T-18-02).
  final String tripId;

  /// Break start timestamp (pause), stored in UTC.
  final DateTime startTime;

  /// Break end timestamp (resume), stored in UTC. Null while the break is
  /// open; finalize closes every segment so a persisted trip never has a
  /// null `endTime` (D-05, D-07).
  final DateTime? endTime;
  const TripBreakRow({
    required this.id,
    required this.tripId,
    required this.startTime,
    this.endTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    return map;
  }

  TripBreaksCompanion toCompanion(bool nullToAbsent) {
    return TripBreaksCompanion(
      id: Value(id),
      tripId: Value(tripId),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
    );
  }

  factory TripBreakRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripBreakRow(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
    };
  }

  TripBreakRow copyWith({
    String? id,
    String? tripId,
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
  }) => TripBreakRow(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
  );
  TripBreakRow copyWithCompanion(TripBreaksCompanion data) {
    return TripBreakRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripBreakRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, startTime, endTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripBreakRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime);
}

class TripBreaksCompanion extends UpdateCompanion<TripBreakRow> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<int> rowid;
  const TripBreaksCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripBreaksCompanion.insert({
    required String id,
    required String tripId,
    required DateTime startTime,
    this.endTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       startTime = Value(startTime);
  static Insertable<TripBreakRow> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripBreaksCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<int>? rowid,
  }) {
    return TripBreaksCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripBreaksCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $UserPreferencesTable userPreferences = $UserPreferencesTable(
    this,
  );
  late final $TripBreaksTable tripBreaks = $TripBreaksTable(this);
  late final Index idxTripsStartTime = Index(
    'idx_trips_start_time',
    'CREATE INDEX idx_trips_start_time ON trips (start_time)',
  );
  late final Index idxTripsDirectionStart = Index(
    'idx_trips_direction_start',
    'CREATE INDEX idx_trips_direction_start ON trips (direction, start_time)',
  );
  late final TripsDao tripsDao = TripsDao(this as AppDatabase);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final UserPreferencesDao userPreferencesDao = UserPreferencesDao(
    this as AppDatabase,
  );
  late final TripBreaksDao tripBreaksDao = TripBreaksDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trips,
    syncQueue,
    userPreferences,
    tripBreaks,
    idxTripsStartTime,
    idxTripsDirectionStart,
  ];
}

typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      required String id,
      Value<String> userId,
      required DateTime startTime,
      required DateTime endTime,
      required int durationSeconds,
      Value<int> totalPausedSeconds,
      required double distanceMeters,
      Value<String?> routePolyline,
      required String direction,
      Value<String> directionSource,
      required int timeMovingSeconds,
      required int timeStuckSeconds,
      Value<bool> isManualEntry,
      Value<bool> isEdited,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<DateTime> startTime,
      Value<DateTime> endTime,
      Value<int> durationSeconds,
      Value<int> totalPausedSeconds,
      Value<double> distanceMeters,
      Value<String?> routePolyline,
      Value<String> direction,
      Value<String> directionSource,
      Value<int> timeMovingSeconds,
      Value<int> timeStuckSeconds,
      Value<bool> isManualEntry,
      Value<bool> isEdited,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, TripRow> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripBreaksTable, List<TripBreakRow>>
  _tripBreaksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripBreaks,
    aliasName: $_aliasNameGenerator(db.trips.id, db.tripBreaks.tripId),
  );

  $$TripBreaksTableProcessedTableManager get tripBreaksRefs {
    final manager = $$TripBreaksTableTableManager(
      $_db,
      $_db.tripBreaks,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripBreaksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPausedSeconds => $composableBuilder(
    column: $table.totalPausedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routePolyline => $composableBuilder(
    column: $table.routePolyline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directionSource => $composableBuilder(
    column: $table.directionSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeMovingSeconds => $composableBuilder(
    column: $table.timeMovingSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeStuckSeconds => $composableBuilder(
    column: $table.timeStuckSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManualEntry => $composableBuilder(
    column: $table.isManualEntry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripBreaksRefs(
    Expression<bool> Function($$TripBreaksTableFilterComposer f) f,
  ) {
    final $$TripBreaksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripBreaks,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripBreaksTableFilterComposer(
            $db: $db,
            $table: $db.tripBreaks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPausedSeconds => $composableBuilder(
    column: $table.totalPausedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routePolyline => $composableBuilder(
    column: $table.routePolyline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directionSource => $composableBuilder(
    column: $table.directionSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeMovingSeconds => $composableBuilder(
    column: $table.timeMovingSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeStuckSeconds => $composableBuilder(
    column: $table.timeStuckSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManualEntry => $composableBuilder(
    column: $table.isManualEntry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPausedSeconds => $composableBuilder(
    column: $table.totalPausedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get routePolyline => $composableBuilder(
    column: $table.routePolyline,
    builder: (column) => column,
  );

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get directionSource => $composableBuilder(
    column: $table.directionSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeMovingSeconds => $composableBuilder(
    column: $table.timeMovingSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeStuckSeconds => $composableBuilder(
    column: $table.timeStuckSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isManualEntry => $composableBuilder(
    column: $table.isManualEntry,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tripBreaksRefs<T extends Object>(
    Expression<T> Function($$TripBreaksTableAnnotationComposer a) f,
  ) {
    final $$TripBreaksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripBreaks,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripBreaksTableAnnotationComposer(
            $db: $db,
            $table: $db.tripBreaks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          TripRow,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (TripRow, $$TripsTableReferences),
          TripRow,
          PrefetchHooks Function({bool tripBreaksRefs})
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime> endTime = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> totalPausedSeconds = const Value.absent(),
                Value<double> distanceMeters = const Value.absent(),
                Value<String?> routePolyline = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> directionSource = const Value.absent(),
                Value<int> timeMovingSeconds = const Value.absent(),
                Value<int> timeStuckSeconds = const Value.absent(),
                Value<bool> isManualEntry = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                userId: userId,
                startTime: startTime,
                endTime: endTime,
                durationSeconds: durationSeconds,
                totalPausedSeconds: totalPausedSeconds,
                distanceMeters: distanceMeters,
                routePolyline: routePolyline,
                direction: direction,
                directionSource: directionSource,
                timeMovingSeconds: timeMovingSeconds,
                timeStuckSeconds: timeStuckSeconds,
                isManualEntry: isManualEntry,
                isEdited: isEdited,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> userId = const Value.absent(),
                required DateTime startTime,
                required DateTime endTime,
                required int durationSeconds,
                Value<int> totalPausedSeconds = const Value.absent(),
                required double distanceMeters,
                Value<String?> routePolyline = const Value.absent(),
                required String direction,
                Value<String> directionSource = const Value.absent(),
                required int timeMovingSeconds,
                required int timeStuckSeconds,
                Value<bool> isManualEntry = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                userId: userId,
                startTime: startTime,
                endTime: endTime,
                durationSeconds: durationSeconds,
                totalPausedSeconds: totalPausedSeconds,
                distanceMeters: distanceMeters,
                routePolyline: routePolyline,
                direction: direction,
                directionSource: directionSource,
                timeMovingSeconds: timeMovingSeconds,
                timeStuckSeconds: timeStuckSeconds,
                isManualEntry: isManualEntry,
                isEdited: isEdited,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tripBreaksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tripBreaksRefs) db.tripBreaks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripBreaksRefs)
                    await $_getPrefetchedData<
                      TripRow,
                      $TripsTable,
                      TripBreakRow
                    >(
                      currentTable: table,
                      referencedTable: $$TripsTableReferences
                          ._tripBreaksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TripsTableReferences(db, table, p0).tripBreaksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tripId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      TripRow,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (TripRow, $$TripsTableReferences),
      TripRow,
      PrefetchHooks Function({bool tripBreaksRefs})
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String tripId,
      required String action,
      Value<String?> payload,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> tripId,
      Value<String> action,
      Value<String?> payload,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueRow,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueRow,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
          ),
          SyncQueueRow,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                tripId: tripId,
                action: action,
                payload: payload,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tripId,
                required String action,
                Value<String?> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                tripId: tripId,
                action: action,
                payload: payload,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueRow,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueRow,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
      ),
      SyncQueueRow,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableCreateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<int> id,
      Value<String> userId,
      Value<String> darkMode,
      Value<int> morningCutoffHour,
      Value<int> eveningCutoffHour,
      Value<bool> reminderEnabled,
      Value<String?> reminderTime,
      Value<bool> weekendReminder,
      Value<bool> weeklyNotificationEnabled,
      Value<bool> autoPauseEnabled,
      Value<bool> hasSeenOnboarding,
      Value<double?> homeLat,
      Value<double?> homeLng,
      Value<double?> officeLat,
      Value<double?> officeLng,
      Value<int> backfillMarkerVersion,
      Value<String> seenTours,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<int> id,
      Value<String> userId,
      Value<String> darkMode,
      Value<int> morningCutoffHour,
      Value<int> eveningCutoffHour,
      Value<bool> reminderEnabled,
      Value<String?> reminderTime,
      Value<bool> weekendReminder,
      Value<bool> weeklyNotificationEnabled,
      Value<bool> autoPauseEnabled,
      Value<bool> hasSeenOnboarding,
      Value<double?> homeLat,
      Value<double?> homeLng,
      Value<double?> officeLat,
      Value<double?> officeLng,
      Value<int> backfillMarkerVersion,
      Value<String> seenTours,
    });

class $$UserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get darkMode => $composableBuilder(
    column: $table.darkMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get morningCutoffHour => $composableBuilder(
    column: $table.morningCutoffHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eveningCutoffHour => $composableBuilder(
    column: $table.eveningCutoffHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get weekendReminder => $composableBuilder(
    column: $table.weekendReminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get weeklyNotificationEnabled => $composableBuilder(
    column: $table.weeklyNotificationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoPauseEnabled => $composableBuilder(
    column: $table.autoPauseEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSeenOnboarding => $composableBuilder(
    column: $table.hasSeenOnboarding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get homeLat => $composableBuilder(
    column: $table.homeLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get homeLng => $composableBuilder(
    column: $table.homeLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get officeLat => $composableBuilder(
    column: $table.officeLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get officeLng => $composableBuilder(
    column: $table.officeLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backfillMarkerVersion => $composableBuilder(
    column: $table.backfillMarkerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seenTours => $composableBuilder(
    column: $table.seenTours,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get darkMode => $composableBuilder(
    column: $table.darkMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get morningCutoffHour => $composableBuilder(
    column: $table.morningCutoffHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eveningCutoffHour => $composableBuilder(
    column: $table.eveningCutoffHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get weekendReminder => $composableBuilder(
    column: $table.weekendReminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get weeklyNotificationEnabled => $composableBuilder(
    column: $table.weeklyNotificationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoPauseEnabled => $composableBuilder(
    column: $table.autoPauseEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSeenOnboarding => $composableBuilder(
    column: $table.hasSeenOnboarding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get homeLat => $composableBuilder(
    column: $table.homeLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get homeLng => $composableBuilder(
    column: $table.homeLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get officeLat => $composableBuilder(
    column: $table.officeLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get officeLng => $composableBuilder(
    column: $table.officeLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backfillMarkerVersion => $composableBuilder(
    column: $table.backfillMarkerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seenTours => $composableBuilder(
    column: $table.seenTours,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get darkMode =>
      $composableBuilder(column: $table.darkMode, builder: (column) => column);

  GeneratedColumn<int> get morningCutoffHour => $composableBuilder(
    column: $table.morningCutoffHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eveningCutoffHour => $composableBuilder(
    column: $table.eveningCutoffHour,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get weekendReminder => $composableBuilder(
    column: $table.weekendReminder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get weeklyNotificationEnabled => $composableBuilder(
    column: $table.weeklyNotificationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoPauseEnabled => $composableBuilder(
    column: $table.autoPauseEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasSeenOnboarding => $composableBuilder(
    column: $table.hasSeenOnboarding,
    builder: (column) => column,
  );

  GeneratedColumn<double> get homeLat =>
      $composableBuilder(column: $table.homeLat, builder: (column) => column);

  GeneratedColumn<double> get homeLng =>
      $composableBuilder(column: $table.homeLng, builder: (column) => column);

  GeneratedColumn<double> get officeLat =>
      $composableBuilder(column: $table.officeLat, builder: (column) => column);

  GeneratedColumn<double> get officeLng =>
      $composableBuilder(column: $table.officeLng, builder: (column) => column);

  GeneratedColumn<int> get backfillMarkerVersion => $composableBuilder(
    column: $table.backfillMarkerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seenTours =>
      $composableBuilder(column: $table.seenTours, builder: (column) => column);
}

class $$UserPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTable,
          UserPreferencesRow,
          $$UserPreferencesTableFilterComposer,
          $$UserPreferencesTableOrderingComposer,
          $$UserPreferencesTableAnnotationComposer,
          $$UserPreferencesTableCreateCompanionBuilder,
          $$UserPreferencesTableUpdateCompanionBuilder,
          (
            UserPreferencesRow,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTable,
              UserPreferencesRow
            >,
          ),
          UserPreferencesRow,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> darkMode = const Value.absent(),
                Value<int> morningCutoffHour = const Value.absent(),
                Value<int> eveningCutoffHour = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
                Value<bool> weekendReminder = const Value.absent(),
                Value<bool> weeklyNotificationEnabled = const Value.absent(),
                Value<bool> autoPauseEnabled = const Value.absent(),
                Value<bool> hasSeenOnboarding = const Value.absent(),
                Value<double?> homeLat = const Value.absent(),
                Value<double?> homeLng = const Value.absent(),
                Value<double?> officeLat = const Value.absent(),
                Value<double?> officeLng = const Value.absent(),
                Value<int> backfillMarkerVersion = const Value.absent(),
                Value<String> seenTours = const Value.absent(),
              }) => UserPreferencesCompanion(
                id: id,
                userId: userId,
                darkMode: darkMode,
                morningCutoffHour: morningCutoffHour,
                eveningCutoffHour: eveningCutoffHour,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
                weekendReminder: weekendReminder,
                weeklyNotificationEnabled: weeklyNotificationEnabled,
                autoPauseEnabled: autoPauseEnabled,
                hasSeenOnboarding: hasSeenOnboarding,
                homeLat: homeLat,
                homeLng: homeLng,
                officeLat: officeLat,
                officeLng: officeLng,
                backfillMarkerVersion: backfillMarkerVersion,
                seenTours: seenTours,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> darkMode = const Value.absent(),
                Value<int> morningCutoffHour = const Value.absent(),
                Value<int> eveningCutoffHour = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
                Value<bool> weekendReminder = const Value.absent(),
                Value<bool> weeklyNotificationEnabled = const Value.absent(),
                Value<bool> autoPauseEnabled = const Value.absent(),
                Value<bool> hasSeenOnboarding = const Value.absent(),
                Value<double?> homeLat = const Value.absent(),
                Value<double?> homeLng = const Value.absent(),
                Value<double?> officeLat = const Value.absent(),
                Value<double?> officeLng = const Value.absent(),
                Value<int> backfillMarkerVersion = const Value.absent(),
                Value<String> seenTours = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                id: id,
                userId: userId,
                darkMode: darkMode,
                morningCutoffHour: morningCutoffHour,
                eveningCutoffHour: eveningCutoffHour,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
                weekendReminder: weekendReminder,
                weeklyNotificationEnabled: weeklyNotificationEnabled,
                autoPauseEnabled: autoPauseEnabled,
                hasSeenOnboarding: hasSeenOnboarding,
                homeLat: homeLat,
                homeLng: homeLng,
                officeLat: officeLat,
                officeLng: officeLng,
                backfillMarkerVersion: backfillMarkerVersion,
                seenTours: seenTours,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTable,
      UserPreferencesRow,
      $$UserPreferencesTableFilterComposer,
      $$UserPreferencesTableOrderingComposer,
      $$UserPreferencesTableAnnotationComposer,
      $$UserPreferencesTableCreateCompanionBuilder,
      $$UserPreferencesTableUpdateCompanionBuilder,
      (
        UserPreferencesRow,
        BaseReferences<
          _$AppDatabase,
          $UserPreferencesTable,
          UserPreferencesRow
        >,
      ),
      UserPreferencesRow,
      PrefetchHooks Function()
    >;
typedef $$TripBreaksTableCreateCompanionBuilder =
    TripBreaksCompanion Function({
      required String id,
      required String tripId,
      required DateTime startTime,
      Value<DateTime?> endTime,
      Value<int> rowid,
    });
typedef $$TripBreaksTableUpdateCompanionBuilder =
    TripBreaksCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<int> rowid,
    });

final class $$TripBreaksTableReferences
    extends BaseReferences<_$AppDatabase, $TripBreaksTable, TripBreakRow> {
  $$TripBreaksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) => db.trips.createAlias(
    $_aliasNameGenerator(db.tripBreaks.tripId, db.trips.id),
  );

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripBreaksTableFilterComposer
    extends Composer<_$AppDatabase, $TripBreaksTable> {
  $$TripBreaksTableFilterComposer({
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

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripBreaksTableOrderingComposer
    extends Composer<_$AppDatabase, $TripBreaksTable> {
  $$TripBreaksTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripBreaksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripBreaksTable> {
  $$TripBreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripBreaksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripBreaksTable,
          TripBreakRow,
          $$TripBreaksTableFilterComposer,
          $$TripBreaksTableOrderingComposer,
          $$TripBreaksTableAnnotationComposer,
          $$TripBreaksTableCreateCompanionBuilder,
          $$TripBreaksTableUpdateCompanionBuilder,
          (TripBreakRow, $$TripBreaksTableReferences),
          TripBreakRow,
          PrefetchHooks Function({bool tripId})
        > {
  $$TripBreaksTableTableManager(_$AppDatabase db, $TripBreaksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripBreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripBreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripBreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripBreaksCompanion(
                id: id,
                tripId: tripId,
                startTime: startTime,
                endTime: endTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripBreaksCompanion.insert(
                id: id,
                tripId: tripId,
                startTime: startTime,
                endTime: endTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripBreaksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
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
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripBreaksTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripBreaksTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$TripBreaksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripBreaksTable,
      TripBreakRow,
      $$TripBreaksTableFilterComposer,
      $$TripBreaksTableOrderingComposer,
      $$TripBreaksTableAnnotationComposer,
      $$TripBreaksTableCreateCompanionBuilder,
      $$TripBreaksTableUpdateCompanionBuilder,
      (TripBreakRow, $$TripBreaksTableReferences),
      TripBreakRow,
      PrefetchHooks Function({bool tripId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$TripBreaksTableTableManager get tripBreaks =>
      $$TripBreaksTableTableManager(_db, _db.tripBreaks);
}
