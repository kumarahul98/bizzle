import ActivityKit
import Foundation

/// ActivityAttributes required by the `live_activities` Flutter plugin (v2.4.9).
///
/// The struct name MUST be `LiveActivitiesAppAttributes` — the plugin creates
/// ActivityKit activities using this exact type name. A mismatch means the plugin
/// starts an activity of this type but the widget registered for any other type
/// will never match, so nothing renders on the lock screen or Dynamic Island.
///
/// Dynamic data is NOT carried in ContentState fields. Instead, the plugin
/// writes each Map entry from Dart into `UserDefaults(suiteName: appGroupId)`
/// under the key `"\(id)_\(mapKey)"`. The SwiftUI widget reads each field via
/// `sharedDefault.string/bool/double(forKey: context.attributes.prefixedKey("key"))`.
///
/// The 7 UserDefaults keys written by live_activity_service.dart:
///   elapsedFormatted (String), distanceFormatted (String),
///   movingFormatted  (String), stuckFormatted   (String),
///   isMoving         (Bool),   direction         (String),
///   startDate        (Double — ms since epoch)
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    // Required by the plugin's UserDefaults bridge — do not remove.
    public typealias LiveDeliveryData = ContentState

    // ContentState is intentionally empty: dynamic data travels through
    // UserDefaults, not through the ContentState Codable payload.
    public struct ContentState: Codable, Hashable { }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    /// Returns the UserDefaults key for a given Dart map key, prefixed with the
    /// activity id. Format mirrors the plugin's native implementation exactly:
    /// `"\(id)_\(key)"`.
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}
