import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/widgets/trip_card.dart';

// Layout constants — multiples of 4 per UI-SPEC, with the date-header
// 40dp exception (UI-SPEC second exception).
const double _kHorizontalPadding = 16;
const double _kEmptyIconSize = 64;
const double _kEmptyHeadingGap = 24;
const double _kEmptyBodyGap = 8;
const double _kDateHeaderHeight = 40;

/// Trip history screen (HIST-01, HIST-02).
///
/// Two view modes toggled by an AppBar icon:
///   - List view: [CustomScrollView] with sticky [SliverPersistentHeader]
///     date headers and [SliverList] of [TripCard] per group.
///   - Calendar view: [TableCalendar] on top, divider, then a filtered
///     [ListView] of [TripCard] for the selected day.
///
/// Data comes from [allTripSummariesProvider] — a [StreamProvider] that
/// watches the Drift `trips` table. Both views share the same
/// `_groupedTrips` map computed once per `data` branch, satisfying
/// Pitfall 5 (single Map lookup keeps the calendar `eventLoader` O(1))
/// and threat T-04-03-03.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Create the history screen.
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _ViewMode { list, calendar }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _ViewMode _viewMode = _ViewMode.list;
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == _ViewMode.list
          ? _ViewMode.calendar
          : _ViewMode.list;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );
      _focusedDay = focusedDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncTrips = ref.watch(allTripSummariesProvider);
    final isCalendar = _viewMode == _ViewMode.calendar;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              isCalendar ? Icons.list_rounded : Icons.calendar_month_outlined,
            ),
            tooltip: isCalendar ? 'Switch to list' : 'Switch to calendar',
            onPressed: _toggleViewMode,
          ),
        ],
      ),
      body: asyncTrips.when(
        data: (trips) {
          final grouped = groupTripsByDate(trips);
          if (isCalendar) {
            return _CalendarBody(
              groupedTrips: grouped,
              selectedDay: _selectedDay,
              focusedDay: _focusedDay,
              onDaySelected: _onDaySelected,
            );
          }
          if (trips.isEmpty) return const _EmptyState();
          return _ListBody(groupedTrips: grouped);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error loading trips: $error')),
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({required this.groupedTrips});

  final Map<DateTime, List<TripSummary>> groupedTrips;

  @override
  Widget build(BuildContext context) {
    final dates = groupedTrips.keys.toList(growable: false);
    final slivers = <Widget>[];
    for (final date in dates) {
      slivers
        ..add(
          SliverPersistentHeader(
            pinned: true,
            delegate: _DateHeaderDelegate(label: formatDateHeader(date)),
          ),
        )
        ..add(
          SliverList.list(
            children: <Widget>[
              for (final trip in groupedTrips[date]!) TripCard(summary: trip),
            ],
          ),
        );
    }
    return CustomScrollView(slivers: slivers);
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.groupedTrips,
    required this.selectedDay,
    required this.focusedDay,
    required this.onDaySelected,
  });

  final Map<DateTime, List<TripSummary>> groupedTrips;
  final DateTime? selectedDay;
  final DateTime focusedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  List<TripSummary> _eventLoader(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return groupedTrips[key] ?? const <TripSummary>[];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lastDay = DateTime.now();
    final selected = selectedDay;
    return Column(
      children: <Widget>[
        TableCalendar<TripSummary>(
          firstDay: DateTime.utc(2020),
          lastDay: lastDay,
          focusedDay: focusedDay.isAfter(lastDay) ? lastDay : focusedDay,
          selectedDayPredicate: (day) => isSameDay(selected, day),
          eventLoader: _eventLoader,
          onDaySelected: onDaySelected,
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 1,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _CalendarSubList(
            selectedDay: selected,
            trips: selected == null
                ? const <TripSummary>[]
                : _eventLoader(selected),
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }
}

class _CalendarSubList extends StatelessWidget {
  const _CalendarSubList({
    required this.selectedDay,
    required this.trips,
    required this.textTheme,
  });

  final DateTime? selectedDay;
  final List<TripSummary> trips;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(_kHorizontalPadding),
          child: Text(
            kHistoryCalendarNoSelection,
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(_kHorizontalPadding),
          child: Text(
            kHistoryCalendarEmptyDate,
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      children: <Widget>[
        for (final trip in trips) TripCard(summary: trip),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_kHorizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.route_outlined,
              size: _kEmptyIconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: _kEmptyHeadingGap),
            Text(kHistoryEmptyHeading, style: textTheme.titleMedium),
            const SizedBox(height: _kEmptyBodyGap),
            Text(
              kHistoryEmptyBody,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => _kDateHeaderHeight;

  @override
  double get maxExtent => _kDateHeaderHeight;

  @override
  bool shouldRebuild(_DateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: _kDateHeaderHeight,
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
      alignment: Alignment.centerLeft,
      child: Text(label, style: textTheme.titleMedium),
    );
  }
}
