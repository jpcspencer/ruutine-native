import Auth
import Charts
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            Color.ruuBackground.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(.ruuAccent)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.ruuMuted)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        reload()
                    }
                    .foregroundColor(.ruuAccent)
                }
                .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        atlasCard
                        programCard
                        statsRow
                        progressCard
                        musclesCard
                        historyButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .task(id: authVM.session?.user.id) {
            reload()
        }
    }

    private var atlasCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(atlasGreeting)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.ruuForeground)

            Text("Tap to chat with Atlas →")
                .font(.system(size: 12))
                .foregroundColor(.ruuMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruuCard()
    }

    private var atlasGreeting: String {
        if let session = viewModel.todaySession, session.completedToday {
            return "Nice work today. You crushed it."
        }
        if viewModel.totalSessions == 0 {
            return "Ready to start your first workout? Tap to chat with Atlas."
        }
        if viewModel.streak > 0 {
            return "You're on a \(viewModel.streak)-day streak. Keep it going."
        }
        return "What's on the agenda today? Tap to talk to Atlas."
    }

    @ViewBuilder
    private var programCard: some View {
        if let session = viewModel.todaySession {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name.uppercased())
                        .font(.ruuBebas(20))
                        .foregroundColor(.ruuForeground)
                        .tracking(1)
                        .lineLimit(2)

                    Text("\(session.exerciseCount) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(.ruuMuted)
                }
                .padding(16)

                if !session.completedToday {
                    Button {
                        print("Start Session tapped")
                    } label: {
                        Text("Start Session")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.ruuAccentForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.ruuAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(Color.ruuSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ruuBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                Text("Your workout will appear here after you complete your chat with Atlas.")
                    .font(.system(size: 12))
                    .foregroundColor(.ruuMuted)
                    .multilineTextAlignment(.center)
            }
            .ruuCard()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCard(value: "\(viewModel.streak)", label: "Streak")
            statCard(value: "\(viewModel.totalSessions)", label: "Sessions")
            statCard(value: "\(viewModel.volumeDisplay)", label: "Vol (\(viewModel.volumeLabel))")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.ruuForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.ruuMuted)
        }
        .frame(maxWidth: .infinity)
        .ruuCard(padding: 12)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.ruuMuted)

            if viewModel.progressWeeks.isEmpty {
                Text("Complete your first week to see progress")
                    .font(.system(size: 12))
                    .foregroundColor(.ruuMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                Chart(viewModel.progressWeeks.suffix(8)) { week in
                    LineMark(
                        x: .value("Week", week.week),
                        y: .value("Sessions", week.sessions)
                    )
                    .foregroundStyle(Color.ruuAccent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Week", week.week),
                        y: .value("Sessions", week.sessions)
                    )
                    .foregroundStyle(Color.ruuAccent)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(
                                    date,
                                    format: .dateTime.month(.abbreviated)
                                )
                                .font(.system(size: 9))
                                .foregroundStyle(Color.ruuMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.ruuBorder)
                        AxisValueLabel()
                            .foregroundStyle(Color.ruuMuted)
                    }
                }
                .frame(height: 120)
            }
        }
        .ruuCard()
    }

    private var musclesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscles trained this week")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.ruuMuted)

            BodyHeatmapView(trainedMuscles: viewModel.trainedMuscles)
        }
        .ruuCard()
    }

    private var historyButton: some View {
        Button {
            print("View History tapped")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(.ruuMuted)
                Text("View History")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.ruuForeground)
            }
            .frame(maxWidth: .infinity)
        }
        .ruuCard(padding: 14)
    }

    private func reload() {
        guard let userId = authVM.session?.user.id else { return }
        Task {
            await viewModel.load(userId: userId)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
