import Auth
import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = OnboardingService()

    @State private var inputText = ""
    @State private var showSignOutConfirm = false
    @State private var showLaterConfirm = false
    @State private var skipError: String?
    @State private var configureError: String?
    @State private var didCelebrateProgramBuilt = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var focusedMeasurementField: MeasurementField?

    let flow: OnboardingFlow
    let onComplete: () -> Void

    init(flow: OnboardingFlow = .onboarding, onComplete: @escaping () -> Void) {
        self.flow = flow
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if flow == .onboarding {
                            messageBubble(
                                AtlasMessage(role: .assistant, content: OnboardingMaps.greeting)
                            )
                            .id("greeting")
                        }

                        ForEach(displayedMessages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if service.isTyping, !showsProgramBuildingLoader {
                            typingIndicator
                                .id("typing")
                        }

                        if showsOnboardingChipRow {
                            chipRow
                                .id("chips")
                        }

                        if service.showsStructuredMeasurements {
                            measurementsInputs
                                .id("measurements")
                        }

                        if showsProgramBuildingLoader {
                            generatingIndicator
                                .id("generating")
                        }

                        if service.step == .programPreview, let program = service.program {
                            programPreview(program)
                                .id("program")
                        }

                        if service.isSaving {
                            savingIndicator
                                .id("saving")
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: service.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy, preferChips: true)
                }
                .onChange(of: service.isTyping) { _, isTyping in
                    scrollToBottom(proxy: proxy, preferChips: !isTyping)
                }
                .onChange(of: showsProgramBuildingLoader) { _, _ in scrollToBottom(proxy: proxy) }
                .onChange(of: service.showsQuickReplyChips) { _, shows in
                    if shows {
                        scrollToBottom(proxy: proxy, preferChips: true)
                    }
                }
                .onChange(of: service.effectiveChipStep) { _, _ in
                    if service.showsQuickReplyChips {
                        scrollToBottom(proxy: proxy, preferChips: true)
                    }
                }
                .onChange(of: service.step) { _, newStep in
                    if newStep == .measurementsAsk || newStep == .measurementsInput {
                        service.prepareMeasurementsStep()
                    }
                    scrollToBottom(proxy: proxy, preferChips: true)
                }
                .onChange(of: focusedMeasurementField) { _, field in
                    if field == nil, service.showsStructuredMeasurements {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }

            if showsProgramPreviewContinue {
                programPreviewContinueBar
            }

            if !service.hidesInputBar {
                inputBar
            }
        }
        .background(RuutineColor.background.ignoresSafeArea())
        .onAppear {
            guard flow == .onboarding, let session = authVM.session else { return }
            service.configure(session: session)
        }
        .task(id: authVM.session?.user.id) {
            guard flow == .programBuild, let session = authVM.session else { return }
            configureError = nil
            do {
                try await service.configureForProgramBuild(session: session)
            } catch {
                configureError = error.localizedDescription
            }
        }
        .task(id: service.messages.last?.id) {
            await service.handleGeneratingHandoffIfNeeded()
        }
        .overlay {
            if service.isSkipping {
                skipLoadingOverlay
            }
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authVM.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Set up later?", isPresented: $showLaterConfirm) {
            Button("Later") {
                Task { await skipTapped() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can build your program with Ruu anytime.")
        }
        .alert("Couldn't Skip Onboarding", isPresented: Binding(
            get: { skipError != nil },
            set: { if !$0 { skipError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(skipError ?? "")
        }
        .alert("Couldn't Start Program Builder", isPresented: Binding(
            get: { configureError != nil },
            set: { if !$0 { configureError = nil; dismiss() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(configureError ?? "")
        }
        .onChange(of: skipError) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
        .onChange(of: configureError) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
        .onChange(of: showsProgramPreviewContinue) { _, isShowing in
            guard isShowing, !didCelebrateProgramBuilt else { return }
            didCelebrateProgramBuilt = true
            SoundFX.onboardingComplete()
            Haptics.notify(.success)
        }
    }

    private var showsProgramBuildingLoader: Bool {
        service.isGenerating || service.step == .generating
    }

    private var showsProgramPreviewContinue: Bool {
        service.step == .programPreview && service.program != nil
    }

    private var onboardingAnswerChips: [String] {
        service.quickReplyChips.filter { $0 != "Skip" }
    }

    private var showsOnboardingSkipChip: Bool {
        service.quickReplyChips.contains("Skip")
    }

    private var showsOnboardingChipRow: Bool {
        !service.isTyping
            && (!onboardingAnswerChips.isEmpty || service.canGoBack || showsOnboardingSkipChip)
    }

    private var hidesLaterButton: Bool {
        switch service.step {
        case .measurementsAsk, .measurementsInput, .generating, .programPreview:
            return true
        default:
            return service.isGenerating
        }
    }

    /// Hide redundant Atlas handoff copy while the themed loader is visible.
    private var displayedMessages: [AtlasMessage] {
        guard showsProgramBuildingLoader else { return service.messages }
        return service.messages.filter {
            $0.role == .user || !OnboardingService.isGeneratingHandoffMessage($0.content)
        }
    }

    private var skipLoadingOverlay: some View {
        ZStack {
            RuutineColor.background.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(RuutineColor.accent)
                Text("Setting up your account...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RuutineColor.foreground)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            if flow == .programBuild {
                Text("RUU")
                    .font(.bebas(28))
                    .foregroundColor(RuutineColor.foreground)
                    .tracking(1)

                Spacer(minLength: 0)

                Button("Close") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .buttonStyle(.plain)
                .disabled(service.isSaving || service.isGenerating)
            } else {
                HStack(spacing: 10) {
                    Button {
                        Haptics.impact(.light)
                        showSignOutConfirm = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(RuutineColor.muted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isSkipping || service.isSaving)

                    Text("RUU")
                        .font(.bebas(28))
                        .foregroundColor(RuutineColor.foreground)
                        .tracking(1)
                }

                Spacer(minLength: 0)

                if !hidesLaterButton {
                    Button("Later") {
                        Haptics.impact(.light)
                        showLaterConfirm = true
                    }
                    .font(.bebas(20))
                    .foregroundColor(RuutineColor.accent)
                    .tracking(0.5)
                    .buttonStyle(.plain)
                    .disabled(service.isSkipping || service.isSaving || service.isGenerating)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RuutineColor.border)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(onboardingAnswerChips, id: \.self) { label in
                Button {
                    Haptics.selection()
                    Task { await service.selectChip(label) }
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(chipForeground(label))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(chipBackground(label))
                        .overlay(
                            Capsule()
                                .stroke(RuutineColor.accent, lineWidth: 1.5)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(service.isTyping || service.isGenerating)
            }

            if service.canGoBack {
                onboardingNavChip(icon: "arrow.uturn.backward") {
                    Haptics.impact(.light)
                    service.goBack()
                }
            }

            if showsOnboardingSkipChip {
                onboardingNavChip(icon: "arrow.uturn.forward") {
                    Haptics.selection()
                    Task { await service.selectChip("Skip") }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func onboardingNavChip(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RuutineColor.muted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RuutineColor.surface.opacity(0.55))
                .overlay(
                    Capsule()
                        .stroke(RuutineColor.border, lineWidth: 1.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(service.isTyping || service.isGenerating)
    }

    private func chipForeground(_ label: String) -> Color {
        if service.effectiveChipStep == .trainingDays,
           let day = OnboardingMaps.dayLabels.first(where: { $0.value == label })?.key,
           service.isTrainingDaySelected(day) {
            return RuutineColor.accentForeground
        }
        return RuutineColor.accent
    }

    private func chipBackground(_ label: String) -> Color {
        if service.effectiveChipStep == .trainingDays,
           let day = OnboardingMaps.dayLabels.first(where: { $0.value == label })?.key,
           service.isTrainingDaySelected(day) {
            return RuutineColor.accent
        }
        return .clear
    }

    private var measurementsInputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Units", selection: $service.measurementsUseImperial) {
                Text("Metric").tag(false)
                Text("Imperial").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: service.measurementsUseImperial) { _, _ in
                Haptics.selection()
                service.syncMeasurementsUnitPreference()
            }

            if service.measurementsUseImperial {
                HStack(spacing: 10) {
                    measurementField("Height (ft)", text: $service.measurementHeightFeet, keyboard: .numberPad, field: .heightFeet)
                    measurementField("Height (in)", text: $service.measurementHeightInches, keyboard: .numberPad, field: .heightInches)
                }
                measurementField("Weight (lbs)", text: $service.measurementWeightLbs, keyboard: .decimalPad, field: .weightLbs)
            } else {
                HStack(spacing: 10) {
                    measurementField("Height (cm)", text: $service.measurementHeightCm, keyboard: .decimalPad, field: .heightCm)
                    measurementField("Weight (kg)", text: $service.measurementWeightKg, keyboard: .decimalPad, field: .weightKg)
                }
            }

            Button {
                Haptics.impact(.light)
                Task { await service.submitMeasurements() }
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RuutineColor.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RuutineColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!service.canSubmitMeasurements || service.isTyping || service.isGenerating)

            Button {
                Haptics.impact(.light)
                Task { await service.skipMeasurements() }
            } label: {
                Text("I'll skip this")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RuutineColor.muted)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(service.isTyping || service.isGenerating)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private func measurementField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        field: MeasurementField
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 15))
            .foregroundColor(RuutineColor.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .focused($focusedMeasurementField, equals: field)
    }

    private var programPreviewContinueBar: some View {
        Button {
            SoundFX.select()
            Haptics.impact(.light)
            Task { await saveAndFinish() }
        } label: {
            Group {
                if service.isSaving {
                    ProgressView()
                        .tint(RuutineColor.accentForeground)
                } else {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(RuutineColor.accentForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RuutineColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(service.isSaving)
        .opacity(service.isSaving ? 0.7 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
    }

    private func programPreview(_ program: OnboardingProgramPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(program.days ?? []) { day in
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(RuutineColor.foreground)

                    ForEach(day.exercises ?? []) { exercise in
                        Text(exerciseLine(exercise))
                            .font(.system(size: 12))
                            .foregroundColor(RuutineColor.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func exerciseLine(_ exercise: OnboardingProgramExercise) -> String {
        var line = exercise.name
        if let sets = exercise.sets, let reps = exercise.reps {
            line += " — \(sets)×\(reps)"
        }
        if let rest = exercise.rest, !rest.isEmpty {
            line += " (rest \(rest))"
        }
        return line
    }

    private func messageBubble(_ message: AtlasMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(RuutineColor.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                        ? RuutineColor.accent.opacity(0.22)
                        : RuutineColor.surface
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            message.role == .user
                                ? RuutineColor.accent.opacity(0.35)
                                : RuutineColor.border,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var typingIndicator: some View {
        HStack {
            OnboardingTypingDotsView()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 48)
        }
    }

    private var generatingIndicator: some View {
        HStack {
            Text("Building your program...")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RuutineColor.surface)
                .overlay {
                    OnboardingGeneratingShimmer()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 48)
        }
    }

    private var savingIndicator: some View {
        HStack {
            Text("Saving your program...")
                .font(.system(size: 14))
                .foregroundColor(RuutineColor.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RuutineColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RuutineColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 48)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(
                inputPlaceholder,
                text: $inputText,
                axis: .vertical
            )
            .font(.system(size: 15))
            .foregroundColor(RuutineColor.foreground)
            .lineLimit(1...4)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RuutineColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(RuutineColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .focused($isInputFocused)
            .onSubmit(sendTapped)

            Button(action: sendTapped) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(RuutineColor.accentForeground)
                    .frame(width: 40, height: 40)
                    .background(RuutineColor.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.45)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RuutineColor.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RuutineColor.border)
                        .frame(height: 1)
                }
        )
    }

    private var inputPlaceholder: String {
        if service.showsStructuredMeasurements {
            return OnboardingMaps.placeholder(for: .measurementsAsk)
        }
        if service.effectiveChipStep != .none {
            return OnboardingMaps.placeholder(for: service.effectiveChipStep)
        }
        return OnboardingMaps.placeholder(for: service.step)
    }

    private var canSend: Bool {
        if service.isTyping || service.isGenerating { return false }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if service.step == .greetingName {
            return trimmed.count >= 2 || trimmed.lowercased() == "skip"
        }
        return !trimmed.isEmpty
    }

    private func dismissKeyboard() {
        isInputFocused = false
        focusedMeasurementField = nil
    }

    private func sendTapped() {
        let text = inputText
        guard canSend else { return }
        Haptics.impact(.light)
        inputText = ""
        Task {
            await service.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, preferChips: Bool = false) {
        let performScroll = {
            withAnimation(.easeOut(duration: 0.2)) {
                if service.isSaving {
                    proxy.scrollTo("saving", anchor: .bottom)
                } else if showsProgramBuildingLoader {
                    proxy.scrollTo("generating", anchor: .bottom)
                } else if service.isTyping {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if service.step == .programPreview {
                    proxy.scrollTo("program", anchor: .bottom)
                } else if service.showsStructuredMeasurements {
                    proxy.scrollTo("measurements", anchor: .bottom)
                } else if preferChips && service.showsQuickReplyChips {
                    proxy.scrollTo("chips", anchor: .bottom)
                } else if let last = service.messages.last?.id {
                    proxy.scrollTo(last, anchor: .bottom)
                } else {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }

        performScroll()

        if preferChips && service.showsQuickReplyChips {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                performScroll()
            }
        }
    }

    private func saveAndFinish() async {
        do {
            try await service.completeOnboarding()
            if flow == .onboarding {
                authVM.markOnboardingComplete()
            }
            onComplete()
            if flow == .programBuild {
                dismiss()
            }
        } catch {
            service.appendErrorMessage(
                flow == .programBuild
                    ? "Couldn't save your program. Please try again. (\(error.localizedDescription))"
                    : "Couldn't save your profile. Please try again. (\(error.localizedDescription))"
            )
        }
    }

    private func skipTapped() async {
        skipError = nil
        do {
            try await service.skipOnboarding()
            authVM.markOnboardingComplete()
            onComplete()
        } catch {
            skipError = error.localizedDescription
        }
    }
}

private enum MeasurementField: Hashable {
    case heightFeet
    case heightInches
    case weightLbs
    case heightCm
    case weightKg
}

private struct OnboardingTypingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(RuutineColor.muted)
                    .frame(width: 7, height: 7)
                    .opacity(animate ? 1 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

/// Simple wrapping chip layout.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(AuthViewModel())
}
