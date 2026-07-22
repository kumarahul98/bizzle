import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';

/// Reactive stream of soft-deleted trips for the Settings → Deleted trips
/// screen (Phase 35, D-05), most recently deleted first. Each [TripSummary]
/// carries its `deletedAt` so the Trash screen renders the retention countdown
/// without a second query.
///
/// Manual provider — no `@riverpod` annotation, per the project-wide analyzer
/// pin documented in `lib/database/providers.dart`.
final StreamProvider<List<TripSummary>> deletedTripSummariesProvider =
    StreamProvider<List<TripSummary>>(
      (ref) => ref.watch(tripsDaoProvider).watchDeletedSummaries(),
      name: 'deletedTripSummariesProvider',
    );
