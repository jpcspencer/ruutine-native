import Auth
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var service = OnboardingService()

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if service.showInitialGreeting {
                            messageBubble(
                                AtlasMessage(role: .assistant, content: OnboardingMaps.greeting)
                            )
                            .id("greeting")
                        }

                        ForEach(service.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if service.showsQuickReplyChips {
                            chipRow
                                .id("chips")
                        }

                        if service.step == .measurementsInput {
                            measurementsInputs
                                .id("measurements")
                        }

                        if service.isTyping {
                            typingIndicator
                                .id("typing")
                        }

                        if service.isGenerating {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: service.messages.count) { _, _ in scrollToBottom(proxy: proxy) }
                .onChange(of: service.isTyping) { _, _ in scrollToBottom(proxy: proxy) }
                .onChange(of: service.isGenerating) { _, _ in scrollToBottom(proxy: proxy) }
                .onChange(of: service.step) { _, _ in scrollToBottom(proxy: proxy) }
            }

            if !service.hidesInputBar {
                inputBar
            }
        }
        .background(RuutineColor.background.ignoresSafeArea())
        .onAppear {
            if let session = authVM.session {
                service.configure(session: session)
            }
        }
        .task(id: service.messages.last?.id) {
            await service.handleGeneratingHandoffIfNeeded()
        }
        .task(id: service.step) {
            if service.step == .programPreview, service.program != nil, !service.isSaving {
                await saveAndFinish()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("ATLAS")
                .font(.bebas(28))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Spacer()

            Text("Onboarding")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(RuutineColor.muted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RuutineColor.border)
                .frame(height: 1)
        }
    }

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(service.quickReplyChips, id: \.self) { label in
                Button {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Height (cm)", text: $service.measurementHeightCm)
                    .keyboardType(.decimalPad)
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

                TextField("Weight (kg)", text: $service.measurementWeightKg)
                    .keyboardType(.decimalPad)
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
            }

            Button {
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
            .disabled(service.isTyping || service.isGenerating)

            Button {
                Task { await service.selectChip("I'll skip this") }
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
            VStack(alignment: .leading, spacing: 8) {
                OnboardingTypingDotsView()
                Text("Building your program...")
                    .font(.system(size: 14))
                    .foregroundColor(RuutineColor.muted)
            }
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
        if service.step == .measurementsAsk || service.step == .measurementsInput {
            return OnboardingMaps.placeholder(for: service.step)
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
        if service.step == .measurementsInput { return true }
        return !trimmed.isEmpty
    }

    private func sendTapped() {
        let text = inputText
        guard canSend else { return }
        inputText = ""
        Task {
            await service.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if service.isSaving {
                proxy.scrollTo("saving", anchor: .bottom)
            } else if service.isGenerating {
                proxy.scrollTo("generating", anchor: .bottom)
            } else if service.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if service.step == .programPreview {
                proxy.scrollTo("program", anchor: .bottom)
            } else if let last = service.messages.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }

    private func saveAndFinish() async {
        do {
            try await service.completeOnboarding()
            authVM.markOnboardingComplete()
            onComplete()
        } catch {
            service.appendErrorMessage(
                "Couldn't save your profile. Please try again. (\(error.localizedDescription))"
            )
        }
    }
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
