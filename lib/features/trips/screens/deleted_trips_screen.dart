import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/deleted_trips_provider.dart';
import 'package:traevy/features/trips/widgets/deleted_trip_tile.dart';

/// Settings → Deleted trips (the Trash), Phase 35 D-05.
///
/// Lists soft-deleted trips newest-deleted first, each showing how long ago it
/// was deleted and how long remains before the app-start purge removes it, with
/// Restore and Delete-permanently actions. Pushed as its own route (its own
/// `Scaffold` + back button) from the Settings Data section.
class DeletedTripsScreen extends ConsumerWidget {
  /// Create the Trash screen.
  const DeletedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrips = ref.watch(deletedTripSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(kTrashScreenTitle)),
      body: SafeArea(
        child: asyncTrips.when(
          data: (trips) => trips.isEmpty
              ? const _TrashEmptyState()
              : _TrashList(trips: trips),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                kTrashLoadErrorMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrashList extends StatelessWidget {
  const _TrashList({required this.trips});

  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: trips.length,
      itemBuilder: (context, i) => DeletedTripTile(
        trip: trips[i],
        showDivider: i < trips.length - 1,
      ),
    );
  }
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    const body =
        '$kTrashEmptyBodyPrefix$kTrashRetentionDays$kTrashEmptyBodySuffix';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              kTrashEmptyHeading,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
