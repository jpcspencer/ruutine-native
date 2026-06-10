import SwiftUI

struct BodyHeatmapView: View {
    let trainedMuscles: [String]

    private var trained: Set<String> { Set(trainedMuscles) }

    var body: some View {
        HStack(spacing: 16) {
            bodyFigure(isFront: true)
            bodyFigure(isFront: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func bodyFigure(isFront: Bool) -> some View {
        ZStack {
            Image(systemName: isFront ? "figure.stand" : "figure.stand")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color(hex: "#8892a4"))
                .opacity(0.35)
                .scaleEffect(x: isFront ? 1 : -1, y: 1)

            if isFront {
                muscleHighlight("Chest", x: 0.5, y: 0.28, width: 0.34, height: 0.1)
                muscleHighlight("Shoulders", x: 0.28, y: 0.24, width: 0.12, height: 0.08)
                muscleHighlight("Shoulders", x: 0.72, y: 0.24, width: 0.12, height: 0.08)
                muscleHighlight("Core", x: 0.5, y: 0.42, width: 0.22, height: 0.12)
                muscleHighlight("Quadriceps", x: 0.38, y: 0.62, width: 0.14, height: 0.18)
                muscleHighlight("Quadriceps", x: 0.62, y: 0.62, width: 0.14, height: 0.18)
                muscleHighlight("Biceps", x: 0.22, y: 0.36, width: 0.1, height: 0.14)
                muscleHighlight("Biceps", x: 0.78, y: 0.36, width: 0.1, height: 0.14)
            } else {
                muscleHighlight("Back", x: 0.5, y: 0.3, width: 0.34, height: 0.14)
                muscleHighlight("Glutes", x: 0.5, y: 0.5, width: 0.28, height: 0.1)
                muscleHighlight("Hamstrings", x: 0.38, y: 0.64, width: 0.14, height: 0.16)
                muscleHighlight("Hamstrings", x: 0.62, y: 0.64, width: 0.14, height: 0.16)
                muscleHighlight("Calves", x: 0.38, y: 0.82, width: 0.12, height: 0.1)
                muscleHighlight("Calves", x: 0.62, y: 0.82, width: 0.12, height: 0.1)
                muscleHighlight("Triceps", x: 0.22, y: 0.36, width: 0.1, height: 0.14)
                muscleHighlight("Triceps", x: 0.78, y: 0.36, width: 0.1, height: 0.14)
            }
        }
        .frame(height: 180)
    }

    @ViewBuilder
    private func muscleHighlight(_ muscle: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        if trained.contains(muscle) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.ruuAccent.opacity(0.85))
                    .frame(
                        width: geo.size.width * width,
                        height: geo.size.height * height
                    )
                    .position(
                        x: geo.size.width * x,
                        y: geo.size.height * y
                    )
            }
        }
    }
}
