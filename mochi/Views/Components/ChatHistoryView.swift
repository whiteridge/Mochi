import SwiftUI

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ChatHistoryView: View {
    @ObservedObject var viewModel: AgentViewModel
    let messages: [ChatMessage]
    let currentStatus: AgentStatus?
    let proposal: ProposalData?
    let typewriterText: String // Progressive text reveal
    let isProcessing: Bool // Hide placeholder during processing
    let onConfirmProposal: () -> Void
    let onCancelProposal: () -> Void
    let rotatingLightNamespace: Namespace.ID
    let animation: Namespace.ID
    
    @State private var shouldAutoScroll = true
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }

    // Helper to determine if a message should be visible when proposal is active
    private func shouldShowMessage(_ message: ChatMessage) -> Bool {
        if proposal != nil {
            // In agentic mode: only show the action summary
            return message.isAttachedToProposal && message.isActionSummary
        }
        return true
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Only use spacer to push content down when NOT in agentic mode
                    if proposal == nil {
                        Spacer(minLength: 0)
                    }
                    
                    // Show all non-hidden messages, but apply visual transforms based on proposal state
                    ForEach(messages.filter { !$0.isHidden }) { message in
                        let isVisible = shouldShowMessage(message)
                        
                        ChatBubbleRow(message: message)
                            .id(message.id)
                            // Push non-visible messages up and fade them out
                            .offset(y: isVisible ? 0 : -100)
                            .opacity(isVisible ? 1 : 0)
                            // Clip height to 0 when hidden so they don't take space
                            .frame(height: isVisible ? nil : 0, alignment: .top)
                            .clipped()
                    }
                    
                    // Typewriter text (progressive reveal)
                    if !typewriterText.isEmpty {
                        HStack {
                            Text(typewriterText)
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .animation(.easeOut(duration: 0.1), value: typewriterText)
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                    
                    // Status Pill / Confirmation Card
                    if viewModel.showStatusPill || proposal != nil {
                        VStack(alignment: .leading, spacing: 0) {
                            if let proposal = proposal {
                                ConfirmationCardView(
                                    proposal: proposal,
                                    onConfirm: onConfirmProposal,
                                    onCancel: onCancelProposal,
                                    rotatingLightNamespace: rotatingLightNamespace,
                                    morphNamespace: animation,
                                    isExecuting: viewModel.isExecutingAction,
                                    isFinalAction: viewModel.proposalQueue.count <= 1,
                                    appSteps: viewModel.appSteps,
                                    activeAppId: proposal.appId ?? viewModel.appSteps.first(where: { $0.state == .active || $0.state == .searching })?.appId
                                )
                                .zIndex(1)
                            } else {
                                // Compute the status to display
                                let pillStatus: StatusPillView.Status = {
                                    if let status = currentStatus {
                                        switch status {
                                        case .thinking: return .thinking
                                        case .searching(let app): return .searching(app: app)
                                        }
                                    } else if let activeStep = viewModel.appSteps.first(where: { $0.state == .searching || $0.state == .active }) {
                                        return .searching(app: activeStep.appId.capitalized)
                                    } else {
                                        return .thinking  // Default fallback
                                    }
                                }()
                                
                                StatusPillView(
                                    status: pillStatus,
                                    isCompact: false,
                                    morphNamespace: animation
                                )
                                .zIndex(2)
                                .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .transition(.opacity)
                    }
                    
                    Color.clear.frame(height: 10).id("bottomAnchor")
                }
                .padding(.horizontal, 20)
                .padding(.top, proposal != nil ? 0 : 24) // No top padding in agentic mode
                .padding(.bottom, 20)
                .animation(.easeInOut(duration: 0.5), value: proposal != nil)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .scrollContentBackground(.hidden)
            .clipped() // Ensure content is clipped at container bounds
            .onScrollGeometryChange(for: Bool.self) { geo in
                // Detect if user is near the bottom to enable/disable auto-scroll
                let distanceFromBottom = geo.contentSize.height - geo.contentOffset.y - geo.containerSize.height
                return distanceFromBottom < 50
            } action: { _, isAtBottom in
                if shouldAutoScroll != isAtBottom {
                    shouldAutoScroll = isAtBottom
                }
            }
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
                if shouldAutoScroll {
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
            .onChange(of: typewriterText) { _, _ in
                if shouldAutoScroll && !typewriterText.isEmpty {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }
}
