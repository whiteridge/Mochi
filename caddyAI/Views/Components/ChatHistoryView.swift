import SwiftUI

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ChatHistoryView: View {
    let messages: [ChatMessage]
    let isTranscribing: Bool
    let currentStatus: AgentStatus?
    let proposal: ProposalData?
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
                    
                    if messages.isEmpty {
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
                    
                    if isTranscribing {
                        ProcessingIndicatorView(text: "Transcribing...", animation: animation)
                            .id("transcribing")
                    }
                    
                    if let status = currentStatus {
                        HStack {
                            StatusPillView(text: status.labelText)
                            Spacer()
                        }
                        .padding(.leading, 4) // Align with chat bubbles
                        .transition(.opacity)
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

struct ProcessingIndicatorView: View {
    let text: String
    let animation: Namespace.ID
    
    var body: some View {
        HStack(spacing: 12) {
            // Interlocking circles (app icons)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "number")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    )
                    .offset(x: -5)
                
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .matchedGeometryEffect(id: "appIcon", in: animation)
                    )
                    .offset(x: 5)
            }
            .frame(width: 34, height: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
