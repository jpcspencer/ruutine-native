import SwiftUI

struct CreateExerciseSheet: View {
    @ObservedObject var exerciseService: ExerciseService
    let profileId: UUID
    var prefilledName: String = ""
    let onCreated: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    @State private var name = ""
    @State private var selectedBodyPart: String?
    @State private var selectedCategory: ExerciseCategory?
    @State private var errorMessage: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !trimmedName.isEmpty && selectedCategory != nil && !exerciseService.isSaving
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        nameSection
                        bodyPartSection
                        exerciseTypeSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(RuutineColor.destructive)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 8)
                }

                createButtonBar
            }
            .background(RuutineColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .ruutineNavigationChrome()
            .toolbar {
                RuutineToolbarItem(placement: .topBarLeading) {
                    RuutineNavButton(kind: .cancel) {
                        dismiss()
                    }
                    .disabled(exerciseService.isSaving)
                }
                RuutineToolbarItem(placement: .principal) {
                    Text("CREATE EXERCISE")
                        .font(.bebas(22))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                }
            }
            .onAppear {
                if name.isEmpty, !prefilledName.isEmpty {
                    name = prefilledName
                }
            }
        }
        .presentationDetents([.large])
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NAME")

            TextField("Exercise name", text: $name)
                .font(.system(size: 15))
                .foregroundColor(RuutineColor.foreground)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isNameFocused ? RuutineColor.accent : RuutineColor.border,
                            lineWidth: isNameFocused ? 2 : 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isNameFocused)
        }
    }

    private var bodyPartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("BODY PART")

            Text("Optional — defaults to Other if none selected.")
                .font(.system(size: 12))
                .foregroundColor(RuutineColor.muted)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Self.bodyPartOptions, id: \.self) { part in
                    bodyPartChip(part)
                }
            }
        }
    }

    private var exerciseTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("EXERCISE TYPE")

            Text("Determines how sets are logged during workouts.")
                .font(.system(size: 12))
                .foregroundColor(RuutineColor.muted)

            VStack(spacing: 8) {
                ForEach(Self.exerciseTypeOptions) { option in
                    exerciseTypeCard(option)
                }
            }
        }
    }

    private var createButtonBar: some View {
        Button {
            Haptics.impact(.light)
            Task { await create() }
        } label: {
            Group {
                if exerciseService.isSaving {
                    ProgressView()
                        .tint(RuutineColor.accentForeground)
                } else {
                    Text("Create")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(RuutineColor.accentForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canCreate ? RuutineColor.accent : RuutineColor.accent.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(RuutineColor.muted)
            .tracking(1.2)
    }

    private func bodyPartChip(_ part: String) -> some View {
        let isSelected = selectedBodyPart == part

        return Button {
            Haptics.selection()
            if isSelected {
                selectedBodyPart = nil
            } else {
                selectedBodyPart = part
            }
        } label: {
            Text(part)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? RuutineColor.accentForeground : RuutineColor.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? RuutineColor.accent : .clear)
                .overlay(
                    Capsule()
                        .stroke(RuutineColor.accent, lineWidth: 1.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func exerciseTypeCard(_ option: ExerciseTypeOption) -> some View {
        let isSelected = selectedCategory == option.category

        return Button {
            Haptics.selection()
            selectedCategory = option.category
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(RuutineColor.foreground)

                    Text(option.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(RuutineColor.muted)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(RuutineColor.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? RuutineColor.accent.opacity(0.12) : RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? RuutineColor.accent : RuutineColor.border, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func create() async {
        guard let category = selectedCategory else { return }
        guard !trimmedName.isEmpty else { return }

        errorMessage = nil
        let muscleGroup = selectedBodyPart ?? "Other"

        do {
            let exercise = try await exerciseService.createCustomExercise(
                name: trimmedName,
                profileId: profileId,
                muscleGroup: muscleGroup,
                category: category
            )
            SoundFX.add()
            Haptics.impact(.medium)
            onCreated(exercise)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.notify(.error)
        }
    }
}

private extension CreateExerciseSheet {
    static let bodyPartOptions = [
        "Chest", "Back", "Legs", "Shoulders", "Arms",
        "Core", "Glutes", "Cardio", "Full Body", "Other",
    ]

    struct ExerciseTypeOption: Identifiable {
        let category: ExerciseCategory
        let title: String
        let subtitle: String

        var id: String { category.rawValue }
    }

    static let exerciseTypeOptions: [ExerciseTypeOption] = [
        ExerciseTypeOption(category: .barbell, title: "Barbell", subtitle: "Weight & Reps"),
        ExerciseTypeOption(category: .dumbbell, title: "Dumbbell", subtitle: "Weight & Reps"),
        ExerciseTypeOption(category: .machineOther, title: "Machine / Other", subtitle: "Weight & Reps"),
        ExerciseTypeOption(category: .weightedBodyweight, title: "Weighted Bodyweight", subtitle: "Added Weight & Reps"),
        ExerciseTypeOption(category: .assistedBodyweight, title: "Assisted Bodyweight", subtitle: "Assisted Reps"),
        ExerciseTypeOption(category: .repsOnly, title: "Reps Only", subtitle: "Reps"),
        ExerciseTypeOption(category: .cardio, title: "Cardio", subtitle: "Time & Distance"),
        ExerciseTypeOption(category: .duration, title: "Duration", subtitle: "Time"),
    ]
}

#Preview {
    CreateExerciseSheet(
        exerciseService: ExerciseService(),
        profileId: UUID(),
        prefilledName: "Morning Run"
    ) { _ in }
}
