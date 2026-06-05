//
//  TraevyLiveActivityLiveActivity.swift
//  TraevyLiveActivity
//
//  Created by Rahul kumar on 05/06/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TraevyLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TraevyLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TraevyLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TraevyLiveActivityAttributes {
    fileprivate static var preview: TraevyLiveActivityAttributes {
        TraevyLiveActivityAttributes(name: "World")
    }
}

extension TraevyLiveActivityAttributes.ContentState {
    fileprivate static var smiley: TraevyLiveActivityAttributes.ContentState {
        TraevyLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TraevyLiveActivityAttributes.ContentState {
         TraevyLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TraevyLiveActivityAttributes.preview) {
   TraevyLiveActivityLiveActivity()
} contentStates: {
    TraevyLiveActivityAttributes.ContentState.smiley
    TraevyLiveActivityAttributes.ContentState.starEyes
}
