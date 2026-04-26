import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/services/trip_actions.dart'
    as trip_actions;
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:traevy/shared/utils/formatters.dart';

// Spacing constants — multiples of 4 per UI-SPEC.
const double _kCardPadding = 16;
const double _kIconSize = 24;
const double _kIconGap = 12;

/// A trip summary card used in both the list view and the calendar
/// sub-list of the history screen (HIST-01, HIST-02).
///
/// Tapping the body navigates to [kRouteTripDetail]. Tapping the
/// trailing more-vert icon opens an options sheet with Edit and Delete
/// actions (Pitfall 6: actions live OUTSIDE the calendar widget so the
/// calendar's day-tap handler does not steal taps).
class TripCard extends ConsumerWidget {
  /// Create a trip card for [summary].
  const TripCard({required this.summary, super.key});

  /// The trip projection backing this card.
  final TripSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final departureTime = DateFormat.jm().format(summary.startTime.toLocal());
    final duration = formatDuration(summary.durationSeconds);

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          kRouteTripDetail,
          arguments: summary.id,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_kCardPadding),
          child: Row(
            children: <Widget>[
              Icon(
                _directionIcon(summary.direction),
                color: colorScheme.onSurfaceVariant,
                size: _kIconSize,
              ),
              const SizedBox(width: _kIconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(departureTime, style: textTheme.bodyLarge),
                    Text(
                      duration,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _DirectionChip(direction: summary.direction),
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Trip options',
                onPressed: () => _showOptionsSheet(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOptionsSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit trip'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) => EditTripSheet(summary: summary),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outlined,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete trip',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                await trip_actions.handleDeleteTrip(context, ref, summary.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _directionIcon(String direction) {
    if (direction == kDirectionToOffice) return Icons.arrow_upward_rounded;
    if (direction == kDirectionToHome) return Icons.arrow_downward_rounded;
    return Icons.help_outline_rounded;
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context) {
    final label = direction == kDirectionToOffice
        ? 'To office'
        : direction == kDirectionToHome
        ? 'To home'
        : 'Unknown';
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}
