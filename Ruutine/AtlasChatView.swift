import Auth
import SwiftUI

struct AtlasChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject var atlasService: AtlasService

    @State private var inputText = ""
    @State private var showClearConfirmation = false
    @State private var clearErrorMessage: String?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: atlasService.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: atlasService.isTyping) { _, _ in
                        scrollToBottom(proxy: proxy)
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

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(RuutineColor.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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
            Color.black.opacity(0.65)
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
                            .foregroundColor(.red)
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
        inputText = ""
        Task {
            await atlasService.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if atlasService.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = atlasService.messages.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            }
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
