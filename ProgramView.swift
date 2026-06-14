import Auth
import SwiftUI

struct ProgramView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var showProgramBuild = false
    var onStartDayWorkout: ((String, [WorkoutExercise]) -> Void)?

    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel = ProgramViewModel()
    @State private var expandedDays: Set<Int> = []
    @State private var showEditProgram = false
    @State private var showReplaceProgramConfirm = false
    @State private var showRenameDialog = false
    @State private var renameInput = ""
    @State private var isSavingName = false
    @State private var isRegenerating = false
    @State private var programError: String?

    init(
        onStartDayWorkout: ((String, [WorkoutExercise]) -> Void)? = nil
    ) {
        self.onStartDayWorkout = onStartDayWorkout
    }

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(RuutineColor.accent)
            } else if viewModel.days.isEmpty {
                emptyState
            } else {
                programContent
            }

            if isRegenerating {
                RuutineColor.scrim.ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(RuutineColor.accent)
                    Text("Building your new program…")
                        .font(.system(size: 15))
                        .foregroundColor(RuutineColor.foreground)
                }
            }

            if showReplaceProgramConfirm {
                replaceProgramDialog
            }

            if showRenameDialog {
                renameProgramDialog
            }
        }
        .task(id: authVM.session?.user.id) {
            guard let userId = authVM.session?.user.id else { return }
            await viewModel.load(userId: userId)
        }
        .sheet(isPresented: $showEditProgram) {
            if let userId = authVM.session?.user.id {
                ProgramEditView(
                    profileId: userId,
                    programName: viewModel.programName,
                    week: viewModel.programWeek,
                    days: viewModel.days
                ) {
                    Task {
                        guard let userId = authVM.session?.user.id else { return }
                        await viewModel.load(userId: userId)
                    }
                }
            }
        }
        .alert("Program Error", isPresented: Binding(
            get: { programError != nil },
            set: { if !$0 { programError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(programError ?? "")
        }
        .fullScreenCover(isPresented: $showProgramBuild) {
            OnboardingView(flow: .programBuild) {
                guard let userId = authVM.session?.user.id else { return }
                Task { await viewModel.load(userId: userId) }
            }
            .environmentObject(authVM)
            .environmentObject(themeManager)
        }
    }

    private var programContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                overviewCard
                    .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    ForEach(viewModel.days, id: \.day) { day in
                        dayCard(day)
                    }
                }
                .padding(.horizontal, 16)

                bottomActions
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .atlasScrollBottomInset()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.displayTitle)
                .font(.bebas(32))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Button {
                renameInput = viewModel.renameFieldValue
                showRenameDialog = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RuutineColor.muted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename program")

            Spacer(minLength: 0)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROGRAM OVERVIEW")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1)

            Text(viewModel.overviewText)
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.foreground)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.overviewFacts, id: \.self) { fact in
                    Text(fact)
                        .font(.system(size: 13))
                        .foregroundColor(RuutineColor.muted)
                }
            }
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

    private func dayCard(_ day: ProgramDay) -> some View {
        let isExpanded = expandedDays.contains(day.day)
        let exerciseCount = day.exercises?.count ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        toggleExpanded(day.day)
                    }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(RuutineColor.foreground)
                                .multilineTextAlignment(.leading)

                            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                                .font(.system(size: 13))
                                .foregroundColor(RuutineColor.muted)
                        }

                        Spacer(minLength: 0)

                        Text(isExpanded ? "−" : "+")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 28, height: 28)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    startDay(day)
                } label: {
                    Text("Start")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(RuutineColor.accentForeground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RuutineColor.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(RuutineColor.border)
                        .padding(.top, 12)

                    if exerciseCount == 0 {
                        Text("No exercises in this day.")
                            .font(.system(size: 13))
                            .foregroundColor(RuutineColor.muted)
                    } else {
                        ForEach(Array((day.exercises ?? []).enumerated()), id: \.offset) { _, exercise in
                            exerciseSubCard(exercise)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isExpanded)
    }

    private func exerciseSubCard(_ exercise: ProgramExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(RuutineColor.foreground)

            Text(exercise.prescriptionLine)
                .font(.system(size: 13))
                .foregroundColor(RuutineColor.muted)

            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RuutineColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                showEditProgram = true
            } label: {
                actionLabel(icon: "pencil", title: "Edit Program")
            }
            .buttonStyle(.plain)

            Button {
                showReplaceProgramConfirm = true
            } label: {
                actionLabel(icon: "sparkles", title: "New Program")
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(RuutineColor.foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(viewModel.displayTitle)
                .font(.bebas(32))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Text("No program yet — generate one.")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showProgramBuild = true
            } label: {
                Text("Generate Program")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RuutineColor.accentForeground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(RuutineColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var renameProgramDialog: some View {
        ZStack {
            RuutineColor.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isSavingName else { return }
                    showRenameDialog = false
                }

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text("RENAME PROGRAM")
                        .font(.bebas(24))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                        .frame(maxWidth: .infinity, alignment: .center)

                    TextField("Program name", text: $renameInput)
                        .font(.system(size: 15))
                        .foregroundColor(RuutineColor.foreground)
                        .padding(14)
                        .background(RuutineColor.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(RuutineColor.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .textInputAutocapitalization(.words)
                        .disabled(isSavingName)

                    Text("Leave blank to reset to your default title.")
                        .font(.system(size: 12))
                        .foregroundColor(RuutineColor.muted)

                    HStack(spacing: 12) {
                        Button {
                            showRenameDialog = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RuutineColor.foreground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RuutineColor.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(RuutineColor.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSavingName)

                        Button {
                            Task { await saveProgramName() }
                        } label: {
                            Group {
                                if isSavingName {
                                    ProgressView().tint(RuutineColor.accentForeground)
                                } else {
                                    Text("Save")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .foregroundColor(RuutineColor.accentForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RuutineColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSavingName)
                    }
                }
                .padding(20)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: showRenameDialog)
    }

    private var replaceProgramDialog: some View {
        ZStack {
            RuutineColor.scrim
                .ignoresSafeArea()
                .onTapGesture { showReplaceProgramConfirm = false }

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Text("This will replace your current program. Continue?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RuutineColor.foreground)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button { showReplaceProgramConfirm = false } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RuutineColor.foreground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RuutineColor.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(RuutineColor.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showReplaceProgramConfirm = false
                            Task { await regenerateProgram() }
                        } label: {
                            Text("Continue")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RuutineColor.accentForeground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RuutineColor.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: showReplaceProgramConfirm)
    }

    private func startDay(_ day: ProgramDay) {
        let exercises = viewModel.exercisesForDay(day)
        guard !exercises.isEmpty else { return }
        onStartDayWorkout?(day.name, exercises)
    }

    private func saveProgramName() async {
        guard let userId = authVM.session?.user.id else { return }
        isSavingName = true
        defer { isSavingName = false }
        do {
            try await viewModel.saveProgramName(renameInput, userId: userId)
            showRenameDialog = false
        } catch {
            programError = error.localizedDescription
        }
    }

    private func regenerateProgram() async {
        guard let userId = authVM.session?.user.id else { return }
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            try await ProgramService.regenerateProgram(profileId: userId)
            await viewModel.load(userId: userId)
        } catch {
            programError = error.localizedDescription
        }
    }

    private func toggleExpanded(_ day: Int) {
        if expandedDays.contains(day) {
            expandedDays.remove(day)
        } else {
            expandedDays.insert(day)
        }
    }
}

#Preview {
    ProgramView()
        .environmentObject(AuthViewModel())
}
