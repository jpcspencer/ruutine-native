import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let onSelect: (Exercise) -> Void

    private var sortedExercises: [Exercise] {
        Exercise.all.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedExercises }
        return sortedExercises.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.primaryMuscle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if filteredExercises.isEmpty {
                    Text("No exercises found.")
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredExercises) { exercise in
                                Button {
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    exerciseRow(exercise)
                                }
                                .buttonStyle(.plain)

                                if exercise.id != filteredExercises.last?.id {
                                    Divider()
                                        .background(RuutineColor.border)
                                        .padding(.leading, 16)
                                }
                            }
                        }
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
                    Text("Add Exercise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(RuutineColor.foreground)
                }
            }
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

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 4) {
            Text(exercise.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(RuutineColor.foreground)

            Text("(\(exercise.primaryMuscle))")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ExercisePickerView { _ in }
}
