import SwiftUI

struct EditableProgramExercise: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: String
    var rest: String
    var notes: String

    init(name: String, sets: Int, reps: String, rest: String, notes: String = "") {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.notes = notes
    }

    init(from exercise: ProgramExercise) {
        self.init(
            name: exercise.name,
            sets: exercise.sets ?? 3,
            reps: exercise.reps ?? "8-10",
            rest: exercise.rest ?? "90s",
            notes: exercise.notes ?? ""
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "sets": sets,
            "reps": reps,
            "rest": rest,
        ]
        if !notes.isEmpty { dict["notes"] = notes }
        return dict
    }
}

struct EditableProgramDay: Identifiable, Equatable {
    var id: Int { day }
    var day: Int
    var name: String
    var exercises: [EditableProgramExercise]

    init(from day: ProgramDay) {
        self.day = day.day
        self.name = day.name
        self.exercises = (day.exercises ?? []).map(EditableProgramExercise.init)
    }

    func toDictionary() -> [String: Any] {
        [
            "day": day,
            "name": name,
            "exercises": exercises.map { $0.toDictionary() },
        ]
    }
}

struct ProgramEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let profileId: UUID
    let programName: String
    let week: Int
    let initialDays: [ProgramDay]
    let onSaved: () -> Void

    @State private var days: [EditableProgramDay]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var atlasPrompt = ""
    @State private var isAtlasEditing = false
    @State private var showAtlasEdit = false

    init(
        profileId: UUID,
        programName: String,
        week: Int,
        days: [ProgramDay],
        onSaved: @escaping () -> Void
    ) {
        self.profileId = profileId
        self.programName = programName
        self.week = week
        self.initialDays = days
        self.onSaved = onSaved
        _days = State(initialValue: days.map(EditableProgramDay.init))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showAtlasEdit = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Edit with Atlas")
                        }
                        .foregroundColor(RuutineColor.accent)
                    }
                }

                ForEach($days) { $day in
                    Section(day.name) {
                        ForEach($day.exercises) { $exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Exercise name", text: $exercise.name)
                                HStack {
                                    Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...10)
                                }
                                TextField("Reps", text: $exercise.reps)
                                TextField("Rest", text: $exercise.rest)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    day.exercises.removeAll { $0.id == exercise.id }
                                } label: {
                                    Text("Delete")
                                }
                            }
                        }
                        Button("Add Exercise") {
                            day.exercises.append(
                                EditableProgramExercise(
                                    name: "New exercise",
                                    sets: 3,
                                    reps: "8-10",
                                    rest: "90s"
                                )
                            )
                        }
                        .foregroundColor(RuutineColor.accent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RuutineColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .ruutineNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT PROGRAM")
                        .font(.bebas(22))
                        .tracking(1)
                }
                ToolbarItem(placement: .topBarLeading) {
                    RuutineNavButton(kind: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    RuutineNavButton(kind: .save, isDisabled: isSaving, isLoading: isSaving) {
                        Task { await saveManual() }
                    }
                }
            }
            .alert("Couldn't Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: errorMessage) { _, error in
                if error != nil { Haptics.notify(.error) }
            }
            .sheet(isPresented: $showAtlasEdit) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Describe the changes you want Atlas to make.")
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)

                        TextField("e.g. Swap squats for leg press", text: $atlasPrompt, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(RuutineColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(RuutineColor.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            Task { await saveWithAtlas() }
                        } label: {
                            Group {
                                if isAtlasEditing {
                                    ProgressView().tint(RuutineColor.accentForeground)
                                } else {
                                    Text("Apply with Atlas")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(RuutineColor.accentForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RuutineColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(atlasPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAtlasEditing)

                        Spacer()
                    }
                    .padding(20)
                    .background(RuutineColor.background)
                    .navigationTitle("Atlas Edit")
                    .navigationBarTitleDisplayMode(.inline)
                    .ruutineNavigationChrome()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            RuutinePillButton(title: "Close", style: .secondary) {
                                showAtlasEdit = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func programContentDictionary() -> [String: Any] {
        [
            "name": programName,
            "week": week,
            "days": days.map { $0.toDictionary() },
        ]
    }

    private func saveManual() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await ProgramService.saveProgram(
                profileId: profileId,
                programContent: programContentDictionary()
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveWithAtlas() async {
        isAtlasEditing = true
        defer { isAtlasEditing = false }
        do {
            let updated = try await ProgramService.editProgramWithAtlas(
                profileId: profileId,
                message: atlasPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                programContent: programContentDictionary()
            )
            if let updatedDays = updated["days"] as? [[String: Any]] {
                days = updatedDays.compactMap { dayDict -> EditableProgramDay? in
                    guard let dayNum = dayDict["day"] as? Int,
                          let name = dayDict["name"] as? String
                    else { return nil }
                    let exercises = (dayDict["exercises"] as? [[String: Any]] ?? []).map { ex -> EditableProgramExercise in
                        EditableProgramExercise(
                            name: ex["name"] as? String ?? "Exercise",
                            sets: ex["sets"] as? Int ?? 3,
                            reps: ex["reps"] as? String ?? "8-10",
                            rest: ex["rest"] as? String ?? "90s",
                            notes: ex["notes"] as? String ?? ""
                        )
                    }
                    return EditableProgramDay(day: dayNum, name: name, exercises: exercises)
                }
            }
            showAtlasEdit = false
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension EditableProgramDay {
    init(day: Int, name: String, exercises: [EditableProgramExercise]) {
        self.day = day
        self.name = name
        self.exercises = exercises
    }
}
