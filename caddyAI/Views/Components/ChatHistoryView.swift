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
    
    @Namespace private var statusPillAnimation
    @State private var shouldAutoScroll = true
    
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
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                                .animation(.easeOut(duration: 0.1), value: typewriterText)
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                    
                    // Status Pills - use showStatusPill flag to control visibility independently
                    // This keeps the pill mounted so text can animate smoothly
                    if viewModel.showStatusPill || proposal != nil || viewModel.appSteps.count > 1 {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                // Use MultiStatusPillView when multiple apps are tracked
                                if viewModel.appSteps.count > 1 {
                                    MultiStatusPillView(
                                        appSteps: viewModel.appSteps,
                                        activeAppId: proposal?.appId ?? currentStatus?.appName?.lowercased()
                                    )
                                    .zIndex(2)
                                } else {
                                    // Single app - use StatusPillView
                                    // Compute the status to display
                                    let pillStatus: StatusPillView.Status = {
                                        if let status = currentStatus {
                                            switch status {
                                            case .thinking: return .thinking
                                            case .transcribing: return .transcribing
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
                                        isCompact: proposal != nil
                                    )
                                    // NO .id() - keep stable view identity for smooth animations
                                    .background(
                                        Group {
                                            if proposal != nil {
                                                RotatingLightBackground(
                                                    cornerRadius: 20,
                                                    shape: .capsule,
                                                    rotationSpeed: 5.0,
                                                    glowColor: .green
                                                )
                                                .padding(-1)
                                                .transition(.opacity)
                                            }
                                        }
                                    )
                                    .zIndex(2)
                                }
                                
                                Spacer()
                            }
                            
                            // Confirmation Card with directional transitions
                            if let proposal = proposal {
                                ConfirmationCardView(
                                    proposal: proposal,
                                    onConfirm: onConfirmProposal,
                                    onCancel: onCancelProposal,
                                    rotatingLightNamespace: rotatingLightNamespace,
                                    isExecuting: viewModel.isExecutingAction,
                                    isFinalAction: viewModel.proposalQueue.count - viewModel.currentProposalIndex <= 1
                                )
                                .id("\(proposal.appId ?? proposal.tool)-\(proposal.proposalIndex)")  // Force view recreation on proposal change
                                .padding(.top, 14)
                                .zIndex(1)
                                // Asymmetric transition: slide out left, slide in from right
                                .transition(.asymmetric(
                                    insertion: viewModel.cardTransitionDirection == .bottom 
                                        ? .move(edge: .bottom).combined(with: .opacity)
                                        : .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.leading, 4)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
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