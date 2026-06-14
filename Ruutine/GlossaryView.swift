import Auth
import SwiftUI

struct GlossaryView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var exerciseService = ExerciseService()

    @State private var searchText = ""
    @State private var selectedCategory: MuscleCategory = .all
    @State private var showAddCustom = false
    @State private var customExerciseName = ""
    @State private var customExerciseError: String?

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
        .alert("Add Custom Exercise", isPresented: $showAddCustom) {
            TextField("Exercise name", text: $customExerciseName)
            Button("Add") {
                Task { await addCustomExercise() }
            }
            Button("Cancel", role: .cancel) {
                customExerciseName = ""
            }
        } message: {
            Text("Enter a name for your custom exercise.")
        }
        .alert("Couldn't Add Exercise", isPresented: Binding(
            get: { customExerciseError != nil },
            set: { if !$0 { customExerciseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(customExerciseError ?? "")
        }
        .onChange(of: customExerciseError) { _, error in
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
            showAddCustom = true
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

    private func exerciseCard(_ exercise: Exercise) -> some View {
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
        .padding(16)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func addCustomExercise() async {
        let trimmed = customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let profileId = authVM.session?.user.id else {
            customExerciseError = ExerciseServiceError.notSignedIn.localizedDescription
            return
        }

        customExerciseError = nil
        do {
            _ = try await exerciseService.createCustomExercise(name: trimmed, profileId: profileId)
            customExerciseName = ""
        } catch {
            customExerciseError = error.localizedDescription
        }
    }

    private func reload() async {
        await exerciseService.loadExercises(profileId: authVM.session?.user.id)
    }
}

private enum MuscleCategory: String, CaseIterable {
    case all = "All"
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case legs = "Legs"
    case arms = "Arms"
    case core = "Core"
    case cardio = "Cardio"

    func matches(_ exercise: Exercise) -> Bool {
        guard self != .all else { return true }

        let muscles = Set([exercise.primaryMuscle] + exercise.secondaryMuscles)

        switch self {
        case .all:
            return true
        case .chest:
            return muscles.contains("Chest")
        case .back:
            return muscles.contains(where: { ["Back", "Lats", "Traps"].contains($0) })
        case .shoulders:
            return muscles.contains("Shoulders")
        case .legs:
            return muscles.contains(where: { ["Quadriceps", "Hamstrings", "Glutes", "Calves", "Legs"].contains($0) })
        case .arms:
            return muscles.contains(where: { ["Biceps", "Triceps", "Forearms"].contains($0) })
        case .core:
            return muscles.contains("Core")
        case .cardio:
            return muscles.contains("Cardio") || muscles.contains("Full Body")
        }
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
