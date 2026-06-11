import SwiftUI

struct WorkoutRecapView: View {
    let data: WorkoutRecapData
    let onDone: () -> Void

    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var atlasService = AtlasService()
    @State private var showAtlasChat = false
    @State private var atlasMessage = "..."

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    exercisesCard
                    atlasCard
                    musclesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            doneButton
        }
        .background(RuutineColor.background.ignoresSafeArea())
        .task {
            await fetchAtlasMessage()
        }
        .sheet(isPresented: $showAtlasChat) {
            AtlasChatView(atlasService: atlasService)
                .environmentObject(authVM)
        }
        .onAppear {
            atlasService.configure(profileId: data.profileId)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(RuutineColor.muted.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            ZStack {
                Text(data.sessionName.uppercased())
                    .font(.bebas(28))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 48)

                HStack {
                    Spacer()
                    Button {
                        // Settings placeholder
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            Text("\(data.sessionName.uppercased()) — COMPLETE")
                .font(.bebas(22))
                .foregroundColor(RuutineColor.foreground)
                .multilineTextAlignment(.center)

            HStack(spacing: 0) {
                recapStat(label: "TIME", value: data.durationFormatted)
                recapStat(label: "SETS", value: "\(data.totalSets)")
                recapStat(label: "VOLUME", value: data.volumeFormatted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RuutineColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RuutineColor.accent.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recapStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(RuutineColor.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXERCISES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1)

            ForEach(data.exercises) { exercise in
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(RuutineColor.foreground)

                    Text(exercise.sets.map { set in
                        "Set \(set.setNumber): \(formatWeight(set.weightKg)) kg × \(set.reps) reps"
                    }.joined(separator: "  "))
                    .font(.system(size: 13))
                    .foregroundColor(RuutineColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var atlasCard: some View {
        Button {
            showAtlasChat = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("ATLAS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .tracking(1)

                Text(atlasMessage)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundColor(RuutineColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tap to chat with Atlas →")
                    .font(.system(size: 12))
                    .foregroundColor(RuutineColor.muted)
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
        .buttonStyle(.plain)
    }

    private var musclesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLES TRAINED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1)

            MuscleMapView(trainedMuscles: data.trainedMuscles)
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

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(RuutineColor.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RuutineColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func fetchAtlasMessage() async {
        guard let url = URL(string: "https://ruutine.app/api/sessions/recap-message") else {
            atlasMessage = fallbackMessage
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "profileId": data.profileId.uuidString,
            "sessionName": data.sessionName,
            "totalTimeSeconds": data.durationSeconds,
            "totalSets": data.totalSets,
            "totalVolumeKg": data.totalVolumeKg,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                atlasMessage = fallbackMessage
                return
            }

            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let message = json["message"] as? String,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                atlasMessage = message
            } else {
                atlasMessage = fallbackMessage
            }
        } catch {
            atlasMessage = fallbackMessage
        }
    }

    private var fallbackMessage: String {
        "Great work today. Keep showing up."
    }
}

#Preview {
    WorkoutRecapView(
        data: WorkoutRecapData(
            id: UUID(),
            sessionName: "June 6 Workout",
            durationSeconds: 3725,
            totalSets: 12,
            totalVolumeKg: 4250,
            exercises: [
                RecapExercise(
                    name: "Bench Press",
                    primaryMuscle: "Chest",
                    sets: [
                        RecapSet(setNumber: 1, weightKg: 60, reps: 10),
                        RecapSet(setNumber: 2, weightKg: 65, reps: 8),
                    ]
                ),
            ],
            profileId: UUID()
        ),
        onDone: {}
    )
    .environmentObject(AuthViewModel())
}
