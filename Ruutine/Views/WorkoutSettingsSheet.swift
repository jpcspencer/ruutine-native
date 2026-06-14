import PhotosUI
import SwiftUI

struct WorkoutSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var name: String
    @State private var note: String
    @State private var startTime: Date
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var restDurationSeconds: Int

    let onSave: (String, String, Date, Data?, Int) -> Void

    init(
        workoutName: String,
        note: String,
        startedAt: Date,
        photoData: Data?,
        restDurationSeconds: Int,
        onSave: @escaping (String, String, Date, Data?, Int) -> Void
    ) {
        _name = State(initialValue: workoutName)
        _note = State(initialValue: note)
        _startTime = State(initialValue: startedAt)
        _photoData = State(initialValue: photoData)
        _restDurationSeconds = State(initialValue: restDurationSeconds)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldSection(title: "WORKOUT NAME") {
                        TextField("Workout name", text: $name)
                            .font(.system(size: 15))
                            .foregroundColor(RuutineColor.foreground)
                            .padding(14)
                            .background(RuutineColor.surface)
                            .overlay(fieldBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    fieldSection(title: "START TIME") {
                        DatePicker(
                            "Start",
                            selection: $startTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(RuutineColor.accent)
                        .padding(14)
                        .background(RuutineColor.surface)
                        .overlay(fieldBorder)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    fieldSection(title: "END TIME") {
                        Text("Currently Active")
                            .font(.system(size: 15))
                            .foregroundColor(RuutineColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RuutineColor.surface)
                            .overlay(fieldBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    fieldSection(title: "NOTE") {
                        TextField("Add a note…", text: $note, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(RuutineColor.foreground)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(RuutineColor.surface)
                            .overlay(fieldBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    fieldSection(title: "DEFAULT REST") {
                        HStack(spacing: 8) {
                            ForEach(RestDurationPreferences.presets, id: \.self) { seconds in
                                let isSelected = restDurationSeconds == seconds
                                Button {
                                    Haptics.selection()
                                    restDurationSeconds = seconds
                                } label: {
                                    Text(RestDurationPreferences.formatted(seconds))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(isSelected ? RuutineColor.accentForeground : RuutineColor.foreground)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? RuutineColor.accent : RuutineColor.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? RuutineColor.accent : RuutineColor.border, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    fieldSection(title: "WORKOUT PHOTO") {
                        VStack(alignment: .leading, spacing: 12) {
                            if let photoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button("Remove Photo") {
                                    self.photoData = nil
                                    photoItem = nil
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(RuutineColor.destructive)
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text(photoData == nil ? "Choose from Library" : "Replace Photo")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(RuutineColor.accentForeground)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RuutineColor.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .onChange(of: photoItem) { _, item in
                                Task {
                                    guard let item,
                                          let data = try? await item.loadTransferable(type: Data.self),
                                          let image = UIImage(data: data),
                                          let jpeg = image.jpegData(compressionQuality: 0.9)
                                    else { return }
                                    photoData = jpeg
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(RuutineColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .ruutineNavigationChrome()
            .toolbar {
                RuutineToolbarItem(placement: .principal) {
                    Text("WORKOUT SETTINGS")
                        .font(.bebas(22))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                }
                RuutineToolbarItem(placement: .topBarLeading) {
                    RuutineNavButton(kind: .cancel) { dismiss() }
                }
                RuutineToolbarItem(placement: .topBarTrailing) {
                    RuutineNavButton(kind: .confirm(text: "Done")) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            trimmed.isEmpty ? ActiveWorkoutViewModel.defaultWorkoutName() : trimmed,
                            note,
                            startTime,
                            photoData,
                            restDurationSeconds
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(RuutineColor.border, lineWidth: 1)
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .tracking(1)
            content()
        }
    }
}
