---
phase: 38-account-data-deletion
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/config/constants.dart
  - lib/sync/api_client.dart
  - lib/database/daos/trips_dao.dart
  - lib/database/daos/sync_queue_dao.dart
  - lib/sync/delete_trips_controller.dart
  - lib/features/settings/widgets/delete_all_data_row.dart
  - lib/features/settings/screens/settings_screen.dart
  - lib/features/auth/services/auth_service.dart
  - lib/features/auth/providers/auth_providers.dart
  - lib/features/auth/providers/delete_account_controller.dart
  - lib/features/dashboard/widgets/account_sheet.dart
  - test/unit/database/trips_dao_delete_all_test.dart
  - test/unit/database/sync_queue_dao_test.dart
  - test/unit/sync/api_client_test.dart
  - test/unit/sync/delete_trips_controller_test.dart
  - test/unit/features/auth/auth_service_test.dart
  - test/unit/features/auth/delete_account_controller_test.dart
autonomous: true
requirements: [DEL-ALL-DATA, DEL-ACCOUNT]
user_setup: []

must_haves:
  truths:
    - "A guest can tap 'Delete all data' in Settings → Data and have every local trip wiped, with the account/session untouched (no server call)."
    - "A signed-in user tapping 'Delete all data' purges server trips first, then wipes local trips + sync queue, and stays signed in."
    - "A signed-in user tapping 'Delete account' in the account sheet deletes the server account, then wipes local trips + sync queue, then signs out — the sheet re-renders/pops to the guest state."
    - "Every destructive action shows a confirm dialog (error-styled) before doing anything; dismissing the dialog is a no-op."
    - "No error state ever surfaces error.toString() — only fixed copy constants (PII guard)."
    - "dart format, flutter analyze (zero issues), and flutter test test/unit/ all pass."
  artifacts:
    - path: "lib/sync/delete_trips_controller.dart"
      provides: "DeleteTripsController + sealed DeleteTripsState + keepAlive provider"
      contains: "class DeleteTripsController extends Notifier"
    - path: "lib/features/settings/widgets/delete_all_data_row.dart"
      provides: "Settings 'Delete all data' row with confirm + snackbar feedback"
    - path: "lib/features/auth/providers/delete_account_controller.dart"
      provides: "DeleteAccountController + sealed DeleteAccountState + keepAlive provider"
      contains: "class DeleteAccountController extends Notifier"
    - path: "lib/features/auth/services/auth_service.dart"
      provides: "AuthService.deleteAccount() ordered server-first wipe"
      contains: "Future<void> deleteAccount"
  key_links:
    - from: "lib/sync/delete_trips_controller.dart"
      to: "lib/sync/api_client.dart"
      via: "ref.read(apiClientProvider).deleteAllTrips() (signed-in path only)"
      pattern: "deleteAllTrips"
    - from: "lib/features/auth/services/auth_service.dart"
      to: "lib/sync/api_client.dart"
      via: "_apiClient.deleteAccount() before any local wipe"
      pattern: "deleteAccount"
    - from: "lib/features/dashboard/widgets/account_sheet.dart"
      to: "lib/features/auth/providers/delete_account_controller.dart"
      via: "ref.read(deleteAccountControllerProvider.notifier).deleteAccount()"
      pattern: "deleteAccountControllerProvider"
    - from: "lib/features/settings/screens/settings_screen.dart"
      to: "lib/features/settings/widgets/delete_all_data_row.dart"
      via: "DeleteAllDataRow wired into _DataSection below the Trash row"
      pattern: "DeleteAllDataRow"
---

<objective>
Implement the Flutter frontend half of Phase 38 ("Account & Data Deletion") for
Commute Tracker: two new user-facing destructive actions Google Play requires of
any signed-in app.

1. **Delete all data** — a new Settings → Data row (guest AND signed-in). Hard-
   wipes all local trips; keeps the account/session. Signed-in users purge server
   trip copies first (`DELETE /trips`); guests have nothing on the server.
2. **Delete account** — a new account-sheet row (signed-in only). Deletes the
   server account (`DELETE /account`: auth user + trip data + prefs doc), then
   wipes local trips + sync queue, then signs the device out.

Purpose: unblock the Play compliance requirement for in-app account/data deletion.
Output: two new REST methods, two DAO wipes, two sealed-state controllers, two UI
rows wired into existing surfaces, and full unit-test coverage — all in `lib/` and
`test/` only. The two backend endpoints are being built in parallel against a
fixed, already-known contract; do NOT touch `backend/functions/`.
</objective>

<execution_context>
@/Users/coolman/bizzle/.claude/get-shit-done/workflows/execute-plan.md
@/Users/coolman/bizzle/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@lib/sync/api_client.dart
@lib/sync/restore_controller.dart
@lib/features/settings/widgets/restore_row.dart
@lib/features/dashboard/widgets/account_sheet.dart
@lib/features/auth/services/auth_service.dart
@lib/features/auth/providers/auth_providers.dart
@lib/database/daos/trips_dao.dart
@lib/database/daos/sync_queue_dao.dart
@lib/features/settings/screens/settings_screen.dart

<constraints>
CLAUDE.md "Frontend / Flutter Rules" are binding and re-checked at the end:
- Riverpod ONLY. No setState / ChangeNotifier / StateNotifier. Use manual
  `Notifier<T>` + `NotifierProvider` (this repo can't run riverpod_generator +
  drift_dev together — see the comment in lib/database/providers.dart / auth_providers.dart).
- Sealed classes for finite state (never raw strings).
- Widgets under ~100 lines; extract if larger.
- Drift is the only UI data source.
- NO hardcoded strings/values — every label, dialog copy, snackbar message, and
  path goes in lib/config/constants.dart.
- PII guard: error states carry NO error detail; UI shows a fixed copy constant,
  never `error.toString()` (mirror RestoreError).
- flutter_secure_storage token handling already exists — do not touch it.
- Do NOT touch user_preferences (device-local theme/reminder — not account data).
- Do NOT touch backend/functions/.
</constraints>

<interfaces>
<!-- Extracted from the codebase. Use these directly — no exploration needed. -->

Fixed backend contract (endpoints built in parallel, do not wait):
- `DELETE {kApiBaseUrl}/trips` → 200, body `{statusCode:200, body:{data:{deletedCount:N}}}`
- `DELETE {kApiBaseUrl}/account` → 200, body `{statusCode:200, body:{data:{deleted:true}}}`
- Both use `Authorization: Bearer <idToken>` and the SAME error/retry contract as
  every existing ApiClient method (401→force-refresh-retry-once, then
  SyncException.http/.transport/.notSignedIn).

From lib/sync/api_client.dart:
```dart
// _send runs the request with a fresh token, retries once on 401, returns the
// http.Response for 2xx (or allowStatus codes), else throws SyncException.http;
// wraps any network/decode error as SyncException.transport.
Future<http.Response> _send(
  Future<http.Response> Function(String token) send, {
  Set<int> allowStatus = const {},
});
Map<String, String> _headers(String token); // Bearer + Content-Type
// restoreTrips() is the double-wrap envelope-unwrap analog:
//   decoded['body']['data']['trips']  → transport() on any malformed step.
final Provider<ApiClient> apiClientProvider; // name: 'apiClientProvider'
class SyncException { factory .http(int); .transport(); .notSignedIn(); }
```

From lib/sync/restore_controller.dart (THE shape to mirror):
```dart
@immutable sealed class RestoreState { const RestoreState(); }
class RestoreIdle/RestoreRestoring/RestoreSuccess(int count)/RestoreError ...
class RestoreController extends Notifier<RestoreState> {
  @override RestoreState build() => const RestoreIdle();
  Future<void> restore() async {         // never rethrows
    state = const RestoreRestoring();
    try { ... state = RestoreSuccess(n); } on Object { state = const RestoreError(); }
  }
}
final NotifierProvider<RestoreController, RestoreState> restoreControllerProvider =
  NotifierProvider(RestoreController.new, name: 'restoreControllerProvider'); // keepAlive
```

From lib/features/settings/widgets/restore_row.dart (double-tap guard + snackbar):
```dart
final state = ref.watch(restoreControllerProvider);
final isRestoring = state is RestoreRestoring;
// onTap disabled while in-flight; after await, guard context.mounted, then
// ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
```

From lib/features/dashboard/widgets/account_sheet.dart (confirm-dialog pattern):
```dart
// _confirmSignOut: AlertDialog, TextButton(kDialogCancel) + FilledButton styled
// FilledButton.styleFrom(backgroundColor: colorScheme.error,
//   foregroundColor: colorScheme.onError). Returns bool? via Navigator.pop.
// _AccountSheetContent.build switches on ref.watch(authStateProvider);
// AuthSignedIn branch holds AccountRow, CloudSyncRow, RestoreRow, Sign out
// SettingsRow(dangerous:true). Guest branch pops with _AccountSheetAction.signIn.
```

From lib/features/auth/services/auth_service.dart:
```dart
AuthService({ required FlutterSecureStorage secureStorage, required TripsDao tripsDao,
  required UserPreferencesDao prefsDao, required SyncQueueDao syncQueueDao,
  FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn, AppDatabase? db });
// lazy getters: _firebaseAuth, _googleSignIn resolve at call time (test-safe).
Future<void> signIn();  // propagates errors
Future<void> signOut(); // firebaseAuth.signOut + googleSignIn.signOut + secureStorage.delete
// _tripsDao / _syncQueueDao are private final fields already present.
```

From lib/features/auth/providers/auth_providers.dart:
```dart
final Provider<AuthService> authServiceProvider = Provider((ref) => AuthService(
  firebaseAuth: ref.watch(firebaseAuthProvider), googleSignIn: ref.watch(googleSignInProvider),
  secureStorage: ref.watch(secureStorageProvider), tripsDao: ref.watch(tripsDaoProvider),
  prefsDao: ref.watch(userPreferencesDaoProvider), syncQueueDao: ref.watch(syncQueueDaoProvider),
  db: ref.watch(appDatabaseProvider)), name: 'authServiceProvider');
final NotifierProvider<AuthStateNotifier, AuthState> authStateProvider; // name: 'authStateProvider'
```

From lib/features/auth/models/auth_state.dart:
```dart
sealed class AuthState; final class AuthLoading; final class AuthGuest;
final class AuthSignedIn { final String uid, name, email; }
```

From lib/database — DAO base + providers:
```dart
// TripsDao.deleteTrip(id) => (delete(trips)..where(...)).go();
//   trip_breaks + trip_stuck_segments FKs are onDelete: KeyAction.cascade under
//   PRAGMA foreign_keys = ON, so a bare delete(trips).go() cascades — confirmed.
// SyncQueueDao table getter is `syncQueue`.
final Provider<TripsDao> tripsDaoProvider;          // name: 'tripsDaoProvider'
final Provider<SyncQueueDao> syncQueueDaoProvider;  // name: 'syncQueueDaoProvider'
final Provider<AppDatabase> appDatabaseProvider;    // name: 'appDatabaseProvider'
```

From lib/features/settings/widgets/settings_row.dart:
```dart
SettingsRow({ required String label, String? subtitle, Widget? trailing,
  VoidCallback? onTap, bool dangerous = false });
```

Existing constants (lib/config/constants.dart — add NEW ones alongside these):
```dart
const kApiBaseUrl = ...;          const kSyncTripsPath = '/trips/sync';
const kRestoreTripsPath = '/trips/restore'; const kDeleteTripPathPrefix = '/trips/';
const kDialogCancel = 'Cancel';   const kSignOutDialogTitle = 'Sign out?';
const kSignOutDialogBody = ...;   const kSignOutConfirm = 'Sign out';
const kCopySettingsSignOut = 'Sign out'; const kSettingsDataSectionTitle = 'Data';
const kTrashSettingsRowLabel = 'Deleted trips';
const kSettingsRestoreInProgress = 'Restoring…'; const kSettingsRestoreError = "Couldn't restore. Try again.";
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Constants + DAO wipes (foundation)</name>
  <files>lib/config/constants.dart, lib/database/daos/trips_dao.dart, lib/database/daos/sync_queue_dao.dart, test/unit/database/trips_dao_delete_all_test.dart, test/unit/database/sync_queue_dao_test.dart</files>
  <behavior>
    - TripsDao.deleteAllTrips() removes every trip row and returns the deleted-row count.
    - Deleting all trips cascades to trip_breaks + trip_stuck_segments (FK onDelete cascade under PRAGMA foreign_keys=ON) — assert both child tables are empty afterward.
    - SyncQueueDao.clearAll() removes every sync_queue row and returns the deleted-row count.
    - On an empty table both return 0.
  </behavior>
  <action>
    In lib/config/constants.dart, near kSyncTripsPath/kRestoreTripsPath/kDeleteTripPathPrefix add:
      `const String kDeleteAllTripsPath = '/trips';`
      `const String kDeleteAccountPath = '/account';`
    Also (near kSignOutDialog* / kSettingsRestore*) add copy constants — follow the exact
    kSignOutDialogTitle/kSignOutDialogBody/kSignOutConfirm naming shape (DEL-ALL-DATA, DEL-ACCOUNT):
      - Delete-all-data row label, confirm dialog title/body/confirm-button, in-progress subtitle,
        success snackbar template (+ singular/plural or a simple "All data deleted" fixed message),
        and a fixed error snackbar (mirror kSettingsRestoreError tone). Body MUST make clear the
        ACCOUNT ITSELF IS KEPT — only local + server trip data is wiped.
      - Delete-account row label, confirm dialog title/body/confirm-button, in-progress copy,
        and a fixed error snackbar. Body MUST be unambiguous it is IRREVERSIBLE and removes the
        account and everything in it.
      Reuse the existing kDialogCancel for both cancel buttons. No hardcoded strings anywhere else.
    In lib/database/daos/trips_dao.dart add (matching the deleteTrip return-style discipline in this file):
      `Future<int> deleteAllTrips() => delete(trips).go();`
      with a doc comment noting the FK cascade removes trip_breaks + trip_stuck_segments, and that
      this is a hard wipe used by the Phase 38 delete flows (enqueues nothing — the server was told
      directly). No `where` clause.
    In lib/database/daos/sync_queue_dao.dart add:
      `Future<int> clearAll() => delete(syncQueue).go();`
      with a doc comment: a pending queue for trips that no longer exist is meaningless after either
      delete flow. (Table getter is `syncQueue`.)
    Run `dart run build_runner build --delete-conflicting-outputs` since DAOs changed (regenerates
    *.g.dart mixins).
    Write test/unit/database/trips_dao_delete_all_test.dart mirroring test/unit/database/trips_dao_test.dart
    setUp/tearDown (in-memory NativeDatabase, close in tearDown). Insert 2+ trips, insert child
    trip_breaks/trip_stuck_segments rows for at least one, call deleteAllTrips(), assert getAllTrips()
    is empty AND both child tables are empty AND the return count matches inserted trip count; assert
    an empty-table call returns 0.
    Add SyncQueueDao.clearAll() coverage to test/unit/database/sync_queue_dao_test.dart (append a group,
    matching its existing conventions): enqueue a few rows, clearAll(), assert getPending() empty and
    the return count matches; empty-table call returns 0.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle && dart run build_runner build --delete-conflicting-outputs && flutter test test/unit/database/trips_dao_delete_all_test.dart test/unit/database/sync_queue_dao_test.dart</automated>
  </verify>
  <done>deleteAllTrips()/clearAll() exist and are green; cascade to both child tables asserted; new path + copy constants present; codegen regenerated.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: ApiClient.deleteAllTrips() + deleteAccount()</name>
  <files>lib/sync/api_client.dart, test/unit/sync/api_client_test.dart</files>
  <behavior>
    - deleteAllTrips() DELETEs {kDeleteAllTripsPath} with the Bearer header, unwraps
      decoded['body']['data']['deletedCount'] (same double-wrap as restoreTrips), returns the int.
    - deleteAllTrips() on a malformed/short envelope throws SyncException.transport() (no PII leak).
    - deleteAllTrips() on non-2xx throws SyncException.http (via _send); 401→refresh→retry-once still applies.
    - deleteAccount() DELETEs {kDeleteAccountPath} with the Bearer header; returns void on 2xx;
      throws SyncException.http on non-2xx. Body not parsed beyond _send's 2xx check.
  </behavior>
  <action>
    Add two methods on ApiClient mirroring the existing style EXACTLY:
      `Future<int> deleteAllTrips()` — `await _send((token) => _client.delete(
        Uri.parse('$_baseUrl$kDeleteAllTripsPath'), headers: _headers(token)))`, then decode the
        envelope inside a try that rethrows SyncException and maps any other throw to
        `const SyncException.transport()` — copy the restoreTrips() decode block structure:
        decoded is! Map → transport(); body=decoded['body'] as Map?; data=body?['data'] as Map?;
        count=data?['deletedCount'] as int?; if count==null → transport(); return count.
      `Future<void> deleteAccount()` — `await _send((token) => _client.delete(
        Uri.parse('$_baseUrl$kDeleteAccountPath'), headers: _headers(token)));` — no body parse.
    Add doc comments in the house style (reference the fixed contract shapes).
    In test/unit/sync/api_client_test.dart add groups using the existing MockClient + fixedToken/build
    helpers already in that file:
      - deleteAllTrips happy path: MockClient returns
        `{"statusCode":200,"body":{"data":{"deletedCount":3}}}` 200 → returns 3; assert method DELETE,
        url == '$testBaseUrl$kDeleteAllTripsPath', Authorization Bearer header present.
      - deleteAllTrips malformed envelope (e.g. `{"body":{"data":{}}}` or truncated) → throws
        SyncException with retryable==true (transport).
      - deleteAllTrips non-2xx (e.g. 500) → throws SyncException.http.
      - deleteAllTrips 401-then-200 refreshes token and retries once (mirror the existing syncTrips 401 test).
      - deleteAccount happy path 200 → completes; assert DELETE + url + Bearer.
      - deleteAccount non-2xx (e.g. 500) → throws SyncException.http.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle && flutter test test/unit/sync/api_client_test.dart</automated>
  </verify>
  <done>Both methods exist, mirror _send/_headers/envelope-unwrap style, and all new + existing api_client tests pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: DeleteTripsController + Settings "Delete all data" row + wiring</name>
  <files>lib/sync/delete_trips_controller.dart, lib/features/settings/widgets/delete_all_data_row.dart, lib/features/settings/screens/settings_screen.dart, test/unit/sync/delete_trips_controller_test.dart</files>
  <behavior>
    - Guest path: deleteAllTrips() does NOT call apiClient; wipes local trips + clears sync queue; ends DeleteTripsSuccess(count).
    - Signed-in path: calls apiClient.deleteAllTrips() FIRST, then wipes local + clears queue; ends DeleteTripsSuccess.
    - API error (SyncException) on signed-in path: state = DeleteTripsError, returns WITHOUT wiping local, never rethrows.
    - Double-tap while DeleteTripsInProgress is a no-op.
  </behavior>
  <action>
    Create lib/sync/delete_trips_controller.dart mirroring restore_controller.dart's shape:
      `@immutable sealed class DeleteTripsState` with `DeleteTripsIdle`, `DeleteTripsInProgress`,
      `DeleteTripsSuccess(int count)` (count = local rows wiped), `DeleteTripsError` (NO error detail — PII guard).
      `class DeleteTripsController extends Notifier<DeleteTripsState>` with
      `@override DeleteTripsState build() => const DeleteTripsIdle();` and
      `Future<void> deleteAllTrips() async`:
        - guard: `if (state is DeleteTripsInProgress) return;`
        - `state = const DeleteTripsInProgress();`
        - if `ref.read(authStateProvider) is AuthSignedIn`: wrap `await ref.read(apiClientProvider).deleteAllTrips()`
          in `try { ... } on SyncException { state = const DeleteTripsError(); return; }` (never rethrow).
        - then always: `final count = await ref.read(tripsDaoProvider).deleteAllTrips();`
          `await ref.read(syncQueueDaoProvider).clearAll();`
        - `state = DeleteTripsSuccess(count);`
      keepAlive provider (bare NotifierProvider, NOT autoDispose):
      `final NotifierProvider<DeleteTripsController, DeleteTripsState> deleteTripsControllerProvider =
        NotifierProvider(DeleteTripsController.new, name: 'deleteTripsControllerProvider');`
      Import authStateProvider (auth_providers.dart), AuthSignedIn (auth_state.dart), apiClientProvider,
      tripsDaoProvider/syncQueueDaoProvider (database/providers.dart).
    Create lib/features/settings/widgets/delete_all_data_row.dart (ConsumerWidget, mirror restore_row.dart,
    keep under ~100 lines):
      - `final state = ref.watch(deleteTripsControllerProvider); final inProgress = state is DeleteTripsInProgress;`
      - render `SettingsRow(label: <delete-all-data label const>, dangerous: true,
        subtitle: inProgress ? <in-progress copy const> : null, onTap: inProgress ? null : () => _onTap(...))`
      - `_onTap`: show the confirm AlertDialog styled EXACTLY like _confirmSignOut (TextButton kDialogCancel +
        FilledButton with FilledButton.styleFrom(backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError), delete-all-data copy). On confirm==true:
        `await ref.read(deleteTripsControllerProvider.notifier).deleteAllTrips();`
        then guard `context.mounted`, map post-state to a snackbar message const (success template with the
        wiped count / fixed error copy), and `ScaffoldMessenger.maybeOf(context)?.showSnackBar(...)` — the
        SAME feedback mechanism RestoreRow uses. Dialog dismissal (`confirmed ?? false`) is a no-op.
    Wire into lib/features/settings/screens/settings_screen.dart _DataSection: add `const DeleteAllDataRow()`
    BELOW the existing Trash SettingsRow in the SettingsSection children. Add the import.
    Write test/unit/sync/delete_trips_controller_test.dart with a ProviderContainer + in-memory Drift
    (mirror restore_controller_test.dart's fake-ApiClient + provider-override setUp): override authStateProvider,
    apiClientProvider (a fake/scripted ApiClient), and the DAO providers. Cover:
      - guest path: fake ApiClient's deleteAllTrips is NEVER called; local trips wiped; ends DeleteTripsSuccess.
      - signed-in path: fake ApiClient's deleteAllTrips IS called once; local wiped; ends DeleteTripsSuccess.
      - signed-in API-error path: fake throws SyncException.transport → state DeleteTripsError, local trips
        still present (not wiped), no rethrow.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle && flutter test test/unit/sync/delete_trips_controller_test.dart</automated>
  </verify>
  <done>Controller + row exist, guest/signed-in/error paths correct and never rethrow, row wired below Trash, tests green, widget under ~100 lines.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: AuthService.deleteAccount() + provider wiring + DeleteAccountController</name>
  <files>lib/features/auth/services/auth_service.dart, lib/features/auth/providers/auth_providers.dart, lib/features/auth/providers/delete_account_controller.dart, test/unit/features/auth/auth_service_test.dart, test/unit/features/auth/delete_account_controller_test.dart</files>
  <behavior>
    - AuthService.deleteAccount() calls, IN ORDER: _apiClient.deleteAccount(), then _tripsDao.deleteAllTrips(),
      then _syncQueueDao.clearAll(), then signOut(). It does NOT touch user_preferences.
    - If _apiClient.deleteAccount() throws, deleteAccount() PROPAGATES and performs NO local wipe / no signOut.
    - DeleteAccountController.deleteAccount() calls authService.deleteAccount() inside try/catch on SyncException;
      Idle→InProgress→Success, or →Error (no detail) on SyncException; never rethrows.
  </behavior>
  <action>
    In lib/features/auth/services/auth_service.dart:
      - add an optional constructor param `ApiClient? apiClient` (same override pattern as
        _firebaseAuthOverride/_googleSignInOverride), store as `_apiClientOverride`, and add a lazy getter
        `ApiClient get _apiClient => _apiClientOverride ?? ...` — BUT there is no ApiClient.instance singleton,
        so make the getter throw a StateError if null (test code that never calls deleteAccount never touches it,
        matching the lazy-getter discipline; the provider always injects a real one). Import lib/sync/api_client.dart.
      - add:
        ```dart
        Future<void> deleteAccount() async {
          await _apiClient.deleteAccount();      // server first — MUST succeed before any local wipe
          await _tripsDao.deleteAllTrips();
          await _syncQueueDao.clearAll();
          await signOut();
        }
        ```
        Doc: server deletion must succeed before local wipe; propagates on API failure (like signIn), unlike
        the controller layer; does NOT touch user_preferences (device-local, matching signOut).
    In lib/features/auth/providers/auth_providers.dart: add `apiClient: ref.watch(apiClientProvider)` to the
      existing authServiceProvider construction; import lib/sync/api_client.dart.
    Create lib/features/auth/providers/delete_account_controller.dart mirroring the controller shape:
      `@immutable sealed class DeleteAccountState` → `DeleteAccountIdle`, `DeleteAccountInProgress`,
      `DeleteAccountSuccess`, `DeleteAccountError` (NO detail).
      `class DeleteAccountController extends Notifier<DeleteAccountState>` with build()=>Idle and
      `Future<void> deleteAccount() async`:
        - guard `if (state is DeleteAccountInProgress) return;`
        - `state = const DeleteAccountInProgress();`
        - `try { await ref.read(authServiceProvider).deleteAccount(); state = const DeleteAccountSuccess(); }
           on SyncException { state = const DeleteAccountError(); }` (never rethrow — same discipline as
           RestoreController / DeleteTripsController).
      keepAlive `final NotifierProvider<DeleteAccountController, DeleteAccountState> deleteAccountControllerProvider =
        NotifierProvider(DeleteAccountController.new, name: 'deleteAccountControllerProvider');`
      Import authServiceProvider (auth_providers.dart) and SyncException (api_client.dart).
    Tests:
      - Add to test/unit/features/auth/auth_service_test.dart (hand-rolled fakes + noSuchMethod style already there):
        add a fake ApiClient that records call order and can throw; fake TripsDao/SyncQueueDao that record
        deleteAllTrips()/clearAll(); a fake FirebaseAuth/GoogleSignIn/secureStorage for signOut(). Cover:
          (a) deleteAccount() happy path calls apiClient.deleteAccount → tripsDao.deleteAllTrips →
              syncQueueDao.clearAll → signOut IN THAT ORDER, and never touches prefsDao.
          (b) deleteAccount() when apiClient.deleteAccount throws SyncException → the throw PROPAGATES and
              tripsDao.deleteAllTrips / clearAll / signOut are NEVER called (local data intact).
      - Create test/unit/features/auth/delete_account_controller_test.dart (mirror delete_trips_controller_test
        style with a fake AuthService via authServiceProvider override): success path → DeleteAccountSuccess;
        SyncException path → DeleteAccountError, no rethrow; in-progress double-call guard is a no-op.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle && flutter test test/unit/features/auth/auth_service_test.dart test/unit/features/auth/delete_account_controller_test.dart</automated>
  </verify>
  <done>AuthService.deleteAccount() ordered server-first + propagates-on-API-failure verified; provider injects apiClient; controller never rethrows; prefs untouched; tests green.</done>
</task>

<task type="auto">
  <name>Task 5: Account sheet "Delete account" row + feedback</name>
  <files>lib/features/dashboard/widgets/account_sheet.dart</files>
  <action>
    In lib/features/dashboard/widgets/account_sheet.dart, _AccountSheetContent's `AuthSignedIn` branch, add a
    new `SettingsRow` AFTER the existing Sign out row (keep Sign out itself unchanged):
      - `SettingsRow(label: <delete-account label const>, dangerous: true, onTap: () => unawaited(_confirmDeleteAccount(context, ref)))`.
    Add a `_confirmDeleteAccount(BuildContext, WidgetRef)` helper mirroring `_confirmSignOut` EXACTLY (same
    AlertDialog structure, TextButton kDialogCancel + FilledButton.styleFrom(backgroundColor: colorScheme.error,
    foregroundColor: colorScheme.onError)) but with the delete-account copy constants (irreversible, removes
    everything). On confirm==true:
      - `await ref.read(deleteAccountControllerProvider.notifier).deleteAccount();`
      - guard `context.mounted`; then read `ref.read(deleteAccountControllerProvider)`:
        - on DeleteAccountError → show a SnackBar with the fixed error copy const (SAME
          ScaffoldMessenger.maybeOf(context)?.showSnackBar mechanism used by DeleteAllDataRow — keep consistent).
        - on DeleteAccountSuccess → pop the sheet (`Navigator.of(context).pop()`), mirroring how the guest
          `_AccountSheetAction.signIn` path pops. No manual auth navigation needed: signOut() inside
          AuthService.deleteAccount() already flips authStateProvider → AuthGuest, and the existing
          _AccountSheetContent switch re-renders the guest row.
    To show a loading indicator while InProgress: since _AccountSheetContent already
    `ref.watch(authStateProvider)`, also `ref.watch(deleteAccountControllerProvider)` at the top of build()
    and, in the AuthSignedIn branch, render the delete-account row's trailing as a small
    CircularProgressIndicator (or disable onTap) when the state is DeleteAccountInProgress. Add the imports
    (delete_account_controller.dart). Keep helpers small — extract if the file's widgets approach ~100 lines.
    Do NOT add hardcoded strings — all copy from constants added in Task 1.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle && flutter analyze lib/features/dashboard/widgets/account_sheet.dart</automated>
  </verify>
  <done>Delete-account row present in the signed-in branch after Sign out (Sign out unchanged), confirm dialog error-styled, InProgress shows a loader, Success pops the sheet, Error shows a snackbar, no hardcoded strings.</done>
</task>

<task type="auto">
  <name>Task 6: Full verification sweep</name>
  <files>(no new files — whole-repo gates)</files>
  <action>
    Run the full verification sequence from the task spec and fix anything that fails:
      1. `dart run build_runner build --delete-conflicting-outputs`
      2. `dart format .`
      3. `flutter analyze` → must report ZERO issues
      4. `flutter test test/unit/` → all new + existing unit tests green
    Then re-read CLAUDE.md's "Frontend / Flutter Rules" section once more and confirm every rule holds:
    Riverpod-only (no setState/ChangeNotifier/StateNotifier — this plan uses manual Notifier+NotifierProvider),
    sealed states, widgets < ~100 lines, Drift-only UI reads, no hardcoded strings/values, PII guard (no
    error.toString() in any state), user_preferences untouched, backend/functions/ untouched.
    If any gate fails, fix in the owning file and re-run — do NOT report done until all four gates pass.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle && dart run build_runner build --delete-conflicting-outputs && dart format --set-exit-if-changed . && flutter analyze && flutter test test/unit/</automated>
  </verify>
  <done>build_runner + dart format clean, flutter analyze zero issues, all unit tests green, CLAUDE.md Frontend rules re-confirmed.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Flutter client → Cloud Functions (DELETE /trips, /account) | Untrusted client asserts identity via Firebase ID token; server authorizes deletion from the verified uid only. |
| Controller/UI ← error objects | SyncException / arbitrary throwables may carry status/URL detail; must not reach the UI as text. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-38-01 | Information Disclosure | DeleteTripsError / DeleteAccountError states + snackbars | mitigate | Error states carry NO error detail; UI shows fixed copy constants only — mirror RestoreError PII guard. Verified by controller tests + the "no error.toString()" rule re-check in Task 6. |
| T-38-02 | Tampering / Data loss | AuthService.deleteAccount() ordering | mitigate | Server delete MUST succeed before any local wipe; on API throw, propagate and perform NO local wipe (test 4b). Prevents wiping local data while the server account survives. |
| T-38-03 | Denial of Service (accidental self-inflicted) | destructive taps | mitigate | Error-styled confirm AlertDialog before every destructive action; dialog dismissal is a no-op; in-progress double-tap guarded in both controllers. |
| T-38-04 | Elevation / Auth bypass | DELETE /trips, /account | accept (server-owned) | Auth is enforced server-side via the same Bearer-token verification as every endpoint; the client reuses the existing _send/_headers path — no new auth surface introduced client-side. Backend deletion authorization is out of this plan's scope (parallel backend agent). |
| T-38-05 | Repudiation | local hard delete cascade | accept | v0.1 single-user offline-first app; hard delete of local trips + cascade to child tables is the intended irreversible action, confirmed via dialog. No audit-trail requirement. |
</threat_model>

<verification>
- `dart run build_runner build --delete-conflicting-outputs` succeeds (DAOs changed).
- `dart format --set-exit-if-changed .` clean.
- `flutter analyze` reports zero issues.
- `flutter test test/unit/` fully green (new: trips_dao_delete_all, sync_queue clearAll, api_client
  delete methods, delete_trips_controller, auth_service.deleteAccount, delete_account_controller).
- Guest "Delete all data" wipes local without any server call; signed-in purges server first.
- "Delete account" deletes server → wipes local → signs out; sheet pops and re-renders guest.
- No error.toString() in any state; user_preferences and backend/functions/ untouched.
</verification>

<success_criteria>
- All 11 build steps from the spec are implemented across Tasks 1–5 and pass Task 6's gates.
- Two new REST methods, two DAO wipes, two sealed-state manual-Notifier controllers, two UI rows
  wired into Settings → Data and the account sheet.
- Every CLAUDE.md Frontend / Flutter Rule holds; four verification gates pass.
</success_criteria>

<output>
After completion, create `.planning/quick/260726-lax-implement-flutter-frontend-for-phase-38-/260726-lax-SUMMARY.md`.
</output>
