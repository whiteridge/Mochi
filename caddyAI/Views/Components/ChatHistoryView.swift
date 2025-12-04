import SwiftUI

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ChatHistoryView: View {
    let messages: [ChatMessage]
    let currentStatus: AgentStatus?
    let proposal: ProposalData?
    let typewriterText: String // Progressive text reveal
    let onConfirmProposal: () -> Void
    let onCancelProposal: () -> Void
    let rotatingLightNamespace: Namespace.ID
    let animation: Namespace.ID
    
    // We need to know the available height to constrain the scroll view, 
    // but the parent handles the frame height logic based on scrollContentHeight.
    // The parent uses ViewHeightKey to get the content height.
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    
                    if messages.isEmpty && typewriterText.isEmpty {
                        Text("How can I help?")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(messages.filter { !$0.isHidden }) { message in
                            ChatBubbleRow(message: message)
                                .id(message.id)
                        }
                    }
                    
                    // Typewriter text (progressive reveal)
                    if !typewriterText.isEmpty {
                        HStack {
                            Text(typewriterText)
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                                .animation(.easeOut(duration: 0.1), value: typewriterText)
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                    
                    if let status = currentStatus {
                        HStack {
                            StatusPillView(text: status.labelText)
                            Spacer()
                        }
                        .padding(.leading, 4) // Align with chat bubbles
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if let proposal = proposal {
                        ConfirmationCardView(
                            proposal: proposal,
                            onConfirm: onConfirmProposal,
                            onCancel: onCancelProposal,
                            rotatingLightNamespace: rotatingLightNamespace
                        )
                        .padding(.top, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Color.clear.frame(height: 10).id("bottomAnchor")
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .scrollContentBackground(.hidden)
            .onChange(of: proposal) { _, newValue in
                if newValue != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }
}


