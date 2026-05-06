import 'package:flutter/widgets.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:traevy/features/trips/screens/trip_detail_screen.dart';

/// Home route — the minimal Phase 2 home screen with the Start commute
/// CTA. Bound via `MaterialApp.home` directly because it is always the
/// first route, so it does not need an entry in [kAppRoutes].
const String kRouteHome = '/';

/// Live tracking screen route (D-12).
const String kRouteTracking = '/tracking';

/// Trip history screen route (D-02).
const String kRouteHistory = '/history';

/// Trip detail screen route (HIST-03). Argument: tripId (String).
const String kRouteTripDetail = '/trip-detail';

/// Stats screen route (Phase 5, D-02). Argument: none.
const String kRouteStats = '/stats';

/// Settings screen route (Phase 7, D-01).
const String kRouteSettings = '/settings';

/// App-level named routes.
///
/// The map is declared `final` instead of `const` because Dart 3.11
/// rejects `const` maps whose values are tear-off [WidgetBuilder]
/// closures — this is a language constraint, not a lint violation.
final Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteTracking: (BuildContext context) => const TrackingScreen(),
  kRouteHistory: (BuildContext context) => const HistoryScreen(),
  kRouteStats: (BuildContext context) => const StatsScreen(),
  kRouteSettings: (BuildContext context) => const SettingsScreen(),
  kRouteTripDetail: (BuildContext context) {
    final tripId = ModalRoute.of(context)!.settings.arguments! as String;
    return TripDetailScreen(tripId: tripId);
  },
};
