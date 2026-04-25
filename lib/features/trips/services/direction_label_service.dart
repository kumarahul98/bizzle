import 'package:traevy/config/constants.dart';

/// Stateless direction-labeling utility.
///
/// Takes `startTimeLocal` already converted to device-local time and
/// `morningCutoffHour` from the user preferences morning cutoff setting.
/// Returns [kDirectionToOffice] or [kDirectionToHome].
///
/// No Riverpod, no async — construct inline wherever needed. The const
/// constructor allows callers to write `const DirectionLabelService()`
/// without allocation cost.
class DirectionLabelService {
  /// Create a direction label service.
  const DirectionLabelService();

  /// Apply the morning-cutoff rule (D-04).
  ///
  /// [startTimeLocal] MUST already be in local time —
  /// call `startTime.toLocal()` at every call site (Pitfall 2).
  ///
  /// `startTimeLocal.hour < morningCutoffHour` → [kDirectionToOffice]
  /// `startTimeLocal.hour >= morningCutoffHour` → [kDirectionToHome]
  String label(DateTime startTimeLocal, int morningCutoffHour) {
    return startTimeLocal.hour < morningCutoffHour
        ? kDirectionToOffice
        : kDirectionToHome;
  }
}
