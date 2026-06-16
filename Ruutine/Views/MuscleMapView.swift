import SwiftUI
import WebKit

// Capacitor reference: ~/ruutine/components/progress/body-heatmap.tsx
// SVG assets: ~/ruutine/public/svgs/man-front.svg, man-back.svg

struct MuscleMapView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let trainedMuscles: [String]
    var compact: Bool = true
    var gender: MuscleMapGender = .male

    private var trainedSvgIds: Set<String> {
        MuscleMapDefinitions.svgIds(for: trainedMuscles)
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 16) {
            MuscleMapSVGCanvas(
                svgResourceName: gender.frontResourceName,
                trainedIds: trainedSvgIds,
                accentHex: RuutineColor.accent.ruuHexString,
                baseHex: RuutineColor.muted.ruuHexString,
                themeKey: themeManager.current.rawValue
            )
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 160 : 256)

            MuscleMapSVGCanvas(
                svgResourceName: gender.backResourceName,
                trainedIds: trainedSvgIds,
                accentHex: RuutineColor.accent.ruuHexString,
                baseHex: RuutineColor.muted.ruuHexString,
                themeKey: themeManager.current.rawValue
            )
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 160 : 256)
        }
        .frame(maxWidth: .infinity)
    }
}

enum MuscleMapGender {
    case male
    case female

    static func from(biologicalSex: String?) -> MuscleMapGender {
        biologicalSex?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "female" ? .female : .male
    }

    var frontResourceName: String {
        switch self {
        case .male: "man-front"
        case .female: "female-front"
        }
    }

    var backResourceName: String {
        switch self {
        case .male: "man-back"
        case .female: "female-back"
        }
    }
}

enum MuscleMapDefinitions {
    /// Capacitor `MUSCLE_TO_SVG_IDS`
    static let muscleToSvgIds: [String: [String]] = [
        "Chest": ["chest"],
        "Back": ["lats", "lower_back", "traps"],
        "Shoulders": ["shoulders"],
        "Biceps": ["biceps"],
        "Triceps": ["triceps"],
        "Quadriceps": ["quadriceps"],
        "Hamstrings": ["hamstrings"],
        "Glutes": ["glutes"],
        "Calves": ["calves"],
        "Core": ["abs", "oblique"],
    ]

    static let allHighlightableSvgIds: [String] = {
        Array(Set(muscleToSvgIds.values.flatMap { $0 })).sorted()
    }()

    static func svgIds(for trainedMuscles: [String]) -> Set<String> {
        var ids = Set<String>()
        for muscle in trainedMuscles {
            guard let mapped = muscleToSvgIds[muscle] else { continue }
            mapped.forEach { ids.insert($0) }
        }
        return ids
    }
}

private struct MuscleMapSVGCanvas: UIViewRepresentable {
    let svgResourceName: String
    let trainedIds: Set<String>
    let accentHex: String
    let baseHex: String
    let themeKey: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let trainedKey = trainedIds.sorted().joined(separator: "|")
        if context.coordinator.svgResourceName == svgResourceName,
           context.coordinator.trainedKey == trainedKey,
           context.coordinator.themeKey == themeKey,
           context.coordinator.accentHex == accentHex,
           context.coordinator.baseHex == baseHex {
            return
        }
        context.coordinator.svgResourceName = svgResourceName
        context.coordinator.trainedKey = trainedKey
        context.coordinator.themeKey = themeKey
        context.coordinator.accentHex = accentHex
        context.coordinator.baseHex = baseHex

        guard let url = Bundle.main.url(
            forResource: svgResourceName,
            withExtension: "svg",
            subdirectory: "Resources/SVGs"
        ) ?? Bundle.main.url(forResource: svgResourceName, withExtension: "svg"),
              let svgText = try? String(contentsOf: url, encoding: .utf8)
        else {
            print("[MuscleMapView] Missing SVG resource: \(svgResourceName).svg")
            return
        }

        let allIdsJSON = jsonString(from: MuscleMapDefinitions.allHighlightableSvgIds)
        let trainedJSON = jsonString(from: Array(trainedIds).sorted())

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
          html, body { margin: 0; padding: 0; background: transparent; width: 100%; height: 100%; }
          svg { width: 100%; height: 100%; display: block; }
        </style>
        </head>
        <body>
        \(svgText)
        <script>
        (function() {
          const accent = '#\(accentHex)';
          const fallback = '#\(baseHex)';
          const allIds = \(allIdsJSON);
          const trainedIds = new Set(\(trainedJSON));
          const svg = document.querySelector('svg');
          if (svg) {
            svg.removeAttribute('width');
            svg.removeAttribute('height');
          }
          allIds.forEach((id) => {
            const el = document.getElementById(id);
            if (!el) return;
            const fill = trainedIds.has(id) ? accent : fallback;
            el.querySelectorAll('path, rect, polyline, line').forEach((node) => {
              node.setAttribute('fill', fill);
            });
          });
        })();
        </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var svgResourceName: String?
        var trainedKey: String?
        var themeKey: String?
        var accentHex: String?
        var baseHex: String?
    }

    private func jsonString(from values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

#Preview {
    MuscleMapView(trainedMuscles: ["Chest", "Back", "Quadriceps"])
        .padding()
        .background(RuutineColor.background)
        .environmentObject(ThemeManager.shared)
}
