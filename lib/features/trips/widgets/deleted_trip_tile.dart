import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/services/trip_actions.dart';
import 'package:traevy/shared/utils/retention_format.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';

/// One row on the Settings → Deleted trips screen (Phase 35, D-05).
///
/// Reuses [TripRowCard] for the trip summary, then adds the retention countdown
/// (computed from `deletedAt`, never stored) and the two actions: Restore, and
/// the destructive Delete permanently. The list is a live stream, so a
/// restored or purged row disappears on its own after the action resolves.
class DeletedTripTile extends ConsumerWidget {
  /// Create a tile for the soft-deleted [trip].
  const DeletedTripTile({
    required this.trip,
    this.showDivider = true,
    super.key,
  });

  /// The soft-deleted trip. Its `deletedAt` is non-null by construction (the
  /// tile is only built from `watchDeletedSummaries`).
  final TripSummary trip;

  /// Whether to draw a hairline divider under the tile.
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final deletedAt = trip.deletedAt;
    final countdown = deletedAt == null
        ? ''
        : formatRetentionCountdown(
            deletedAtUtc: deletedAt,
            nowUtc: DateTime.now().toUtc(),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TripRowCard(
          direction: trip.direction,
          startTime: trip.startTime,
          endTime: trip.endTime,
          durationSeconds: trip.durationSeconds,
          distanceMeters: trip.distanceMeters,
          stuckSeconds: trip.timeStuckSeconds,
          isEdited: trip.isEdited,
          showDivider: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            countdown,
            style: TraevyFonts.mono(size: 12, color: tokens.textDim),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () =>
                    unawaited(handleRestoreTrip(context, ref, trip.id)),
                child: const Text(kTrashRestoreLabel),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: tokens.record),
                onPressed: () => unawaited(
                  handleDeleteTripPermanently(context, ref, trip.id),
                ),
                child: const Text(kTrashDeletePermanentlyLabel),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: tokens.border, thickness: 1, height: 1),
      ],
    );
  }
}
