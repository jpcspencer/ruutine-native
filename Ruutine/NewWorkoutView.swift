import SwiftUI

struct WorkoutTemplate: Identifiable {
    let id = UUID()
    let name: String
    let exerciseCount: Int
    let exercises: [String]
}

struct NewWorkoutView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let onStart: ([WorkoutExercise]) -> Void

    private let templates: [WorkoutTemplate] = [
        WorkoutTemplate(
            name: "Upper Body Push",
            exerciseCount: 5,
            exercises: ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raise", "Tricep Pushdown"]
        ),
        WorkoutTemplate(
            name: "Upper Body Pull",
            exerciseCount: 5,
            exercises: ["Barbell Row", "Pull-Up", "Lat Pulldown", "Face Pull", "Bicep Curl"]
        ),
        WorkoutTemplate(
            name: "Legs",
            exerciseCount: 6,
            exercises: ["Barbell Squat", "Romanian Deadlift", "Leg Press", "Leg Curl", "Calf Raise", "Hip Thrust"]
        ),
        WorkoutTemplate(
            name: "Full Body",
            exerciseCount: 5,
            exercises: ["Barbell Squat", "Bench Press", "Barbell Row", "Overhead Press", "Deadlift"]
        ),
        WorkoutTemplate(
            name: "Push/Pull/Legs",
            exerciseCount: 5,
            exercises: ["Bench Press", "Barbell Row", "Barbell Squat", "Overhead Press", "Romanian Deadlift"]
        ),
        WorkoutTemplate(
            name: "Strong 5x5",
            exerciseCount: 3,
            exercises: ["Barbell Squat", "Bench Press", "Deadlift"]
        ),
    ]

    private var filteredTemplates: [WorkoutTemplate] {
        guard !searchText.isEmpty else { return templates }
        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.exercises.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        searchBar

                        sectionHeader("QUICK START")

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                            ],
                            spacing: 12
                        ) {
                            ForEach(filteredTemplates) { template in
                                templateCard(template)
                            }
                        }

                        sectionHeader("YOUR EXERCISES")

                        emptyState
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }

                startButton
            }
        }
    }

    private var header: some View {
        HStack {
            Text("NEW WORKOUT")
                .font(.bebas(36))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Spacer()

            RuutineNavButton(kind: .close) {
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(RuutineColor.muted)

            TextField("Search exercises...", text: $searchText)
                .foregroundColor(RuutineColor.foreground)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RuutineColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(RuutineColor.muted)
            .tracking(1.2)
    }

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        Button {
            startWorkout(exercises: template.exercises)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(template.exerciseCount) exercises")
                    .font(.system(size: 12))
                    .foregroundColor(RuutineColor.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Text("Add exercises now, or start empty and add as you go.")
            .font(.system(size: 14))
            .foregroundColor(RuutineColor.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundColor(RuutineColor.border)
            )
    }

    private var startButton: some View {
        Button {
            startWorkout(exercises: [])
        } label: {
            Text("Start Workout")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(RuutineColor.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RuutineColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(RuutineColor.background)
    }

    private func startWorkout(exercises names: [String]) {
        onStart(names.map { name in
            WorkoutExercise(
                name: name,
                primaryMuscle: Exercise.lookup(name: name)?.primaryMuscle
            )
        })
    }
}

#Preview {
    NewWorkoutView { _ in }
}
