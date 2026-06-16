import Auth
import SwiftUI

struct AtlasChatView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject var atlasService: AtlasService

    @State private var inputText = ""
    @State private var showClearConfirmation = false
    @State private var clearErrorMessage: String?
    @State private var isScrolledNearTop = false
    @State private var showScrollUpHint = false
    @State private var scrollUpPulse = false
    @State private var didInitialScrollToBottom = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Color.clear
                                .frame(height: 1)
                                .id("chat-top")

                            if atlasService.isLoadingHistory, atlasService.messages.isEmpty {
                                ProgressView()
                                    .tint(RuutineColor.accent)
                                    .padding(.top, 24)
                            }

                            ForEach(atlasService.messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }

                            if atlasService.isTyping {
                                typingIndicator
                                    .id("typing")
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("chat-bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissKeyboard()
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentOffset.y <= 16
                    } action: { _, nearTop in
                        isScrolledNearTop = nearTop
                        refreshScrollUpHint()
                    }
                    .overlay(alignment: .top) {
                        scrollUpHint(proxy: proxy)
                    }
                    .onChange(of: atlasService.messages.count) { oldCount, newCount in
                        guard newCount > oldCount else { return }
                        guard !atlasService.isLoadingHistory else { return }
                        scrollToBottom(proxy: proxy, animated: true)
                        refreshScrollUpHint()
                    }
                    .onChange(of: atlasService.isLoadingHistory) { _, isLoading in
                        guard !isLoading else { return }
                        scrollToBottomOnOpenIfNeeded(proxy: proxy)
                    }
                    .onAppear {
                        scrollToBottomOnOpenIfNeeded(proxy: proxy)
                        refreshScrollUpHint()
                    }
                    .onDisappear {
                        didInitialScrollToBottom = false
                    }
                }

                inputBar
        }
        .background(RuutineColor.background.ignoresSafeArea())
        .task(id: authVM.session?.user.id) {
            if let userId = authVM.session?.user.id {
                atlasService.setProfileId(userId)
                await atlasService.loadHistory()
            }
        }
        .ruutineConfirm(
            isPresented: $showClearConfirmation,
            title: "Clear this conversation?",
            message: "This can't be undone.",
            confirmLabel: "Clear",
            isDestructive: true
        ) {
            Task { await confirmClearChat() }
        }
        .alert("Couldn't Clear Chat", isPresented: Binding(
            get: { clearErrorMessage != nil },
            set: { if !$0 { clearErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(clearErrorMessage ?? "")
        }
        .onChange(of: clearErrorMessage) { _, error in
            if error != nil { Haptics.notify(.error) }
        }
    }

    @ViewBuilder
    private func scrollUpHint(proxy: ScrollViewProxy) -> some View {
        if showScrollUpHint {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("chat-top", anchor: .top)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(RuutineColor.accent)
                    .frame(width: 34, height: 34)
                    .background(RuutineColor.surface.opacity(0.94))
                    .overlay(
                        Circle()
                            .stroke(RuutineColor.border, lineWidth: 1)
                    )
                    .clipShape(Circle())
                    .opacity(scrollUpPulse ? 1 : 0.42)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .accessibilityLabel("Earlier conversation above")
            .onAppear {
                scrollUpPulse = false
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    scrollUpPulse = true
                }
            }
        }
    }

    private func refreshScrollUpHint() {
        showScrollUpHint = atlasService.shouldShowScrollUpHint && !isScrolledNearTop
    }

    private var header: some View {
        HStack {
            Text("RUU")
                .font(.bebas(28))
                .foregroundColor(RuutineColor.foreground)
                .tracking(1)

            Spacer()

            Button {
                showClearConfirmation = true
                clearErrorMessage = nil
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear chat")

            RuutineNavButton(kind: .close) {
                dismiss()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close chat")
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

    private func confirmClearChat() async {
        clearErrorMessage = nil
        do {
            try await atlasService.clearChat()
            isScrolledNearTop = false
            refreshScrollUpHint()
        } catch {
            clearErrorMessage = "Couldn't clear chat. \(error.localizedDescription)"
        }
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
            TypingDotsView()
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
            TextField("Message Ruu…", text: $inputText, axis: .vertical)
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
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || atlasService.isTyping)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || atlasService.isTyping ? 0.45 : 1)
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

    private func dismissKeyboard() {
        isInputFocused = false
    }

    private func sendTapped() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Haptics.impact(.light)
        inputText = ""
        Task {
            await atlasService.sendMessage(text)
        }
    }

    private func scrollToBottomOnOpenIfNeeded(proxy: ScrollViewProxy) {
        guard !didInitialScrollToBottom else { return }
        guard !atlasService.isLoadingHistory else { return }

        didInitialScrollToBottom = true
        DispatchQueue.main.async {
            scrollToBottom(proxy: proxy, animated: false)
            refreshScrollUpHint()
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            proxy.scrollTo("chat-bottom", anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                scroll()
            }
        } else {
            scroll()
        }
    }
}

private struct TypingDotsView: View {
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

#Preview {
    AtlasChatView(atlasService: AtlasService())
        .environmentObject(AuthViewModel())
}
