//
//  RuutineLiveActivityLiveActivity.swift
//  RuutineLiveActivity
//
//  Created by Jordan Spencer on 6/14/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RuutineLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct RuutineLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RuutineLiveActivityAttributes.self) { context in
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

extension RuutineLiveActivityAttributes {
    fileprivate static var preview: RuutineLiveActivityAttributes {
        RuutineLiveActivityAttributes(name: "World")
    }
}

extension RuutineLiveActivityAttributes.ContentState {
    fileprivate static var smiley: RuutineLiveActivityAttributes.ContentState {
        RuutineLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: RuutineLiveActivityAttributes.ContentState {
         RuutineLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: RuutineLiveActivityAttributes.preview) {
   RuutineLiveActivityLiveActivity()
} contentStates: {
    RuutineLiveActivityAttributes.ContentState.smiley
    RuutineLiveActivityAttributes.ContentState.starEyes
}
