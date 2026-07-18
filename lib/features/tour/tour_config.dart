import 'package:flutter/widgets.dart';
import 'package:traevy/config/constants.dart';

/// A single coach-mark step: the on-screen widget to spotlight ([targetKey])
/// plus the [title] / [description] copy shown in the tooltip beside it.
///
/// Steps are immutable value objects. The [targetKey] is one of the shared
/// [TourKeys] `GlobalKey`s, attached to the real widget inside its screen so
/// the overlay can measure the widget's on-screen rectangle at showcase time.
@immutable
class TourStep {
  /// Create a coach-mark step.
  const TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
  });

  /// The shared `GlobalKey` attached to the widget this step spotlights.
  final GlobalKey targetKey;

  /// Short heading shown at the top of the tooltip.
  final String title;

  /// One- or two-sentence body explaining the spotlighted element.
  final String description;
}

/// The full tour for one MainShell tab: which [pageKey] persists it as seen,
/// which [tabIndex] must be selected for it to run, and its ordered [steps].
@immutable
class PageTour {
  /// Create a page tour definition.
  const PageTour({
    required this.pageKey,
    required this.tabIndex,
    required this.steps,
  });

  /// `seen_tours` CSV token (e.g. [kTourKeyDashboard]) persisted once this
  /// page's tour finishes or is skipped.
  final String pageKey;

  /// The MainShell `IndexedStack` index this tour belongs to. The tour only
  /// starts when this index is the selected (visible) tab.
  final int tabIndex;

  /// Ordered coach-mark steps for this page.
  final List<TourStep> steps;
}

/// Shared `GlobalKey`s attaching each tour step to a real widget inside its
/// screen. Declared once here (not inside the screens) so the tour overlay,
/// mounted at the MainShell level, and the target widgets, mounted deep inside
/// each tab, reference the same identity without a provider round-trip.
///
/// Each key is attached in exactly one place in the widget tree at a time
/// (its tab's screen), so there is never a duplicate-`GlobalKey` collision.
abstract final class TourKeys {
  /// Dashboard: the START / record hero card.
  static final GlobalKey dashboardRecord = GlobalKey(
    debugLabel: 'tour_dashboard_record',
  );

  /// Dashboard: today's summary section.
  static final GlobalKey dashboardToday = GlobalKey(
    debugLabel: 'tour_dashboard_today',
  );

  /// History: the list / calendar view toggle.
  static final GlobalKey tripsView = GlobalKey(debugLabel: 'tour_trips_view');

  /// History: the add-trip-manually button.
  static final GlobalKey tripsAdd = GlobalKey(debugLabel: 'tour_trips_add');

  /// Stats: the traffic-loss hero.
  static final GlobalKey statsTraffic = GlobalKey(
    debugLabel: 'tour_stats_traffic',
  );

  /// Stats: the moving-vs-stuck breakdown chart.
  static final GlobalKey statsBreakdown = GlobalKey(
    debugLabel: 'tour_stats_breakdown',
  );

  /// Settings: the auto-pause toggle row.
  static final GlobalKey settingsAutoPause = GlobalKey(
    debugLabel: 'tour_settings_auto_pause',
  );

  /// Settings: the Home / Office locations section.
  static final GlobalKey settingsLocations = GlobalKey(
    debugLabel: 'tour_settings_locations',
  );
}

/// The four per-page tours, one per MainShell tab, in tab order. The MainShell
/// wraps each `IndexedStack` child in a `PageTourHost` built from the matching
/// entry here.
List<PageTour> buildPageTours() => <PageTour>[
  PageTour(
    pageKey: kTourKeyDashboard,
    tabIndex: 0,
    steps: <TourStep>[
      TourStep(
        targetKey: TourKeys.dashboardRecord,
        title: kTourDashboardRecordTitle,
        description: kTourDashboardRecordBody,
      ),
      TourStep(
        targetKey: TourKeys.dashboardToday,
        title: kTourDashboardTodayTitle,
        description: kTourDashboardTodayBody,
      ),
    ],
  ),
  PageTour(
    pageKey: kTourKeyTrips,
    tabIndex: 1,
    steps: <TourStep>[
      TourStep(
        targetKey: TourKeys.tripsView,
        title: kTourTripsViewTitle,
        description: kTourTripsViewBody,
      ),
      TourStep(
        targetKey: TourKeys.tripsAdd,
        title: kTourTripsAddTitle,
        description: kTourTripsAddBody,
      ),
    ],
  ),
  PageTour(
    pageKey: kTourKeyStats,
    tabIndex: 2,
    steps: <TourStep>[
      TourStep(
        targetKey: TourKeys.statsTraffic,
        title: kTourStatsTrafficTitle,
        description: kTourStatsTrafficBody,
      ),
      TourStep(
        targetKey: TourKeys.statsBreakdown,
        title: kTourStatsBreakdownTitle,
        description: kTourStatsBreakdownBody,
      ),
    ],
  ),
  PageTour(
    pageKey: kTourKeySettings,
    tabIndex: 3,
    steps: <TourStep>[
      TourStep(
        targetKey: TourKeys.settingsAutoPause,
        title: kTourSettingsAutoPauseTitle,
        description: kTourSettingsAutoPauseBody,
      ),
      TourStep(
        targetKey: TourKeys.settingsLocations,
        title: kTourSettingsLocationsTitle,
        description: kTourSettingsLocationsBody,
      ),
    ],
  ),
];

/// Every page key that has a tour — used by tests to script an
/// already-seen-everything preferences value that suppresses all tours.
List<String> get allTourPageKeys => <String>[
  kTourKeyDashboard,
  kTourKeyTrips,
  kTourKeyStats,
  kTourKeySettings,
];
