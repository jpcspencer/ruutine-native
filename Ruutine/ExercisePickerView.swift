import Auth
import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exerciseService = ExerciseService()
    @State private var searchText = ""
    @State private var selectedExerciseIDs: [String] = []
    @State private var createExerciseContext: CreateExerciseSheetContext?
    @FocusState private var isSearchFocused: Bool

    let onSelect: ([Exercise]) -> Void

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExercises: [Exercise] {
        let query = trimmedSearch
        guard !query.isEmpty else { return exerciseService.exercises }
        return exerciseService.exercises.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.primaryMuscle.localizedCaseInsensitiveContains(query)
        }
    }

    private var showCreateOption: Bool {
        !trimmedSearch.isEmpty && filteredExercises.isEmpty && !exerciseService.isLoading
    }

    private var selectedCount: Int {
        selectedExerciseIDs.count
    }

    private var selectedExercises: [Exercise] {
        selectedExerciseIDs.compactMap { id in
            exerciseService.exercises.first { $0.id == id }
        }
    }

    private var addButtonTitle: String {
        switch selectedCount {
        case 1: return "Add 1 Exercise"
        default: return "Add \(selectedCount) Exercises"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if exerciseService.isLoading && exerciseService.exercises.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(RuutineColor.accent)
                    Spacer()
                } else if showCreateOption {
                    emptySearchState
                } else if filteredExercises.isEmpty {
                    Text("No exercises found.")
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredExercises) { exercise in
                                Button {
                                    toggleSelection(for: exercise)
                                } label: {
                                    exerciseRow(exercise, isSelected: isSelected(exercise))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, selectedCount > 0 ? 8 : 16)
                    }
                }

                if selectedCount > 0 {
                    selectionFooter
                }
            }
            .background(RuutineColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .ruutineNavigationChrome()
            .toolbar {
                RuutineToolbarItem(placement: .topBarLeading) {
                    RuutineNavButton(kind: .back) {
                        dismiss()
                    }
                }
                RuutineToolbarItem(placement: .principal) {
                    Text("ADD EXERCISE")
                        .font(.bebas(24))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                }
            }
            .task {
                await exerciseService.loadExercises(profileId: authVM.session?.user.id)
            }
            .sheet(item: $createExerciseContext) { context in
                if let profileId = authVM.session?.user.id {
                    CreateExerciseSheet(
                        exerciseService: exerciseService,
                        profileId: profileId,
                        prefilledName: context.prefilledName
                    ) { exercise in
                        if !selectedExerciseIDs.contains(exercise.id) {
                            selectedExerciseIDs.append(exercise.id)
                        }
                        SoundFX.select()
                        Haptics.selection()
                    }
                }
            }
        }
    }

    private var selectionFooter: some View {
        VStack(spacing: 12) {
            Text("\(selectedCount) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(RuutineColor.muted)

            Button {
                confirmSelection()
            } label: {
                Text(addButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RuutineColor.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RuutineColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("No exercises found.")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)

            Button {
                Haptics.impact(.light)
                createExerciseContext = CreateExerciseSheetContext(prefilledName: trimmedSearch)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create \"\(trimmedSearch)\"")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(RuutineColor.accentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RuutineColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            Spacer()
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
                .focused($isSearchFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSearchFocused ? RuutineColor.accent : RuutineColor.border,
                    lineWidth: isSearchFocused ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func isSelected(_ exercise: Exercise) -> Bool {
        selectedExerciseIDs.contains(exercise.id)
    }

    private func toggleSelection(for exercise: Exercise) {
        if isSelected(exercise) {
            selectedExerciseIDs.removeAll { $0 == exercise.id }
            Haptics.selection()
        } else {
            selectedExerciseIDs.append(exercise.id)
            SoundFX.select()
            Haptics.selection()
        }
    }

    private func confirmSelection() {
        let exercises = selectedExercises
        guard !exercises.isEmpty else { return }
        SoundFX.add()
        Haptics.impact(.medium)
        onSelect(exercises)
        dismiss()
    }

    private func exerciseRow(_ exercise: Exercise, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(RuutineColor.foreground)
                    .multilineTextAlignment(.leading)

                Text("(\(exercise.primaryMuscle))")
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted)
            }

            Spacer(minLength: 0)

            if isSelected {
                ZStack {
                    Circle()
                        .fill(RuutineColor.accent)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(RuutineColor.accentForeground)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? RuutineColor.accent.opacity(0.12) : RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? RuutineColor.accent : RuutineColor.border, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ExercisePickerView { _ in }
        .environmentObject(AuthViewModel())
}
