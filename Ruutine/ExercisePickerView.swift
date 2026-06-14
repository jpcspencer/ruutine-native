import Auth
import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exerciseService = ExerciseService()
    @State private var searchText = ""
    @State private var createError: String?
    @FocusState private var isSearchFocused: Bool

    let onSelect: (Exercise) -> Void

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
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    exerciseRow(exercise)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(RuutineColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(RuutineColor.foreground)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("ADD EXERCISE")
                        .font(.bebas(24))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                }
            }
            .task {
                await exerciseService.loadExercises(profileId: authVM.session?.user.id)
            }
            .alert("Couldn't Create Exercise", isPresented: Binding(
                get: { createError != nil },
                set: { if !$0 { createError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(createError ?? "")
            }
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("No exercises found.")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)

            Button {
                Task { await createAndSelect() }
            } label: {
                HStack(spacing: 8) {
                    if exerciseService.isSaving {
                        ProgressView()
                            .tint(RuutineColor.accentForeground)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
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
            .disabled(exerciseService.isSaving)
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

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 6) {
            Text(exercise.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(RuutineColor.foreground)
                .multilineTextAlignment(.leading)

            Text("(\(exercise.primaryMuscle))")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private func createAndSelect() async {
        guard let profileId = authVM.session?.user.id else {
            createError = ExerciseServiceError.notSignedIn.localizedDescription
            return
        }

        createError = nil
        do {
            let exercise = try await exerciseService.createCustomExercise(
                name: trimmedSearch,
                profileId: profileId
            )
            onSelect(exercise)
            dismiss()
        } catch {
            createError = error.localizedDescription
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
        .environmentObject(AuthViewModel())
}
