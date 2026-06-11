import Auth
import SwiftUI

struct ProgramView: View {
    @Binding var showAtlasChat: Bool
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel = ProgramViewModel()
    @State private var expandedDays: Set<Int> = []
    @State private var showEditAlert = false
    @State private var showNewProgramAlert = false

    init(showAtlasChat: Binding<Bool> = .constant(false)) {
        _showAtlasChat = showAtlasChat
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
        }
        .task(id: authVM.session?.user.id) {
            guard let userId = authVM.session?.user.id else { return }
            await viewModel.load(userId: userId)
        }
        .alert("Edit Program", isPresented: $showEditAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Program editing is coming soon.")
        }
        .alert("New Program", isPresented: $showNewProgramAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Atlas program generation is coming soon.")
        }
    }

    private var programContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

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
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("MY PROGRAM")
                .font(.bebas(32))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Button {
                showEditAlert = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func dayCard(_ day: ProgramDay) -> some View {
        let isExpanded = expandedDays.contains(day.day)
        let exerciseCount = day.exercises?.count ?? 0

        return VStack(alignment: .leading, spacing: 0) {
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
                        .frame(width: 36, height: 36)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                showEditAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                    Text("Edit Program")
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
            .buttonStyle(.plain)

            Button {
                showNewProgramAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("New Program")
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
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("MY PROGRAM")
                .font(.bebas(32))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Text("No program yet. Chat with Atlas to generate one.")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showAtlasChat = true
            } label: {
                Text("Talk to Atlas")
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
