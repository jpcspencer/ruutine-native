import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let g = UIImpactFeedbackGenerator(style: style); g.prepare(); g.impactOccurred()
    }
    static func selection() {
        let g = UISelectionFeedbackGenerator(); g.prepare(); g.selectionChanged()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator(); g.prepare(); g.notificationOccurred(type)
    }
}
