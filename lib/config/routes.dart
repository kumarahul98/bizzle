import 'package:flutter/widgets.dart';
import 'package:traevy/features/onboarding/screens/onboarding_screen.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:traevy/features/trips/screens/trip_detail_screen.dart';

/// Home route — the minimal Phase 2 home screen with the Start commute
/// CTA. Bound via `MaterialApp.home` directly because it is always the
/// first route, so it does not need an entry in [kAppRoutes].
const String kRouteHome = '/';

/// Trip history screen route (D-02).
const String kRouteHistory = '/history';

/// Trip detail screen route (HIST-03). Argument: tripId (String).
const String kRouteTripDetail = '/trip-detail';

/// Stats screen route (Phase 5, D-02). Argument: none.
const String kRouteStats = '/stats';

/// Settings screen route (Phase 7, D-01).
const String kRouteSettings = '/settings';

/// Onboarding screen route (D-08; screen registered in Plan 07).
///
/// Reserved here so the route name is available app-wide before
/// the OnboardingScreen builder is wired in Plan 07.
const String kRouteOnboarding = '/onboarding';

/// One-time sign-in confirmation screen route (D-12, Phase 9 Plan 04).
///
/// Shown immediately after a first successful sign-in when
/// `AuthService.signIn()` returns `true` (i.e. local trips were backfilled
/// from `kDefaultUserId` to the Firebase UID). Displays "You're signed in."
/// and the "Let's go" CTA that resolves to the main shell.
///
/// This name is **reserved here** so all navigation callers can reference it
/// as a constant before the screen is built in Plan 04. The screen is pushed
/// via `Navigator.of(context).pushNamed(kRouteSignInSuccess)` from the
/// onboarding handler and the sign-in sheet; it is NOT added to `kAppRoutes`
/// because Plan 04 will push it as a `MaterialPageRoute` (not a named-route
/// builder) to avoid exposing it in the global route table.
///
/// See D-12 in `.planning/phases/09-authentication/09-RESEARCH.md`.
const String kRouteSignInSuccess = '/sign-in-success';

/// App-level named routes.
///
/// The map is declared `final` instead of `const` because Dart 3.11
/// rejects `const` maps whose values are tear-off [WidgetBuilder]
/// closures — this is a language constraint, not a lint violation.
final Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteHistory: (BuildContext context) => const HistoryScreen(),
  kRouteStats: (BuildContext context) => const StatsScreen(),
  kRouteSettings: (BuildContext context) => const SettingsScreen(),
  kRouteOnboarding: (BuildContext context) => const OnboardingScreen(),
  kRouteTripDetail: (BuildContext context) {
    final tripId = ModalRoute.of(context)!.settings.arguments! as String;
    return TripDetailScreen(tripId: tripId);
  },
};
