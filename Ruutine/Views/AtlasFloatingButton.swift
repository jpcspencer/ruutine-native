import SwiftUI

enum AtlasFloatingButtonLayout {
  /// Matches `MainTabView` tab bar reserved height.
  static let tabBarHeight: CGFloat = 72
  static let size: CGFloat = 56
  static let trailingInset: CGFloat = 18
  static let spacingAboveTabBar: CGFloat = 18

  /// Bottom padding from screen edge to button bottom (tab bar top + gap).
  static var bottomInset: CGFloat { tabBarHeight + spacingAboveTabBar }

  /// Extra scroll padding so the last row clears the floating button.
  static var scrollBottomInset: CGFloat { size + spacingAboveTabBar + 16 }
}

struct AtlasFloatingButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "bubble.left.and.bubble.right.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundColor(RuutineColor.accentForeground)
        .frame(width: AtlasFloatingButtonLayout.size, height: AtlasFloatingButtonLayout.size)
        .background(RuutineColor.accent)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Chat with Atlas")
  }
}

extension View {
  func atlasScrollBottomInset() -> some View {
    padding(.bottom, AtlasFloatingButtonLayout.scrollBottomInset)
  }
}
