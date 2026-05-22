import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/dashboard/providers/dashboard_providers.dart';
import 'package:traevy/features/dashboard/widgets/empty_slot_row.dart';
import 'package:traevy/features/dashboard/widgets/in_progress_card.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/shared/widgets/section_label.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';

/// "Today" section of the dashboard showing recorded trips, an in-progress
/// card when tracking, and empty-slot placeholders.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §3 Today section.
class TodaySection extends ConsumerWidget {
  /// Create the today section.
  const TodaySection({required this.trackingState, super.key});

  /// Current tracking state; drives [InProgressCard] visibility.
  final TrackingState trackingState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final asyncToday = ref.watch(todaysTripSummariesProvider);
    final isActive = trackingState is TrackingActive;

    return asyncToday.when(
      data: (trips) => _TodaySectionContent(
        trips: trips,
        isActive: isActive,
        trackingState: trackingState,
        tokens: tokens,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          kDashboardErrorMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _TodaySectionContent extends StatelessWidget {
  const _TodaySectionContent({
    required this.trips,
    required this.isActive,
    required this.trackingState,
    required this.tokens,
  });

  final List<TripSummary> trips;
  final bool isActive;
  final TrackingState trackingState;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    final tripCount = trips.length;
    final emptyCount = (tripCount < 2 && !isActive) ? 2 - tripCount : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const SectionLabel(text: 'Today'),
              const Spacer(),
              Text(
                '$tripCount trip${tripCount == 1 ? '' : 's'}',
                style: TraevyFonts.ui(size: 11, color: tokens.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: tokens.bgElev,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            children: [
              if (isActive)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: InProgressCard(
                    active: trackingState as TrackingActive,
                  ),
                ),
              for (int i = 0; i < trips.length; i++)
                TripRowCard(
                  direction: trips[i].direction,
                  startTime: trips[i].startTime,
                  endTime: trips[i].endTime,
                  durationSeconds: trips[i].durationSeconds,
                  distanceMeters: trips[i].distanceMeters,
                  stuckSeconds: trips[i].timeStuckSeconds,
                  showDivider: i < trips.length - 1 || emptyCount > 0,
                  onTap: () => Navigator.pushNamed(
                    context,
                    kRouteTripDetail,
                    arguments: trips[i].id,
                  ),
                ),
              for (int i = 0; i < emptyCount; i++)
                Column(
                  children: [
                    const EmptySlotRow(),
                    if (i < emptyCount - 1)
                      Divider(
                        color: tokens.border,
                        thickness: 1,
                        height: 1,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
