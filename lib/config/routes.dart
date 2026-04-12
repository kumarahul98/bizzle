import 'package:flutter/widgets.dart';

/// App-level named routes.
///
/// Phase 1 ships with no named routes — the placeholder home screen is
/// mounted directly via `MaterialApp.home`. Phases 4+ populate this map
/// as real feature screens come online, so the symbol is declared once
/// here and imported by `lib/app.dart` without needing later renames.
const Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{};
