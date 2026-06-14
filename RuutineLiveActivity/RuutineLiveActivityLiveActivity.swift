import ActivityKit
import WidgetKit
import SwiftUI

private extension Color {
    static let ruutineBG = Color(red: 0.039, green: 0.039, blue: 0.039)     // #0a0a0a
    static let ruutineAccent = Color(red: 0.961, green: 0.773, blue: 0.094) // #f5c518
    static let ruutineFG = Color(red: 0.941, green: 0.925, blue: 0.878)     // #f0ece0
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .activityBackgroundTint(Color.ruutineBG)
                .activitySystemActionForegroundColor(Color.ruutineAccent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.headline).foregroundStyle(Color.ruutineFG).lineLimit(1)
                        Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isResting, let end = context.state.restEndDate, end > Date() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("REST").font(.caption2).foregroundStyle(Color.ruutineAccent)
                            Text(timerInterval: Date()...end, countsDown: true)
                                .font(.system(.title3, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.ruutineFG)
                                .multilineTextAlignment(.trailing).frame(maxWidth: 70)
                        }
                    } else {
                        WorkoutTargetView(state: context.state).foregroundStyle(Color.ruutineFG)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.workoutName)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Color.ruutineAccent)
            } compactTrailing: {
                if context.state.isResting, let end = context.state.restEndDate, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit().frame(maxWidth: 44).foregroundStyle(Color.ruutineFG)
                } else {
                    Text("\(context.state.currentSet)/\(context.state.totalSets)")
                        .monospacedDigit().foregroundStyle(Color.ruutineFG)
                }
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Color.ruutineAccent)
            }
            .keylineTint(Color.ruutineAccent)
        }
    }
}

struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.workoutName.uppercased())
                    .font(.caption2).foregroundStyle(Color.ruutineAccent)
                Text(context.state.exerciseName)
                    .font(.title3.bold()).foregroundStyle(Color.ruutineFG).lineLimit(1)
                Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if context.state.isResting, let end = context.state.restEndDate, end > Date() {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REST").font(.caption2).foregroundStyle(Color.ruutineAccent)
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.ruutineFG).frame(maxWidth: 120)
                }
            } else {
                WorkoutTargetView(state: context.state).foregroundStyle(Color.ruutineFG)
            }
        }
        .padding()
    }
}

struct WorkoutTargetView: View {
    let state: WorkoutActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let weight = state.weight {
                Text(weight == weight.rounded() ? "\(Int(weight)) kg" : String(format: "%.1f kg", weight))
                    .font(.title3.bold())
            }
            if let reps = state.targetReps {
                Text("\(reps) reps").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#if swift(>=5.9)
@available(iOS 17.0, *)
#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes(workoutName: "Afternoon Workout")) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(exerciseName: "Bench Press", currentSet: 2, totalSets: 4, targetReps: 8, weight: 100, isResting: false, restEndDate: nil)
    WorkoutActivityAttributes.ContentState(exerciseName: "Bench Press", currentSet: 2, totalSets: 4, targetReps: 8, weight: 100, isResting: true, restEndDate: Date().addingTimeInterval(90))
}
#endif
