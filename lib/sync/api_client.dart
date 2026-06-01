import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/trip_serializer.dart';

/// Typed error thrown by [ApiClient]. Plan 02's `SyncEngine` branches on
/// [retryable] (HIGH-2 error classification) — NOT on raw status codes.
///
/// Classification rule:
///   * 5xx, a final 401-after-refresh, and transport failures
///     (network/socket/timeout) ⇒ [retryable] == `true`;
///   * all other 4xx — especially a 400 validation poison-pill ⇒
///     [retryable] == `false` (the engine fails it fast instead of burning
///     the retry budget);
///   * [notSignedIn] (no `currentUser`) ⇒ a no-op skip, never a retry case.
///
/// SECURITY (T-11-01): [toString] NEVER includes the Bearer token, uid, or
/// email — only [statusCode], [retryable], and a short fixed message.
class SyncException implements Exception {
  /// Not-signed-in gate: no token available, no HTTP request issued.
  const SyncException.notSignedIn()
      : statusCode = null,
        notSignedIn = true,
        retryable = false,
        message = 'not signed in';

  /// Non-2xx HTTP response. 5xx and a final 401 are retryable; all other 4xx
  /// (esp. 400 validation) are non-retryable poison pills.
  const SyncException.http(int code)
      : statusCode = code,
        notSignedIn = false,
        retryable = code >= 500 || code == 401,
        message = 'http error';

  /// Transport failure (network/socket/timeout/decode) — always retryable.
  const SyncException.transport()
      : statusCode = null,
        notSignedIn = false,
        retryable = true,
        message = 'transport error';

  /// HTTP status code, or null for a transport / not-signed-in error.
  final int? statusCode;

  /// True when the caller is not signed in (no token). The engine no-ops.
  final bool notSignedIn;

  /// Whether the engine should retry with backoff (true) or fail fast (false).
  final bool retryable;

  /// Short, PII-free message.
  final String message;

  @override
  String toString() =>
      'SyncException(statusCode: $statusCode, retryable: $retryable, '
      'message: $message)';
}

/// Thin typed transport over `package:http` to the Phase 10 Cloud Functions.
///
/// Owns: base URL, Bearer-token attachment via the injected `getToken` seam, a
/// single 401 force-refresh-retry (D-03), and non-2xx → [SyncException]
/// classification (HIGH-2). The engine (Plan 02) owns retry/backoff scheduling
/// — this class only CLASSIFIES and surfaces errors.
///
/// All three of `getToken`, `client`, and `baseUrl` are injectable so tests
/// pass a `MockClient` + fake token-getter + test/emulator host with no
/// Firebase platform channels. The production [apiClientProvider] wires the
/// REAL FirebaseAuth `currentUser?.getIdToken(forceRefresh)` as the token seam.
class ApiClient {
  /// Construct with injected dependencies. [baseUrl] defaults to [kApiBaseUrl].
  ApiClient({
    required http.Client client,
    required Future<String?> Function({bool forceRefresh}) getToken,
    String baseUrl = kApiBaseUrl,
  })  : _client = client,
        _getToken = getToken,
        _baseUrl = baseUrl;

  final http.Client _client;
  final Future<String?> Function({bool forceRefresh}) _getToken;
  final String _baseUrl;

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Run [send] with a fresh token, refreshing-and-retrying once on a 401.
  ///
  /// Throws [SyncException.notSignedIn] when no token is available, and wraps
  /// any thrown network/refresh/decode error as [SyncException.transport]
  /// (retryable) so a raw `http.ClientException` (which could carry the URL)
  /// never escapes. Returns the [http.Response] for 2xx; throws
  /// [SyncException.http] for any other final status — EXCEPT [allowStatus]
  /// codes, which are returned to the caller for idempotent handling
  /// (e.g. delete-404 = success per the amendment).
  Future<http.Response> _send(
    Future<http.Response> Function(String token) send, {
    Set<int> allowStatus = const {},
  }) async {
    final token = await _getToken();
    if (token == null) throw const SyncException.notSignedIn();

    try {
      var res = await send(token);
      if (res.statusCode == 401) {
        final fresh = await _getToken(forceRefresh: true);
        if (fresh == null) throw const SyncException.notSignedIn();
        res = await send(fresh);
      }
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (ok || allowStatus.contains(res.statusCode)) return res;
      throw SyncException.http(res.statusCode);
    } on SyncException {
      rethrow;
    } on Object {
      // Network/socket/timeout/refresh/decode failures — retryable, no leak.
      throw const SyncException.transport();
    }
  }

  /// `POST /trips/sync` — batch upsert of [trips] (D-02). Body is
  /// `{ "trips": [ <serialized> ] }`. Throws on non-2xx.
  Future<void> syncTrips(List<TripRow> trips) async {
    final body = jsonEncode({
      'trips': trips.map(TripSerializer.toJson).toList(),
    });
    await _send(
      (token) => _client.post(
        Uri.parse('$_baseUrl$kSyncTripsPath'),
        headers: _headers(token),
        body: body,
      ),
    );
  }

  /// `DELETE /trips/{tripId}` (D-02). An HTTP 404 is treated as SUCCESS
  /// (idempotent delete — the trip is already absent server-side, e.g. created
  /// then deleted locally before the create ever synced). All other 4xx remain
  /// non-retryable failures.
  Future<void> deleteTrip(String tripId) async {
    await _send(
      (token) => _client.delete(
        Uri.parse('$_baseUrl$kDeleteTripPathPrefix$tripId'),
        headers: _headers(token),
      ),
      allowStatus: const {404},
    );
  }

  /// `GET /trips/restore` (D-02). Unwraps the FULL double-wrapped envelope
  /// `decoded['body']['data']['trips']` (MEDIUM-1 — matches restore-trips.ts
  /// `{statusCode, body:{data:{trips}}}`) and maps each trip JSON object to a
  /// [TripsCompanion]. Throws [SyncException.transport] on a malformed envelope
  /// rather than silently returning `[]`.
  Future<List<TripsCompanion>> restoreTrips() async {
    final res = await _send(
      (token) => _client.get(
        Uri.parse('$_baseUrl$kRestoreTripsPath'),
        headers: _headers(token),
      ),
    );

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final body = decoded['body'] as Map<String, dynamic>?;
    final data = body?['data'] as Map<String, dynamic>?;
    final trips = data?['trips'] as List<dynamic>?;
    if (trips == null) throw const SyncException.transport();

    return trips
        .map((e) => TripSerializer.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// keepAlive provider for the production [ApiClient]. The token seam is wired
/// to the LIVE FirebaseAuth `currentUser?.getIdToken(forceRefresh)` (M4) — NOT
/// a stub. Tests construct [ApiClient] directly (or override this provider)
/// with a `MockClient` + fake token-getter + test/emulator `baseUrl`.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (ref) {
    final client = http.Client();
    ref.onDispose(client.close);
    return ApiClient(
      client: client,
      getToken: ({forceRefresh = false}) =>
          ref
              .read(firebaseAuthProvider)
              .currentUser
              ?.getIdToken(forceRefresh) ??
          Future<String?>.value(),
    );
  },
  name: 'apiClientProvider',
);
