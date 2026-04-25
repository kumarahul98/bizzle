import 'package:traevy/config/constants.dart';

/// Stateless direction-labeling utility.
///
/// Takes `startTimeLocal` already converted to device-local time,
/// `morningCutoffHour`, and `eveningCutoffHour` from user preferences.
/// Returns [kDirectionToOffice] or [kDirectionToHome].
///
/// No Riverpod, no async — construct inline wherever needed. The const
/// constructor allows callers to write `const DirectionLabelService()`
/// without allocation cost.
class DirectionLabelService {
  /// Create a direction label service.
  const DirectionLabelService();

  /// Apply the two-cutoff labeling rule (D-04).
  ///
  /// [startTimeLocal] MUST already be in local time —
  /// call `startTime.toLocal()` at every call site (Pitfall 2).
  ///
  /// `hour < morningCutoffHour`  → [kDirectionToOffice]
  /// `hour >= eveningCutoffHour` → [kDirectionToHome]
  /// Between the two cutoffs     → [kDirectionToHome] (ambiguous; default)
  String label(
    DateTime startTimeLocal,
    int morningCutoffHour,
    int eveningCutoffHour,
  ) {
    final hour = startTimeLocal.hour;
    if (hour < morningCutoffHour) return kDirectionToOffice;
    if (hour >= eveningCutoffHour) return kDirectionToHome;
    // Between the two cutoffs: ambiguous — default to to_home.
    return kDirectionToHome;
  }
}
