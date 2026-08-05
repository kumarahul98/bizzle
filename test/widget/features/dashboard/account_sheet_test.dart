// Widget tests for the account sheet opened from the dashboard avatar
// (Phase 32, D-02, SC#3).
//
// The Cloud sync / Restore / Sign out coverage here is the coverage that used
// to live in settings_screen_test.dart's _AccountSection groups — the section
// moved into this sheet, so its tests moved with it. Settings keeps only a
// negative assertion that the controls are gone (SC#4).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/services/auth_service.dart';
import 'package:traevy/features/dashboard/widgets/account_sheet.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/sync_engine.dart';
import 'package:traevy/sync/sync_status.dart';
import 'package:traevy/sync/trip_serializer.dart';

// ---------------------------------------------------------------------------
// Fakes — same shapes settings_screen_test.dart used for these rows.
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.throwOnDeleteAccount = false});

  final bool throwOnDeleteAccount;
  int signOutCallCount = 0;
  int deleteAccountCallCount = 0;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (throwOnDeleteAccount) throw const SyncException.transport();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncStatusNotifier extends SyncStatusNotifier {
  _FakeSyncStatusNotifier(this._status);

  final SyncStatus _status;

  @override
  SyncStatus build() => _status;
}

class _FakeSyncEngine implements SyncEngine {
  int retryFailedCallCount = 0;

  @override
  Future<void> retryFailed() async {
    retryFailedCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this._companions, {this.throwOnRestore = false});

  final List<TripsCompanion> _companions;
  final bool throwOnRestore;

  @override
  Future<List<ParsedTrip>> restoreTrips() async {
    if (throwOnRestore) throw const SyncException.transport();
    return _companions
        .map(
          (c) => (
            trip: c,
            breaks: const <TripBreaksCompanion>[],
            stuckSegments: const <TripStuckSegmentsCompanion>[],
          ),
        )
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Pump a host screen whose single button opens the account sheet, then open
/// it. Mirrors the production entry point (a tap on the dashboard avatar).
Future<void> _openSheet(
  WidgetTester tester, {
  AuthState authState = const AuthGuest(),
  AuthService? authService,
  SyncStatus syncStatus = const SyncIdle(),
  int pendingCount = 0,
  _FakeSyncEngine? syncEngine,
  _FakeApiClient? apiClient,
  AppDatabase? restoreDb,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(false),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
        syncStatusProvider.overrideWith(
          () => _FakeSyncStatusNotifier(syncStatus),
        ),
        pendingSyncCountProvider.overrideWith(
          (ref) => Stream<int>.value(pendingCount),
        ),
        if (syncEngine != null)
          syncEngineProvider.overrideWithValue(syncEngine),
        if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
        if (restoreDb != null)
          tripsDaoProvider.overrideWithValue(restoreDb.tripsDao),
        if (restoreDb != null)
          syncQueueDaoProvider.overrideWithValue(restoreDb.syncQueueDao),
        if (authService != null)
          authServiceProvider.overrideWithValue(authService),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showAccountSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('account sheet — signed in (SC#3)', () {
    const signedIn = AuthSignedIn(
      uid: 'u',
      name: 'Ada Lovelace',
      email: 'ada@x.dev',
    );

    testWidgets('renders the same four rows the Account section held', (
      tester,
    ) async {
      await _openSheet(tester, authState: signedIn);

      expect(find.byType(AccountRow), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('ada@x.dev'), findsOneWidget);
      expect(find.text(kSettingsCloudSyncRowLabel), findsOneWidget);
      expect(find.text(kSettingsRestoreRowLabel), findsOneWidget);
      expect(find.text(kCopySettingsSignOut), findsOneWidget);
      // The guest CTA has no place in the signed-in sheet.
      expect(find.text(kCopySettingsGuestSignIn), findsNothing);
    });

    testWidgets(
      'Sign out confirms first, then invokes signOut() exactly once',
      (tester) async {
        final fakeAuth = _FakeAuthService();
        await _openSheet(
          tester,
          authState: signedIn,
          authService: fakeAuth,
        );

        // Tapping the row opens the confirmation dialog — it does NOT sign out.
        await tester.tap(find.text(kCopySettingsSignOut));
        await tester.pumpAndSettle();
        expect(find.text(kSignOutDialogTitle), findsOneWidget);
        expect(fakeAuth.signOutCallCount, equals(0));

        // Confirming (the dialog's FilledButton, distinct from the row of the
        // same label) signs out exactly once.
        await tester.tap(
          find.widgetWithText(FilledButton, kSignOutConfirm),
        );
        await tester.pumpAndSettle();
        expect(fakeAuth.signOutCallCount, equals(1));
      },
    );

    testWidgets('cancelling the sign-out dialog does not sign out', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthService();
      await _openSheet(
        tester,
        authState: signedIn,
        authService: fakeAuth,
      );

      await tester.tap(find.text(kCopySettingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, kDialogCancel));
      await tester.pumpAndSettle();

      expect(find.text(kSignOutDialogTitle), findsNothing);
      expect(fakeAuth.signOutCallCount, equals(0));
    });

    testWidgets('synced status renders the "All synced" subtitle', (
      tester,
    ) async {
      await _openSheet(
        tester,
        authState: signedIn,
        syncStatus: const SyncSynced(),
      );
      expect(find.text(kSettingsSyncStatusAllSynced), findsOneWidget);
    });

    testWidgets('tapping a failed Cloud sync row calls retryFailed() once', (
      tester,
    ) async {
      final engine = _FakeSyncEngine();
      await _openSheet(
        tester,
        authState: signedIn,
        syncStatus: const SyncFailed(1),
        syncEngine: engine,
      );

      expect(find.text(kSettingsSyncStatusFailed), findsOneWidget);
      await tester.tap(find.text(kSettingsCloudSyncRowLabel));
      await tester.pump();
      expect(engine.retryFailedCallCount, equals(1));
    });

    testWidgets('Restore drives the controller and reports its result', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await _openSheet(
        tester,
        authState: signedIn,
        apiClient: _FakeApiClient(<TripsCompanion>[_restoreCompanion('r1')]),
        restoreDb: db,
      );

      await tester.tap(find.text(kSettingsRestoreRowLabel));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '$kSettingsRestoreResultTemplate 1 $kRestoreTripNounSingular',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failing restore surfaces the error copy', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await _openSheet(
        tester,
        authState: signedIn,
        apiClient: _FakeApiClient(
          const <TripsCompanion>[],
          throwOnRestore: true,
        ),
        restoreDb: db,
      );

      await tester.tap(find.text(kSettingsRestoreRowLabel));
      await tester.pumpAndSettle();

      expect(find.text(kSettingsRestoreError), findsOneWidget);
    });

    testWidgets('exactly one Sign out and one Restore control exist', (
      tester,
    ) async {
      // The whole point of deleting the Settings copy (D-02): two Restore rows
      // could fire two restores, and two Sign outs read the same state.
      await _openSheet(tester, authState: signedIn);
      expect(find.text(kCopySettingsSignOut), findsOneWidget);
      expect(find.text(kSettingsRestoreRowLabel), findsOneWidget);
    });

    testWidgets(
      'Delete account confirms first, then deletes and pops the sheet '
      'on success',
      (tester) async {
        final fakeAuth = _FakeAuthService();
        await _openSheet(
          tester,
          authState: signedIn,
          authService: fakeAuth,
        );

        // Tapping the row opens the confirmation dialog — it does NOT delete.
        await tester.tap(find.text(kDeleteAccountRowLabel));
        await tester.pumpAndSettle();
        expect(find.text(kDeleteAccountDialogTitle), findsOneWidget);
        expect(fakeAuth.deleteAccountCallCount, equals(0));

        // Confirming (the dialog's FilledButton, distinct from the row of the
        // same label) deletes exactly once and pops the sheet.
        await tester.tap(
          find.widgetWithText(FilledButton, kDeleteAccountConfirm),
        );
        await tester.pumpAndSettle();
        expect(fakeAuth.deleteAccountCallCount, equals(1));
        expect(find.text(kDeleteAccountRowLabel), findsNothing);
      },
    );

    testWidgets('cancelling the delete-account dialog does not delete', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthService();
      await _openSheet(
        tester,
        authState: signedIn,
        authService: fakeAuth,
      );

      await tester.tap(find.text(kDeleteAccountRowLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, kDialogCancel));
      await tester.pumpAndSettle();

      expect(find.text(kDeleteAccountDialogTitle), findsNothing);
      expect(fakeAuth.deleteAccountCallCount, equals(0));
    });

    testWidgets('a failing delete-account surfaces the error snackbar', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthService(throwOnDeleteAccount: true);
      await _openSheet(
        tester,
        authState: signedIn,
        authService: fakeAuth,
      );

      await tester.tap(find.text(kDeleteAccountRowLabel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, kDeleteAccountConfirm),
      );
      await tester.pumpAndSettle();

      expect(find.text(kDeleteAccountErrorSnackbar), findsOneWidget);
      // The sheet stays open on failure — the row is still there.
      expect(find.text(kDeleteAccountRowLabel), findsOneWidget);
    });
  });

  group('account sheet — guest (SC#3)', () {
    testWidgets('renders only the sign-in CTA', (tester) async {
      await _openSheet(tester);

      expect(find.text(kCopySettingsGuestSignIn), findsOneWidget);
      expect(find.byType(AccountRow), findsNothing);
      expect(find.text(kCopySettingsSignOut), findsNothing);
      expect(find.text(kSettingsCloudSyncRowLabel), findsNothing);
      expect(find.text(kSettingsRestoreRowLabel), findsNothing);
      expect(find.byType(SettingsRow), findsOneWidget);
    });

    testWidgets('the CTA closes this sheet and opens the sign-in sheet', (
      tester,
    ) async {
      await _openSheet(tester);

      await tester.tap(find.text(kCopySettingsGuestSignIn));
      await tester.pumpAndSettle();

      // The account sheet is gone — the two sheets never stack.
      expect(find.text(kCopySettingsGuestSignIn), findsNothing);
      // …and the sign-in sheet is up in its place.
      expect(find.text(kCopySignInSheetHeadline), findsOneWidget);
    });

    testWidgets('loading state renders the guest CTA, not a blank sheet', (
      tester,
    ) async {
      await _openSheet(tester, authState: const AuthLoading());
      expect(find.text(kCopySettingsGuestSignIn), findsOneWidget);
    });
  });
}

/// Build a restored-trip [TripsCompanion] for [id] via the real serializer.
TripsCompanion _restoreCompanion(String id) =>
    TripSerializer.fromJson(<String, dynamic>{
      'id': id,
      'startTime': '2026-05-01T08:00:00.000Z',
      'endTime': '2026-05-01T08:30:00.000Z',
      'durationSeconds': 1800,
      'distanceMeters': 12000.0,
      'routePolyline': null,
      'direction': 'to_office',
      'timeMovingSeconds': 1200,
      'timeStuckSeconds': 600,
      'isManualEntry': false,
      'createdAt': '2026-05-01T08:30:00.000Z',
      'updatedAt': '2026-05-01T08:30:00.000Z',
    }).trip;
