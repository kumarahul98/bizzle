import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('EditTripSheet', () {
    late AppDatabase db;
    const uuid = Uuid();

    // A fixed UTC window; the sheet shows these in local time.
    final start = DateTime.utc(2026, 1, 1, 8);
    final end = DateTime.utc(2026, 1, 1, 9);

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async => db.close());

    // The time picker dialog needs a tall surface to lay out without overflow.
    Future<void> setSurface(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    Future<String> insertTrip({
      int moving = 3000,
      int stuck = 600,
      String direction = kDirectionToOffice,
    }) async {
      final id = uuid.v4();
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: end,
          durationSeconds: 3600,
          distanceMeters: 0,
          direction: direction,
          timeMovingSeconds: moving,
          timeStuckSeconds: stuck,
        ),
      );
      return id;
    }

    TripSummary makeSummary({
      required String id,
      int moving = 3000,
      int stuck = 600,
      String direction = kDirectionToOffice,
    }) {
      return TripSummary(
        id: id,
        startTime: start,
        endTime: end,
        durationSeconds: 3600,
        distanceMeters: 0,
        direction: direction,
        timeMovingSeconds: moving,
        timeStuckSeconds: stuck,
        isManualEntry: false,
      );
    }

    Widget buildSheet(
      TripSummary summary, {
      List<EditBreakSegment> initialBreaks = const <EditBreakSegment>[],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          tripBreaksDaoProvider.overrideWithValue(db.tripBreaksDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: EditTripSheet(
              summary: summary,
              initialBreaks: initialBreaks,
            ),
          ),
        ),
      );
    }

    testWidgets('shows Edit trip title and core fields', (tester) async {
      final id = await insertTrip();
      await tester.pumpWidget(buildSheet(makeSummary(id: id)));
      expect(find.text('Edit trip'), findsOneWidget);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text(kEditBreaksSectionLabel), findsOneWidget);
      expect(find.text(kEditAddBreakLabel), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('editing end via date+time pickers updates the label', (
      tester,
    ) async {
      await setSurface(tester);
      final id = await insertTrip();
      await tester.pumpWidget(buildSheet(makeSummary(id: id)));

      // The End button shows the original end time label.
      final endLocal = end.toLocal();
      final endButton = find.widgetWithText(
        OutlinedButton,
        _dateTimeLabel(endLocal),
      );
      expect(endButton, findsOneWidget);
      await tester.tap(endButton);
      await tester.pumpAndSettle();

      // showDatePicker opened on the end's month (January). Pick the NEXT day
      // (2 Jan, visible in the same grid) so end stays after start, then OK.
      final nextDay = DateTime(
        endLocal.year,
        endLocal.month,
        endLocal.day + 1,
        endLocal.hour,
        endLocal.minute,
      );
      await tester.tap(find.text('${nextDay.day}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // showTimePicker is open: accept the unchanged time with OK.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The End button now reflects the next day at the same local time.
      expect(
        find.widgetWithText(OutlinedButton, _dateTimeLabel(nextDay)),
        findsOneWidget,
      );
    });

    testWidgets('Save persists recomputed stats + breaks + one sync update', (
      tester,
    ) async {
      final id = await insertTrip();
      // Seed one break 10–20 min in. Active = 3600 - 600 = 3000s.
      final seed = <EditBreakSegment>[
        EditBreakSegment(
          start: start.add(const Duration(minutes: 10)),
          end: start.add(const Duration(minutes: 20)),
        ),
      ];
      await tester.pumpWidget(
        buildSheet(makeSummary(id: id), initialBreaks: seed),
      );
      await tester.pumpAndSettle();

      await tapSave(tester);

      final row = await db.tripsDao.findById(id);
      expect(row, isNotNull);
      // Active = window(3600) − break(600) = 3000.
      expect(row!.durationSeconds, 3000);
      expect(row.timeMovingSeconds + row.timeStuckSeconds, 3000);
      // Original ratio moving:stuck = 3000:600 → 5:1; active 3000 → 2500/500.
      expect(row.timeMovingSeconds, 2500);
      expect(row.timeStuckSeconds, 500);
      expect(row.isEdited, isTrue);

      final breaks = await db.tripBreaksDao.breaksForTrip(id);
      expect(breaks, hasLength(1));
      // Drift returns DateTime in local zone; compare by instant.
      expect(
        breaks.first.startTime.toUtc(),
        start.add(const Duration(minutes: 10)),
      );
      expect(
        breaks.first.endTime!.toUtc(),
        start.add(const Duration(minutes: 20)),
      );

      final pending = await db.syncQueueDao.getPending();
      expect(pending, hasLength(1));
    });

    testWidgets('adding then removing a break leaves the saved set empty', (
      tester,
    ) async {
      final id = await insertTrip();
      await tester.pumpWidget(buildSheet(makeSummary(id: id)));
      await tester.pumpAndSettle();

      // Add a break (default 5-min in-window segment) then remove it.
      await tester.tap(find.text(kEditAddBreakLabel));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tapSave(tester);

      final breaks = await db.tripBreaksDao.breaksForTrip(id);
      expect(breaks, isEmpty);
    });

    testWidgets(
      'an overlapping break disables Save and shows the specific message',
      (tester) async {
        final id = await insertTrip();
        // Two touching breaks: 10–20 and 20–30 — touch is rejected (D-07).
        final seed = <EditBreakSegment>[
          EditBreakSegment(
            start: start.add(const Duration(minutes: 10)),
            end: start.add(const Duration(minutes: 20)),
          ),
          EditBreakSegment(
            start: start.add(const Duration(minutes: 20)),
            end: start.add(const Duration(minutes: 30)),
          ),
        ];
        await tester.pumpWidget(
          buildSheet(makeSummary(id: id), initialBreaks: seed),
        );
        await tester.pumpAndSettle();

        expect(find.text(kEditValidationBreakOverlap), findsOneWidget);
        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(saveButton.onPressed, isNull);
      },
    );

    testWidgets('a break outside the window disables Save with the message', (
      tester,
    ) async {
      final id = await insertTrip();
      // Break extends past the trip end (window is 60 min): 50–70 min.
      final seed = <EditBreakSegment>[
        EditBreakSegment(
          start: start.add(const Duration(minutes: 50)),
          end: start.add(const Duration(minutes: 70)),
        ),
      ];
      await tester.pumpWidget(
        buildSheet(makeSummary(id: id), initialBreaks: seed),
      );
      await tester.pumpAndSettle();

      expect(find.text(kEditValidationBreakOutsideWindow), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);

      // Nothing was persisted.
      final row = await db.tripsDao.findById(id);
      expect(row!.isEdited, isFalse);
    });
  });
}

/// Mirror the sheet's start/end button label format.
String _dateTimeLabel(DateTime local) {
  final weekday = const <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][local.weekday - 1];
  final month = const <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][local.month - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$weekday, ${local.day} $month · $hh:$mm';
}
