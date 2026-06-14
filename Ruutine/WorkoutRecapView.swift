import SwiftUI

struct WorkoutRecapView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let data: WorkoutRecapData
    var saveError: String?
    let onDone: () -> Void

    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var atlasService = AtlasService()
    @State private var showAtlasChat = false
    @State private var atlasState: AtlasRecapState = .loading
    @State private var messageVisible = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    if let saveError, !saveError.isEmpty {
                        saveErrorBanner(saveError)
                    }

                    summaryCard
                    if data.note != nil || data.photoData != nil {
                        notePhotoCard
                    }
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
        .task(id: data.id) {
            await loadAtlasMessage()
        }
        .sheet(isPresented: $showAtlasChat) {
            AtlasChatView(atlasService: atlasService)
                .environmentObject(authVM)
        }
        .task(id: data.profileId) {
            atlasService.setProfileId(data.profileId)
            await atlasService.loadHistory()
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

    private func saveErrorBanner(_ message: String) -> some View {
        Text("Couldn't save workout: \(message)")
            .font(.system(size: 13))
            .foregroundColor(RuutineColor.destructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RuutineColor.destructive.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RuutineColor.destructive.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notePhotoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let note = data.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let photoData = data.photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
            Haptics.impact(.light)
            showAtlasChat = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("ATLAS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .tracking(1)

                atlasMessageContent

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

    @ViewBuilder
    private var atlasMessageContent: some View {
        switch atlasState {
        case .loading:
            RecapAtlasShimmer()
                .frame(minHeight: 44)

        case .loaded(let message):
            Text(message)
                .font(.system(size: 14))
                .italic()
                .foregroundColor(RuutineColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(messageVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.35), value: messageVisible)

        case .failed:
            Text("Couldn't load coach note")
                .font(.system(size: 13))
                .foregroundColor(RuutineColor.muted)
        }
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
        Button {
            Haptics.impact(.light)
            onDone()
        } label: {
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

    private func loadAtlasMessage() async {
        atlasState = .loading
        messageVisible = false

        let result = await RecapMessageService.fetchMessage(for: data)

        switch result {
        case .success(let message):
            atlasState = .loaded(message)
            withAnimation(.easeIn(duration: 0.35)) {
                messageVisible = true
            }
        case .failure:
            atlasState = .failed
        }
    }
}

private enum AtlasRecapState: Equatable {
    case loading
    case loaded(String)
    case failed
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
