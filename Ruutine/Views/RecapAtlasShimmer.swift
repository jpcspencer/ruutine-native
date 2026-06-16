import SwiftUI

struct RecapAtlasShimmer: View {
    @State private var shimmerPhase: CGFloat = -1

    private let lineWidths: [CGFloat] = [1.0, 0.88, 0.62]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lineWidths.enumerated()), id: \.offset) { _, width in
                shimmerLine(widthFraction: width)
            }
        }
        .onAppear {
            shimmerPhase = -1
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private func shimmerLine(widthFraction: CGFloat) -> some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width * widthFraction

            RoundedRectangle(cornerRadius: 4)
                .fill(RuutineColor.muted.opacity(0.14))
                .frame(width: barWidth, height: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RuutineColor.muted.opacity(0.05),
                                    RuutineColor.accent.opacity(0.22),
                                    RuutineColor.muted.opacity(0.05),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth * 0.45)
                        .offset(x: shimmerPhase * barWidth * 0.9)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 12)
    }
}

/// Branded highlight sweep for the onboarding program-generation bubble.
struct OnboardingGeneratingShimmer: View {
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            LinearGradient(
                colors: [
                    RuutineColor.accent.opacity(0.0),
                    RuutineColor.accent.opacity(0.10),
                    RuutineColor.accent.opacity(0.20),
                    RuutineColor.accent.opacity(0.10),
                    RuutineColor.accent.opacity(0.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.5)
            .offset(x: shimmerPhase * width * 1.05)
        }
        .allowsHitTesting(false)
        .onAppear {
            shimmerPhase = -0.5
            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                shimmerPhase = 0.55
            }
        }
    }
}
