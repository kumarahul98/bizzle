import WidgetKit
import SwiftUI

/// Widget bundle for the TraevyLiveActivity extension.
/// Exposes ONLY the ActivityKit Live Activity widget (IOS-13).
/// The Control Widget and App Intent were removed — they trigger the
/// ExtractAppIntentsMetadata build cycle and require entitlements unavailable
/// on the free-provisioning personal-team profile.
@main
struct TraevyLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TraevyLiveActivityWidget()
    }
}
