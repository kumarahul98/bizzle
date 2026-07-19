import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Durable hand-off slot for a trip that has been finalized but not yet
/// written to Drift (WR-05).
///
/// ## Why this exists
///
/// On Android the GPS work runs in the `flutter_background_service` isolate.
/// When the user taps Stop, that isolate calls `TripAccumulator.finalize()` —
/// which, as its last act, CLEARS the `active_trip.json` recovery file — and
/// then emits `kTripFinalizedEvent` across the isolate boundary. Only after
/// that hop does the UI isolate write the trip to Drift.
///
/// Between the clear and the Drift write the finished commute exists ONLY in
/// memory, inside a service that is about to call `stopSelf()`. A force-stop
/// or OS kill in that window loses the trip outright, with no recovery path:
/// the interrupted-trip file is already gone and Drift never saw the row.
///
/// The window is short (an isolate hop plus one transaction) but it is real,
/// and it lands on a *completed* commute — the most expensive thing the app
/// can lose.
///
/// ## Why a file, not a MethodChannel
///
/// The original WR-05 mitigation called
/// `MethodChannel('traevy/tracking').invokeMethod('savePendingTrip', ...)`.
/// No native handler was ever registered, so every invocation threw
/// `MissingPluginException` into a swallowing `catch`, and the mitigation
/// never once executed.
///
/// Registering that handler in `MainActivity.configureFlutterEngine` would NOT
/// have fixed it: the call originates in the background service isolate, which
/// runs its own `FlutterEngine`. A handler bound to the activity's engine is
/// invisible to it.
///
/// A plain file has no such problem — [TripStatePersister] already writes from
/// this exact isolate on the GPS hot path, so the approach is proven here.
///
/// ## Relationship to `active_trip.json`
///
/// The two files are mutually exclusive by construction: `finalize()` clears
/// the interrupted-trip snapshot before this store is written. `active_trip`
/// means "a trip was in progress, offer resume or discard"; `pending_trip`
/// means "a trip COMPLETED, save it — no user decision required".
class PendingTripStore {
  /// Create a store. [directoryProvider] is injectable so tests can point at a
  /// temp directory without a platform channel — mirrors [TripStatePersister].
  PendingTripStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider;

  final Future<Directory> Function()? _directoryProvider;

  // Resolved once and reused: getApplicationDocumentsDirectory() is a
  // platform-channel round trip whose result never changes for the life of the
  // process. Caching the Future (not the File) lets concurrent first callers
  // share a single resolution.
  Future<File>? _cachedFile;

  Future<File> get _file => _cachedFile ??= _resolveFile();

  Future<File> _resolveFile() async {
    Directory dir;
    try {
      dir = _directoryProvider != null
          ? await _directoryProvider()
          : await getApplicationDocumentsDirectory();
    } on Object {
      dir = Directory.systemTemp;
    }
    return File('${dir.path}/pending_trip.json');
  }

  /// Persist [tripMap] (a `FinalizedTrip.toMap()` payload) so it survives
  /// process death.
  ///
  /// Callers MUST await this before emitting the finalized event — the whole
  /// point is that the durable write happens BEFORE the isolate hop. Writing
  /// via a temp file + rename makes the swap atomic, so a kill mid-write can
  /// never leave a truncated JSON document that later fails to decode.
  Future<void> save(Map<String, Object?> tripMap) async {
    final file = await _file;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(tripMap), flush: true);
    await temp.rename(file.path);
  }

  /// Read the pending trip, or `null` when there is none.
  ///
  /// A corrupt or unreadable file returns `null` rather than throwing: recovery
  /// runs during app start-up, where an exception would break launch. A trip we
  /// cannot decode is already lost — failing loudly here would only widen the
  /// damage.
  Future<Map<String, Object?>?> load() async {
    final file = await _file;
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, Object?>;
    } on Object {
      return null;
    }
  }

  /// Delete the pending trip. Safe to call when no file exists.
  Future<void> clear() async {
    final file = await _file;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
