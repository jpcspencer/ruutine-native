import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard AppPreferences.shared.hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: style); g.prepare(); g.impactOccurred()
    }
    static func selection() {
        guard AppPreferences.shared.hapticsEnabled else { return }
        let g = UISelectionFeedbackGenerator(); g.prepare(); g.selectionChanged()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AppPreferences.shared.hapticsEnabled else { return }
        let g = UINotificationFeedbackGenerator(); g.prepare(); g.notificationOccurred(type)
    }
}
