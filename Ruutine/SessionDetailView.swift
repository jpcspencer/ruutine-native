import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let session: HistorySessionItem
    let logs: [ExerciseLogDetail]
    let isImperial: Bool

    private var groupedExercises: [(name: String, sets: [ExerciseLogDetail])] {
        var groups: [String: [ExerciseLogDetail]] = [:]
        for log in logs {
            let name = log.exerciseName ?? "Unknown"
            groups[name, default: []].append(log)
        }
        return groups
            .map { (name: $0.key, sets: $0.value.sorted { ($0.setNumber ?? 0) < ($1.setNumber ?? 0) }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader("SESSION")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.sessionName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(RuutineColor.foreground)

                        Text(HistoryFormatting.detailDateTime(session.date))
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)
                    }

                    sectionHeader("EXERCISES")

                    if groupedExercises.isEmpty {
                        Text("No exercise logs for this session.")
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)
                    } else {
                        ForEach(groupedExercises, id: \.name) { exercise in
                            exerciseCard(exercise)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(RuutineColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Session details")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(RuutineColor.foreground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button("Edit") {
                            print("Edit session tapped")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(RuutineColor.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RuutineColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(RuutineColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(RuutineColor.muted)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(RuutineColor.muted)
            .tracking(1.2)
    }

    private func exerciseCard(_ exercise: (name: String, sets: [ExerciseLogDetail])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(RuutineColor.foreground)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                Text("Set \(set.setNumber ?? index + 1): \(HistoryFormatting.setLine(weightKg: set.weightKg, reps: set.reps, isImperial: isImperial))")
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RuutineColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
