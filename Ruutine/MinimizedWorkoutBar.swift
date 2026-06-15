import SwiftUI

enum MinimizedWorkoutBarLayout {
    static let height: CGFloat = 52
}

struct MinimizedWorkoutBar: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let onExpand: () -> Void

    private let accentColor = Color(red: 0.96, green: 0.77, blue: 0.09) // #f5c518

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)

                Text(viewModel.workoutName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RuutineColor.foreground)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(viewModel.elapsedFormatted)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accentColor)
                    .monospacedDigit()

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: MinimizedWorkoutBarLayout.height)
            .background(
                RuutineColor.surface
                    .shadow(color: RuutineColor.foreground.opacity(0.12), radius: 8, y: -2)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(accentColor.opacity(0.85))
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume workout, \(viewModel.workoutName), elapsed \(viewModel.elapsedFormatted)")
    }
}
