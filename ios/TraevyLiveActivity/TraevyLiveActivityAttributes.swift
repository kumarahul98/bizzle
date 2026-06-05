import ActivityKit
import WidgetKit
import SwiftUI

/// ActivityAttributes for the Traevy Live Activity (IOS-13).
///
/// ContentState carries the 7 dynamic fields that the live_activities Flutter
/// plugin writes to the shared App Group UserDefaults suite on every snapshot
/// update. The `LiveDeliveryData` typealias is required by the plugin's
/// UserDefaults bridge (it reads prefixed keys using this type name).
///
/// IMPORTANT: `startDate` is a Double (ms since epoch), NOT a Swift Date.
/// The live_activities UserDefaults/Codable bridge serialises Dart's int epoch
/// value as a numeric JSON value and cannot decode it as a Swift Date. Convert
/// to Date in the view layer: `Date(timeIntervalSince1970: startDate / 1000.0)`.
struct TraevyLiveActivityAttributes: ActivityAttributes {
    // Required by the live_activities plugin's UserDefaults bridge.
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        /// Pre-formatted elapsed string, e.g. "38:22" or "1:04:15".
        var elapsedFormatted: String
        /// Pre-formatted distance string, e.g. "2.4 km".
        var distanceFormatted: String
        /// Pre-formatted moving time string, e.g. "34m".
        var movingFormatted: String
        /// Pre-formatted stuck time string, e.g. "4m".
        var stuckFormatted: String
        /// True when current speed >= kStuckSpeedThresholdKmh (10 km/h).
        var isMoving: Bool
        /// Trip direction: "to_office" or "to_home".
        var direction: String
        /// Trip start time as milliseconds since epoch (Double, NOT Date).
        /// Convert in view: Date(timeIntervalSince1970: startDate / 1000.0)
        var startDate: Double
    }

    var id = UUID()
}
