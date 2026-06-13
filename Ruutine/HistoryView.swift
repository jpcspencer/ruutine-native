import Auth
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showCalendar = false
    @State private var selectedSession: HistorySessionItem?
    @State private var sessionToDelete: HistorySessionItem?

    var body: some View {
        ZStack {
            RuutineColor.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(RuutineColor.accent)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.muted)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        reload()
                    }
                    .foregroundColor(RuutineColor.accent)
                }
                .padding(24)
            } else if viewModel.monthGroups.isEmpty {
                VStack(spacing: 12) {
                    Text("No sessions yet.")
                        .font(.system(size: 14))
                        .foregroundColor(RuutineColor.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(viewModel.monthGroups) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(RuutineColor.muted)
                                    .tracking(1.2)

                                ForEach(group.sessions) { session in
                                    sessionCard(session)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Home")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(RuutineColor.foreground)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("SESSION HISTORY")
                    .font(.bebas(28))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(RuutineColor.muted)
                }
            }
        }
        .task(id: authVM.session?.user.id) {
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutCompleted)) { _ in
            reload()
        }
        .sheet(isPresented: $showCalendar) {
            WorkoutCalendarView(workoutDays: viewModel.workoutDays)
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                logs: viewModel.logs(for: session.id),
                isImperial: viewModel.isImperial,
                onSave: { updates in
                    try await viewModel.saveExerciseLogs(updates, sessionId: session.id)
                    reload()
                }
            )
            .environmentObject(themeManager)
        }
        .alert("Delete Session?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task {
                        try? await viewModel.deleteSession(session.id)
                        reload()
                    }
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func sessionCard(_ session: HistorySessionItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.sessionName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(RuutineColor.foreground)
                            .multilineTextAlignment(.leading)

                        Text(HistoryFormatting.sessionDate(session.date))
                            .font(.system(size: 13))
                            .foregroundColor(RuutineColor.muted)
                    }

                    Spacer()

                    Button {
                        sessionToDelete = session
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }

                Text(HistoryFormatting.volumeLabel(session.volume, isImperial: viewModel.isImperial))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RuutineColor.foreground)

                Rectangle()
                    .fill(RuutineColor.border)
                    .frame(height: 1)

                HStack {
                    Text("Exercise")
                        .font(.system(size: 11))
                        .foregroundColor(RuutineColor.muted)
                    Spacer()
                    Text("Best Set")
                        .font(.system(size: 11))
                        .foregroundColor(RuutineColor.muted)
                }

                let visibleExercises = Array(session.exercises.prefix(4))
                ForEach(visibleExercises, id: \.self) { exercise in
                    HStack(alignment: .top) {
                        Text(exercise)
                            .font(.system(size: 13))
                            .foregroundColor(RuutineColor.foreground)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(HistoryFormatting.bestSetLabel(session.bestSets[exercise], isImperial: viewModel.isImperial))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(RuutineColor.foreground)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if session.exercises.count > 4 {
                    Text("+ \(session.exercises.count - 4) more")
                        .font(.system(size: 12))
                        .foregroundColor(RuutineColor.muted)
                }
        }
        .padding(16)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            selectedSession = session
        }
    }

    private func reload() {
        guard let userId = authVM.session?.user.id else { return }
        Task {
            await viewModel.load(userId: userId)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject(AuthViewModel())
    }
}
