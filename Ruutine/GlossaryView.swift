import Auth
import SwiftUI

struct GlossaryView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var exerciseService = ExerciseService()

    @State private var searchText = ""
    @State private var selectedCategory: MuscleCategory = .all
    @State private var showCreateExerciseSheet = false
    @State private var exercisePendingDelete: Exercise?
    @State private var deleteExerciseError: String?

    private var filteredExercises: [Exercise] {
        exerciseService.exercises
            .filter { exercise in
                let matchesSearch = searchText.trimmingCharacters(in: .whitespaces).isEmpty
                    || exercise.name.localizedCaseInsensitiveContains(searchText)
                    || exercise.primaryMuscle.localizedCaseInsensitiveContains(searchText)
                    || exercise.secondaryMuscles.contains {
                        $0.localizedCaseInsensitiveContains(searchText)
                    }
                let matchesCategory = selectedCategory.matches(exercise)
                return matchesSearch && matchesCategory
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchBar
                    categoryFilter
                    addCustomButton
                    exerciseList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .atlasScrollBottomInset()
            }

            if exerciseService.isLoading && exerciseService.exercises.isEmpty {
                ProgressView()
                    .tint(RuutineColor.accent)
            }
        }
        .task {
            await reload()
        }
        .sheet(isPresented: $showCreateExerciseSheet) {
            if let profileId = authVM.session?.user.id {
                CreateExerciseSheet(
                    exerciseService: exerciseService,
                    profileId: profileId
                ) { _ in }
            }
        }
        .alert("Delete Exercise?", isPresented: Binding(
            get: { exercisePendingDelete != nil },
            set: { if !$0 { exercisePendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let exercise = exercisePendingDelete else { return }
                exercisePendingDelete = nil
                Task { await confirmDeleteCustomExercise(exercise) }
            }
            Button("Cancel", role: .cancel) {
                exercisePendingDelete = nil
            }
        } message: {
            if let exercise = exercisePendingDelete {
                Text("Delete \"\(exercise.name)\"? This can't be undone.")
            }
        }
        .alert("Couldn't Delete Exercise", isPresented: Binding(
            get: { deleteExerciseError != nil },
            set: { if !$0 { deleteExerciseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteExerciseError ?? "")
        }
        .onChange(of: deleteExerciseError) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EXERCISE GLOSSARY")
                .font(.bebas(32))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Text("Search and filter exercises. Tap any to view details.")
                .font(.system(size: 13))
                .foregroundColor(RuutineColor.muted)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)

            TextField("Search exercises...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(RuutineColor.foreground)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryFilter: some View {
        Menu {
            ForEach(MuscleCategory.allCases, id: \.self) { category in
                Button(category.rawValue) {
                    Haptics.selection()
                    selectedCategory = category
                }
            }
        } label: {
            HStack {
                Text(selectedCategory.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RuutineColor.foreground)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RuutineColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var addCustomButton: some View {
        Button {
            Haptics.impact(.light)
            showCreateExerciseSheet = true
        } label: {
            Text("+ Add custom exercise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(RuutineColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundColor(RuutineColor.border)
                )
        }
        .buttonStyle(.plain)
    }

    private var exerciseList: some View {
        LazyVStack(spacing: 12) {
            if filteredExercises.isEmpty, !exerciseService.isLoading {
                Text("No exercises found.")
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }

            ForEach(filteredExercises) { exercise in
                exerciseCard(exercise)
            }
        }
    }

    @ViewBuilder
    private func exerciseCard(_ exercise: Exercise) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(RuutineColor.foreground)

                Text(exercise.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if exercise.id.hasPrefix("custom-") {
                Button {
                    exercisePendingDelete = exercise
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(RuutineColor.destructive)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func confirmDeleteCustomExercise(_ exercise: Exercise) async {
        guard let profileId = authVM.session?.user.id else {
            deleteExerciseError = ExerciseServiceError.notSignedIn.localizedDescription
            return
        }

        deleteExerciseError = nil
        do {
            try await exerciseService.deleteCustomExercise(exerciseId: exercise.id, profileId: profileId)
            Haptics.impact(.medium)
        } catch {
            deleteExerciseError = error.localizedDescription
        }
    }

    private func reload() async {
        await exerciseService.loadExercises(profileId: authVM.session?.user.id)
    }
}

private enum MuscleCategory: String, CaseIterable {
    case all = "All"
    case custom = "Custom"
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case legs = "Legs"
    case arms = "Arms"
    case core = "Core"
    case cardio = "Cardio"

    func matches(_ exercise: Exercise) -> Bool {
        switch self {
        case .all:
            return true
        case .custom:
            return exercise.id.hasPrefix("custom-")
        case .chest:
            return muscleSet(for: exercise).contains("Chest")
        case .back:
            return muscleSet(for: exercise).contains(where: { ["Back", "Lats", "Traps"].contains($0) })
        case .shoulders:
            return muscleSet(for: exercise).contains("Shoulders")
        case .legs:
            return muscleSet(for: exercise).contains(where: { ["Quadriceps", "Hamstrings", "Glutes", "Calves", "Legs"].contains($0) })
        case .arms:
            return muscleSet(for: exercise).contains(where: { ["Biceps", "Triceps", "Forearms"].contains($0) })
        case .core:
            return muscleSet(for: exercise).contains("Core")
        case .cardio:
            return muscleSet(for: exercise).contains("Cardio") || muscleSet(for: exercise).contains("Full Body")
        }
    }

    private func muscleSet(for exercise: Exercise) -> Set<String> {
        Set([exercise.primaryMuscle] + exercise.secondaryMuscles)
    }
}

private extension Exercise {
    var subtitle: String {
        var parts: [String] = [primaryMuscle]

        if !secondaryMuscles.isEmpty {
            parts.append(secondaryMuscles.joined(separator: ", "))
        }

        parts.append(difficulty.capitalized)
        return parts.joined(separator: " · ")
    }
}

#Preview {
    GlossaryView()
        .environmentObject(AuthViewModel())
}
