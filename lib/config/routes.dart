import 'package:flutter/widgets.dart';
import 'package:traevy/features/tracking/screens/tracking_screen.dart';

/// Home route — the minimal Phase 2 home screen with the Start commute
/// CTA. Bound via `MaterialApp.home` directly because it is always the
/// first route, so it does not need an entry in [kAppRoutes].
const String kRouteHome = '/';

/// Live tracking screen route (D-12).
const String kRouteTracking = '/tracking';

/// App-level named routes.
///
/// The map is declared `final` instead of `const` because Dart 3.11
/// rejects `const` maps whose values are tear-off [WidgetBuilder]
/// closures — this is a language constraint, not a lint violation.
final Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteTracking: (BuildContext context) => const TrackingScreen(),
};
