// Widget tests for the dashboard HomeHeader identity wiring and the avatar
// account entry point (Phase 32, D-01 / D-02, SC#1-3, SC#5, SC#7).
//
// Pattern mirrors guest_connection_indicator_test.dart: _FakeAuthNotifier +
// firebaseReadyProvider override=false so no Firebase platform channel is
// touched, MaterialApp(theme: buildLightTheme()) so TraevyTokensExt exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/dashboard/widgets/home_header.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/sync/sync_status.dart';

/// Minimal fake [AuthStateNotifier] returning a fixed [AuthState] without
/// subscribing to any Firebase stream.
class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

/// A notifier whose state can be flipped mid-test, to prove the header follows
/// auth transitions without a manual refresh (SC#5).
class _MutableAuthNotifier extends AuthStateNotifier {
  _MutableAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  /// Push [next] as the new auth state mid-test. Not a setter: the obvious
  /// name for one (`state`) is already Notifier's own.
  // ignore: use_setters_to_change_properties
  void emit(AuthState next) => state = next;
}

/// Fixed-state [SyncStatusNotifier] so the account sheet's cloud-sync row can
/// render without any engine, network, or on-disk Drift.
class _FakeSyncStatusNotifier extends SyncStatusNotifier {
  @override
  SyncStatus build() => const SyncIdle();
}

/// Pump a bare [HomeHeader] whose auth state comes from [notifier].
///
/// `firebaseReady=false` keeps every Firebase platform channel out of the test
/// host; the sync overrides keep the account sheet the avatar opens off the
/// real engine and off on-disk Drift.
Future<void> _pumpWithNotifier(
  WidgetTester tester,
  AuthStateNotifier Function() notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(false),
        authStateProvider.overrideWith(notifier),
        syncStatusProvider.overrideWith(_FakeSyncStatusNotifier.new),
        pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: HomeHeader()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required AuthState authState,
}) => _pumpWithNotifier(tester, () => _FakeAuthNotifier(authState));

void main() {
  group('HomeHeader identity (SC#1, SC#2)', () {
    testWidgets('signed-in user is greeted by first name with their initial', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        authState: const AuthSignedIn(
          uid: 'u1',
          name: 'Ada Lovelace',
          email: 'ada@x.dev',
        ),
      );

      expect(find.text('${kGreetingPrefix}Ada'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      // The surname never reaches the header.
      expect(find.textContaining('Lovelace'), findsNothing);
    });

    testWidgets('guest falls back to the guest name and initial', (
      tester,
    ) async {
      await _pumpHeader(tester, authState: const AuthGuest());

      expect(
        find.text('$kGreetingPrefix$kPlaceholderUserName'),
        findsOneWidget,
      );
      expect(find.text(kPlaceholderUserInitial), findsOneWidget);
    });

    testWidgets('loading falls back rather than rendering a blank header', (
      tester,
    ) async {
      await _pumpHeader(tester, authState: const AuthLoading());

      expect(
        find.text('$kGreetingPrefix$kPlaceholderUserName'),
        findsOneWidget,
      );
      expect(find.text(kPlaceholderUserInitial), findsOneWidget);
    });

    testWidgets('a whitespace-only display name never blanks the avatar', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        authState: const AuthSignedIn(
          uid: 'u1',
          name: '   ',
          email: 'ada@x.dev',
        ),
      );

      expect(
        find.text('$kGreetingPrefix$kPlaceholderUserName'),
        findsOneWidget,
      );
      expect(find.text(kPlaceholderUserInitial), findsOneWidget);
    });

    testWidgets('signing in while mounted updates greeting and avatar (SC#5)', (
      tester,
    ) async {
      final notifier = _MutableAuthNotifier(const AuthGuest());
      await _pumpWithNotifier(tester, () => notifier);
      expect(
        find.text('$kGreetingPrefix$kPlaceholderUserName'),
        findsOneWidget,
      );

      notifier.emit(
        const AuthSignedIn(uid: 'u1', name: 'Ada Lovelace', email: 'a@x.dev'),
      );
      await tester.pump();

      expect(find.text('${kGreetingPrefix}Ada'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      // …and back out again.
      notifier.emit(const AuthGuest());
      await tester.pump();
      expect(
        find.text('$kGreetingPrefix$kPlaceholderUserName'),
        findsOneWidget,
      );
    });
  });

  group('HomeHeader avatar as account entry point (SC#3, SC#7)', () {
    testWidgets('the touch target is at least 48x48 while the circle is 36', (
      tester,
    ) async {
      await _pumpHeader(tester, authState: const AuthGuest());

      final avatar = find.byTooltip(kAccountAvatarLabel);
      final tapTarget = tester.getSize(
        find.descendant(of: avatar, matching: find.byType(InkWell)).first,
      );
      expect(tapTarget.width, greaterThanOrEqualTo(48));
      expect(tapTarget.height, greaterThanOrEqualTo(48));

      // The painted circle is unchanged from its Phase 8 size.
      final circle = tester.getSize(
        find.descendant(of: avatar, matching: find.byType(Container)).first,
      );
      expect(circle.width, kAccountAvatarPaintedSize);
      expect(circle.height, kAccountAvatarPaintedSize);
    });

    testWidgets('the avatar is labelled for screen readers', (tester) async {
      await _pumpHeader(tester, authState: const AuthGuest());
      // A bare letter announces as a meaningless character without this.
      expect(find.byTooltip(kAccountAvatarLabel), findsOneWidget);
    });

    testWidgets('tapping the avatar opens the account sheet (guest)', (
      tester,
    ) async {
      await _pumpHeader(tester, authState: const AuthGuest());

      await tester.tap(find.byTooltip(kAccountAvatarLabel));
      await tester.pumpAndSettle();

      expect(find.text(kCopySettingsGuestSignIn), findsOneWidget);
    });

    testWidgets('tapping the avatar opens the account sheet (signed in)', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        authState: const AuthSignedIn(
          uid: 'u1',
          name: 'Ada Lovelace',
          email: 'ada@x.dev',
        ),
      );

      await tester.tap(find.byTooltip(kAccountAvatarLabel));
      await tester.pumpAndSettle();

      expect(find.byType(AccountRow), findsOneWidget);
      expect(find.text('ada@x.dev'), findsOneWidget);
      expect(find.text(kCopySettingsSignOut), findsOneWidget);
    });
  });
}
