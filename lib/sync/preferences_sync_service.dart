import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/saved_locations.dart';

/// Pushes and restores the user's saved Home/Office locations (Phase 29,
/// LOC-03).
///
/// ## Why this is not part of `SyncEngine`
///
/// `SyncEngine` drains the `sync_queue` table, whose `tripId` column is
/// non-nullable with an FK to `trips.id`. Preferences have no trip, so they
/// cannot ride that queue without widening the FK — a change that would put the
/// trip sync path (stabilized across Phases 24, 25.1 and 26) back at risk for
/// no benefit here.
///
/// A queue exists to preserve ordering and survive partial failure across many
/// entities. This payload is ONE row that always carries its whole current
/// value, so it is idempotent and order-independent: a failed push is simply
/// re-sent by the next change or the next sign-in, and cannot drift, because
/// there are no deltas to lose. That is D-02.
///
/// ## PII
///
/// Every method here handles coordinates that reveal where the user lives.
/// T-21-03 stands: nothing in this class logs a coordinate, and failures are
/// swallowed as bare booleans rather than surfaced with the payload attached.
class PreferencesSyncService {
  /// Construct with the API client and preferences DAO.
  const PreferencesSyncService({
    required ApiClient apiClient,
    required UserPreferencesDao userPreferencesDao,
  }) : _apiClient = apiClient,
       _userPreferencesDao = userPreferencesDao;

  final ApiClient _apiClient;
  final UserPreferencesDao _userPreferencesDao;

  /// Push the locally saved locations to the cloud.
  ///
  /// Returns `true` on success, `false` on any failure. Failure is deliberately
  /// non-fatal and non-throwing: this runs on a UI seam (saving a pin, signing
  /// in) and CLAUDE.md forbids blocking the UI on the network. Losing a push is
  /// recoverable by construction — the next change or sign-in re-sends the full
  /// current value.
  ///
  /// A user with nothing set still pushes: clearing a location is a real change
  /// that the cloud must learn about, and an all-null payload is explicitly
  /// valid server-side (SC#5). Skipping it would strand a cleared location as a
  /// stale coordinate in Firestore.
  Future<bool> push() async {
    try {
      final prefs = await _userPreferencesDao.getOrDefault();
      final locations = SavedLocations(
        homeLat: prefs.homeLat,
        homeLng: prefs.homeLng,
        officeLat: prefs.officeLat,
        officeLng: prefs.officeLng,
      );
      await _apiClient.syncPreferences(locations);
      return true;
    } on Object {
      // Includes SyncException.notSignedIn — a local-only user simply has
      // nowhere to push to, which is not an error worth surfacing.
      return false;
    }
  }

  /// Fetch cloud locations and write them into Drift, filling ONLY gaps.
  ///
  /// **D-03 — local always wins.** A cloud coordinate is applied only where the
  /// local value is currently null. CLAUDE.md makes the client authoritative
  /// and Drift the source of truth; a user who has already set Home on this
  /// device must never have it silently moved by a stale cloud copy. That makes
  /// restore purely additive, and removes any need for conflict UI.
  ///
  /// Returns the number of locations written (0, 1, or 2 — Home and Office are
  /// each a unit, since a lat without its lng is not a location).
  Future<int> restore() async {
    try {
      final cloud = await _apiClient.restorePreferences();
      if (cloud.isEmpty) return 0;

      final local = await _userPreferencesDao.getOrDefault();
      var written = 0;

      // Home and Office are handled as PAIRS, never per-field. Writing a lone
      // latitude would leave the resolver with half a coordinate — worse than
      // leaving the gap, because a half-set location reads as "set".
      final homeUnset = local.homeLat == null && local.homeLng == null;
      if (homeUnset && cloud.homeLat != null && cloud.homeLng != null) {
        await _userPreferencesDao.setHomeLocation(
          cloud.homeLat!,
          cloud.homeLng!,
        );
        written += 1;
      }

      final officeUnset = local.officeLat == null && local.officeLng == null;
      if (officeUnset && cloud.officeLat != null && cloud.officeLng != null) {
        await _userPreferencesDao.setOfficeLocation(
          cloud.officeLat!,
          cloud.officeLng!,
        );
        written += 1;
      }

      return written;
    } on Object {
      // Same rationale as push(): never block or crash a sign-in on this.
      return 0;
    }
  }
}

/// keepAlive provider for the production [PreferencesSyncService].
///
/// Tests construct the service directly with a `MockClient`-backed
/// [ApiClient] and an in-memory DAO rather than overriding this.
final Provider<PreferencesSyncService> preferencesSyncServiceProvider =
    Provider<PreferencesSyncService>(
      (ref) => PreferencesSyncService(
        apiClient: ref.watch(apiClientProvider),
        userPreferencesDao: ref.watch(userPreferencesDaoProvider),
      ),
      name: 'preferencesSyncServiceProvider',
    );
