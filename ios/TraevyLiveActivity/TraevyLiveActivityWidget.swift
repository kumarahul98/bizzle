import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared UserDefaults container (App Group)

/// Shared container that the live_activities Flutter plugin writes to.
/// The suite name must match `kLiveActivityAppGroupId` in constants.dart
/// (`group.com.travey.app`) and the App Group capability on both targets.
private let sharedDefault = UserDefaults(suiteName: "group.com.travey.app")!

// MARK: - Color helpers (Traevy token approximations for SwiftUI)

private extension Color {
    /// Traevy moving state color (approximates #2E8B57 light / #5BC88A dark).
    static var traevyMoving: Color {
        Color(red: 0.18, green: 0.55, blue: 0.34)
    }

    /// Traevy stuck state color (approximates #C4820A light / #D4A832 dark).
    static var traevyStuck: Color {
        Color(red: 0.77, green: 0.51, blue: 0.04)
    }
}

// MARK: - Localisation helper

private extension String {
    /// Look up a key in the Localizable.strings bundle for the extension.
    var localizedLiveActivity: String {
        NSLocalizedString(self, bundle: .main, comment: "")
    }
}

// MARK: - Shared sub-views

/// Direction badge: uppercase "TO OFFICE" / "TO HOME" on a tinted background.
private struct DirectionBadge: View {
    let direction: String

    var body: some View {
        let label: String = direction == "to_office"
            ? "live_activity_to_office".localizedLiveActivity
            : "live_activity_to_home".localizedLiveActivity

        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// Moving / stuck status chip: coloured dot + "MOVING" or "STUCK".
private struct StatusChip: View {
    let isMoving: Bool

    var body: some View {
        let label: String = isMoving
            ? "live_activity_moving".localizedLiveActivity
            : "live_activity_stuck".localizedLiveActivity
        let chipColor: Color = isMoving ? .traevyMoving : .traevyStuck

        HStack(spacing: 4) {
            Circle()
                .fill(chipColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(chipColor)
        }
    }
}

/// Full-width Stop commute button (URL-scheme deep-link — free-provisioning safe).
private struct StopButton: View {
    var body: some View {
        Link(destination: URL(string: "traevy://stop")!) {
            Text("live_activity_stop".localizedLiveActivity)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.red)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Lock-screen expanded view (Surface C)

struct TraevyLockScreenView: View {
    /// Pre-resolved values read from UserDefaults before the view is constructed.
    let distanceFormatted: String
    let direction: String
    let isMoving: Bool
    let startDateAsDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: direction badge + moving/stuck chip
            HStack {
                DirectionBadge(direction: direction)
                Spacer()
                StatusChip(isMoving: isMoving)
            }

            // Row 2: elapsed timer (client-side ticking from startDate) + distance
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        timerInterval: startDateAsDate...Date.distantFuture,
                        countsDown: false
                    )
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .monospacedDigit()

                    Text("live_activity_elapsed".localizedLiveActivity)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(distanceFormatted)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .monospacedDigit()

                    Text("live_activity_distance".localizedLiveActivity)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Row 3: Stop button
            StopButton()
        }
        .padding(16)
    }
}

// MARK: - Main Widget (IOS-13)

struct TraevyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // ----------------------------------------------------------------
            // Read dynamic fields from the shared App Group UserDefaults.
            // The plugin writes each Dart map key under "\(activityId)_\(key)".
            // Use safe defaults so the first frame renders before the first update.
            // ----------------------------------------------------------------
            let distanceFormatted = sharedDefault.string(
                forKey: context.attributes.prefixedKey("distanceFormatted")
            ) ?? "0.0 km"

            let direction = sharedDefault.string(
                forKey: context.attributes.prefixedKey("direction")
            ) ?? "to_office"

            let isMoving = sharedDefault.bool(
                forKey: context.attributes.prefixedKey("isMoving")
            )

            // startDate is sent as Double (ms epoch) — convert to Date for timerInterval.
            let startDateMs = sharedDefault.double(
                forKey: context.attributes.prefixedKey("startDate")
            )
            let startDateAsDate: Date = startDateMs > 0
                ? Date(timeIntervalSince1970: startDateMs / 1000.0)
                : Date()

            // Lock screen / notification banner presentation
            TraevyLockScreenView(
                distanceFormatted: distanceFormatted,
                direction: direction,
                isMoving: isMoving,
                startDateAsDate: startDateAsDate
            )
            .activityBackgroundTint(Color(.systemBackground))

        } dynamicIsland: { context in
            // ----------------------------------------------------------------
            // Read the same fields for Dynamic Island regions.
            // ----------------------------------------------------------------
            let distanceFormatted = sharedDefault.string(
                forKey: context.attributes.prefixedKey("distanceFormatted")
            ) ?? "0.0 km"

            let direction = sharedDefault.string(
                forKey: context.attributes.prefixedKey("direction")
            ) ?? "to_office"

            let isMoving = sharedDefault.bool(
                forKey: context.attributes.prefixedKey("isMoving")
            )

            let startDateMs = sharedDefault.double(
                forKey: context.attributes.prefixedKey("startDate")
            )
            let startDateAsDate: Date = startDateMs > 0
                ? Date(timeIntervalSince1970: startDateMs / 1000.0)
                : Date()

            return DynamicIsland {
                // MARK: Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            timerInterval: startDateAsDate...Date.distantFuture,
                            countsDown: false
                        )
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .monospacedDigit()

                        Text("live_activity_elapsed".localizedLiveActivity)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(distanceFormatted)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .monospacedDigit()

                        Text("live_activity_distance".localizedLiveActivity)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        DirectionBadge(direction: direction)
                        StatusChip(isMoving: isMoving)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    StopButton()
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }

            } compactLeading: {
                // MARK: Compact Leading — car icon + elapsed timer
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 12))

                    Text(
                        timerInterval: startDateAsDate...Date.distantFuture,
                        countsDown: false
                    )
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                }

            } compactTrailing: {
                // MARK: Compact Trailing — status dot + distance
                HStack(spacing: 3) {
                    Circle()
                        .fill(isMoving ? Color.traevyMoving : Color.traevyStuck)
                        .frame(width: 6, height: 6)

                    Text(distanceFormatted)
                        .font(.system(size: 11, weight: .medium))
                }

            } minimal: {
                // MARK: Minimal — car icon in accent color
                Image(systemName: "car.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 16))
            }
            .widgetURL(URL(string: "traevy://open"))
            .keylineTint(Color.accentColor)
        }
    }
}
