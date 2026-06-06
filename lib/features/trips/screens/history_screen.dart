import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/widgets/history_view_toggle.dart';
import 'package:traevy/features/trips/widgets/manual_entry_sheet.dart';
import 'package:traevy/features/trips/widgets/trip_section_card.dart';
import 'package:traevy/shared/utils/formatters.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';

// Layout constants — multiples of 4 per UI-SPEC.
const double _kHorizontalPadding = 20;
const double _kEmptyIconSize = 64;
const double _kEmptyHeadingGap = 24;
const double _kEmptyBodyGap = 8;

/// Trip history screen (HIST-01, HIST-02).
///
/// Two view modes toggled by a pill [HistoryViewToggle] and a calendar icon:
///   - List view: [ListView] of [TripSectionCard] per date group.
///   - Calendar view: [TableCalendar] with token-driven colours + filtered
///     trip list for the selected day.
///
/// No AppBar — the screen lives inside the MainShell navigation and renders
/// its own 'Trips' title row with icon buttons.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Create the history screen.
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryView _view = HistoryView.list;
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  void _onViewChanged(HistoryView view) {
    setState(() => _view = view);
  }

  void _toggleCalendar() {
    setState(() {
      _view = _view == HistoryView.calendar
          ? HistoryView.list
          : HistoryView.calendar;
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

  Future<void> _showManualEntry() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ManualEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncTrips = ref.watch(allTripSummariesProvider);
    final textTheme = Theme.of(context).textTheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Title row.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kHorizontalPadding,
                16,
                _kHorizontalPadding,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Text('Trips', style: textTheme.titleLarge),
                  const Spacer(),
                  // Calendar toggle icon button — 36dp surface circle.
                  _IconCircleButton(
                    onTap: _toggleCalendar,
                    // surfaceContainer maps to t.surface in buildLightTheme.
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    icon: Icons.calendar_today_rounded,
                    iconColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  // Add trip icon button — 36dp text-bg circle.
                  _IconCircleButton(
                    onTap: _showManualEntry,
                    backgroundColor: Theme.of(context).colorScheme.onSurface,
                    icon: Icons.add_rounded,
                    iconColor: bgColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // View toggle pill.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kHorizontalPadding,
              ),
              child: HistoryViewToggle(
                selectedView: _view,
                onChanged: _onViewChanged,
              ),
            ),
            const SizedBox(height: 16),
            // Body.
            Expanded(
              child: asyncTrips.when(
                data: (trips) {
                  final grouped = groupTripsByDate(trips);
                  if (_view == HistoryView.calendar) {
                    return _CalendarBody(
                      groupedTrips: grouped,
                      selectedDay: _selectedDay,
                      focusedDay: _focusedDay,
                      onDaySelected: _onDaySelected,
                      onTripTap: (trip) => Navigator.pushNamed(
                        context,
                        kRouteTripDetail,
                        arguments: trip.id,
                      ),
                    );
                  }
                  if (trips.isEmpty) return const _EmptyState();
                  return _ListBody(
                    groupedTrips: grouped,
                    onTripTap: (trip) => Navigator.pushNamed(
                      context,
                      kRouteTripDetail,
                      arguments: trip.id,
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text('Error loading trips: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 36dp circle icon button used in the title row.
class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.onTap,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.groupedTrips,
    required this.onTripTap,
  });

  final Map<DateTime, List<TripSummary>> groupedTrips;
  final ValueChanged<TripSummary> onTripTap;

  String _totalLabel(List<TripSummary> trips) {
    final totalSeconds = trips.fold<int>(
      0,
      (sum, t) => sum + t.durationSeconds,
    );
    return formatDuration(totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final dates = groupedTrips.keys.toList(growable: false);
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: dates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final date = dates[index];
        final trips = groupedTrips[date]!;
        final label = formatDateHeader(date);
        return TripSectionCard(
          dateLabel: label,
          totalLabel: _totalLabel(trips),
          trips: trips,
          onTripTap: onTripTap,
        );
      },
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.groupedTrips,
    required this.selectedDay,
    required this.focusedDay,
    required this.onDaySelected,
    required this.onTripTap,
  });

  final Map<DateTime, List<TripSummary>> groupedTrips;
  final DateTime? selectedDay;
  final DateTime focusedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(TripSummary trip) onTripTap;

  List<TripSummary> _eventLoader(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return groupedTrips[key] ?? const <TripSummary>[];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final lastDay = DateTime.now();
    final selected = selectedDay;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
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
            // Pitfall 10: calendar colours use tokens, not colorScheme.primary.
            markerDecoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              // tokens.text maps to colorScheme.onSurface in buildLightTheme.
              color: Theme.of(context).colorScheme.onSurface,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: tokens.accentBg,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TraevyFonts.ui(
              size: 14,
              weight: FontWeight.w600,
              color: tokens.accent,
            ),
            selectedTextStyle: TraevyFonts.ui(
              size: 14,
              weight: FontWeight.w600,
              color: bgColor,
            ),
            defaultTextStyle: textTheme.bodyMedium!,
            weekendTextStyle: textTheme.bodyMedium!,
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
            onTripTap: onTripTap,
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
    required this.onTripTap,
  });

  final DateTime? selectedDay;
  final List<TripSummary> trips;
  final TextTheme textTheme;
  final void Function(TripSummary trip) onTripTap;

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
        for (int i = 0; i < trips.length; i++)
          TripRowCard(
            direction: trips[i].direction,
            startTime: trips[i].startTime,
            endTime: trips[i].endTime,
            durationSeconds: trips[i].durationSeconds,
            distanceMeters: trips[i].distanceMeters,
            stuckSeconds: trips[i].timeStuckSeconds,
            isEdited: trips[i].isEdited,
            showDivider: i < trips.length - 1,
            onTap: () => onTripTap(trips[i]),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
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
              color: tokens.textMuted,
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
