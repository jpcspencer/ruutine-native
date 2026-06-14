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
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
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
                    }
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentOffset.y <= 16
                    } action: { _, nearTop in
                        isScrolledNearTop = nearTop
                        refreshScrollUpHint()
                    }
                    .overlay(alignment: .top) {
                        scrollUpHint(proxy: proxy)
                    }
                    .onChange(of: atlasService.isLoadingHistory) { _, isLoading in
                        guard !isLoading else { return }
                        openAtBottom(proxy: proxy)
                    }
                    .onChange(of: atlasService.messages.count) { _, _ in
                        if !atlasService.isLoadingHistory {
                            scrollToBottom(proxy: proxy, animated: true)
                            refreshScrollUpHint()
                        }
                    }
                    .onChange(of: atlasService.isTyping) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .onAppear {
                        refreshScrollUpHint()
                    }
                }

                inputBar
            }
            .background(RuutineColor.background.ignoresSafeArea())

            if showClearConfirmation {
                clearChatDialog
            }
        }
        .task(id: authVM.session?.user.id) {
            if let userId = authVM.session?.user.id {
                atlasService.setProfileId(userId)
                await atlasService.loadHistory()
            }
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

    private func openAtBottom(proxy: ScrollViewProxy) {
        scrollToBottom(proxy: proxy, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            scrollToBottom(proxy: proxy, animated: false)
            refreshScrollUpHint()
        }
    }

    private var header: some View {
        HStack {
            Text("ATLAS")
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
    }

    private var clearChatDialog: some View {
        ZStack {
            RuutineColor.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    showClearConfirmation = false
                }

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Text("Clear this conversation? This can't be undone.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(RuutineColor.foreground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if let clearErrorMessage {
                        Text(clearErrorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(RuutineColor.destructive)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        Button {
                            showClearConfirmation = false
                        } label: {
                            Text("Keep")
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
                            Task {
                                await confirmClearChat()
                            }
                        } label: {
                            Text("Clear")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(RuutineColor.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RuutineColor.destructive.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(RuutineColor.destructive.opacity(0.85), lineWidth: 1)
                                )
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
        .animation(.easeInOut(duration: 0.2), value: showClearConfirmation)
    }

    private func confirmClearChat() async {
        clearErrorMessage = nil
        do {
            try await atlasService.clearChat()
            showClearConfirmation = false
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
            TextField("Message Atlas…", text: $inputText, axis: .vertical)
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

    private func sendTapped() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Haptics.impact(.light)
        inputText = ""
        Task {
            await atlasService.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            if atlasService.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = atlasService.messages.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            } else {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
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
