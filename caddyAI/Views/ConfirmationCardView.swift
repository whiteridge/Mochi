import SwiftUI
import Foundation

struct ConfirmationCardView: View {
    let proposal: ProposalData
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var rotatingLightNamespace: Namespace.ID
    var morphNamespace: Namespace.ID? = nil
    let isExecuting: Bool
    let isFinalAction: Bool
    let appSteps: [AppStep]
    let activeAppId: String?

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.28)
    }

    private var cardShadowLiftColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.18)
    }
    
    @State private var showButtonGlow: Bool = false
    @State private var previousProposalIndex: Int? = nil
    @State private var glowPhase: Double = 0
    @State private var isGlowMotionActive: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            animatedStageSection
            footerSection
        }
        .padding(22)
        .background(glowOverlay)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: cardShadowColor, radius: 24, x: 0, y: 18)
        .shadow(color: cardShadowLiftColor, radius: 8, x: 0, y: 4)
        .frame(maxWidth: 560)
        .onChange(of: isExecuting) { _, newValue in
            if newValue {
                startButtonGlow()
            } else {
                endButtonGlow()
            }
        }
        .onAppear {
            previousProposalIndex = proposal.proposalIndex
            startGlowMotion()
        }
        .onChange(of: proposal.proposalIndex) { _, newValue in
            previousProposalIndex = newValue
            endButtonGlow()
        }
    }
}

// MARK: - Sections

private extension ConfirmationCardView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !appSteps.isEmpty {
                MultiStatusPillView(appSteps: appSteps, activeAppId: activeAppId)
            }
            
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headerActionTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                }
                
                Spacer()
            }
        }
        .overlay(alignment: .topTrailing) {
            cancelButton
                .padding(.top, appSteps.isEmpty ? 0 : 5)
        }
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.iconSecondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(palette.iconBackground)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var stageTransition: AnyTransition {
        guard let previousProposalIndex, previousProposalIndex != proposal.proposalIndex else {
            return .identity
        }

        let isForward = proposal.proposalIndex >= previousProposalIndex
        let insertionEdge: Edge = isForward ? .trailing : .leading
        let removalEdge: Edge = isForward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    var animatedStageSection: some View {
        ZStack {
            ForEach([proposal], id: \.proposalIndex) { proposalItem in
                stageSection(for: proposalItem)
                    .transition(stageTransition)
            }
        }
    }

    @ViewBuilder
    func stageSection(for proposal: ProposalData) -> some View {
        if proposal.isSlackApp {
            SlackStageSection(
                proposal: proposal,
                stageCornerRadius: stageCornerRadius,
                stageMetadataColumns: stageMetadataColumns
            )
        } else if proposal.isCalendarApp {
            CalendarStageSection(
                proposal: proposal,
                stageCornerRadius: stageCornerRadius
            )
        } else if proposal.isGitHubApp {
            GitHubStageSection(
                proposal: proposal,
                stageCornerRadius: stageCornerRadius,
                stageMetadataColumns: stageMetadataColumns
            )
        } else if proposal.isGmailApp {
            GmailStageSection(
                proposal: proposal,
                stageCornerRadius: stageCornerRadius,
                stageMetadataColumns: stageMetadataColumns
            )
        } else if proposal.isNotionApp {
            NotionStageSection(
                proposal: proposal,
                stageCornerRadius: stageCornerRadius,
                stageMetadataColumns: stageMetadataColumns
            )
        } else {
            LinearStageSection(
                proposal: proposal,
                stageCornerRadius: stageCornerRadius,
                stageMetadataColumns: stageMetadataColumns
            )
        }
    }
    
    var footerSection: some View {
        HStack {
            Spacer()
            actionButtonsSection
        }
    }

    private var stageCornerRadius: CGFloat {
        18
    }

    private var stageMetadataColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
    
    // MARK: - Action Buttons Section
    
    @ViewBuilder
    var actionButtonsSection: some View {
        if proposal.isSlackApp {
            SlackActionButtons(
                proposal: proposal,
                isExecuting: isExecuting,
                onConfirm: onConfirm,
                gradientNamespace: rotatingLightNamespace
            )
        } else {
            actionButton
        }
    }
    
    var actionButton: some View {
        return ActionGlowButton(
            title: confirmButtonTitle,
            isExecuting: isExecuting,
            action: {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                onConfirm()
            },
            gradientNamespace: rotatingLightNamespace
        )
    }
    
    @ViewBuilder
    var cardBackground: some View {
        let cardProminence: LiquidGlassProminence = preferences.glassStyle == .clear ? .subtle : .regular
        let background = LiquidGlassSurface(shape: .roundedRect(24), prominence: cardProminence, shadowed: false)
        if let morphNamespace {
            background
                .matchedGeometryEffect(id: "background", in: morphNamespace)
        } else {
            background
        }
    }
    
    var glowOverlay: some View {
        let isGlowActive = isExecuting || showButtonGlow
        return GeometryReader { proxy in
            let size = proxy.size
            let maxRadius = max(size.width, size.height) * 2.0
            let phase = glowPhase * Double.pi * 2
            let driftX = CGFloat(cos(phase)) * 0.035
            let driftY = CGFloat(sin(phase)) * 0.03
            let coneOrigin = UnitPoint(x: 0.5 + driftX, y: 0.5 + driftY)
            let baseIntensity = colorScheme == .dark
                ? (isFinalAction ? 0.22 : 0.18)
                : (isFinalAction ? 0.52 : 0.44)
            let styleBoost = preferences.glassStyle == .regular
                ? (colorScheme == .dark ? 1.35 : 1.18)
                : 1.0
            let glowIntensity = min(baseIntensity * styleBoost, 1.0)
            let baseOpacity = colorScheme == .dark ? 0.55 : 0.9
            let glowOpacity = min(
                baseOpacity + (preferences.glassStyle == .regular ? 0.08 : 0),
                1.0
            )
            let glowBlendMode: BlendMode = colorScheme == .dark
                ? .plusLighter
                : (preferences.glassStyle == .regular ? .plusLighter : .screen)
            let rotationSpeed = isGlowActive ? 1.4 : 0
            let maskGradient = RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.85), location: 0),
                    .init(color: .white.opacity(0.82), location: 0.4),
                    .init(color: .white.opacity(0.8), location: 0.8),
                    .init(color: .white.opacity(0.78), location: 1)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: maxRadius
            )

            RotatingGradientFill(
                shape: .roundedRect(cornerRadius: 24),
                rotationSpeed: rotationSpeed,
                intensity: glowIntensity,
                renderStyle: .cone(origin: coneOrigin)
            )
            .opacity(isGlowActive ? glowOpacity : 0)
            .blendMode(glowBlendMode)
            .mask(
                maskGradient
                    .blur(radius: colorScheme == .dark ? 16 : 12)
            )
            .animation(.easeInOut(duration: 0.45), value: isGlowActive)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Header Helpers

private extension ConfirmationCardView {
    
    var normalizedAppId: String {
        let base = proposal.appId ?? proposal.tool
        return base.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    var headerAppName: String {
        switch normalizedAppId {
        case "linear":
            return "Linear"
        case "slack":
            return "Slack"
        case "notion":
            return "Notion"
        case "gmail", "googlemail":
            return "Gmail"
        case "calendar", "googlecalendar", "google":
            return "Calendar"
        case "github":
            return "GitHub"
        default:
            return proposal.appId ?? "App"
        }
    }

    var headerActionTitle: String {
        let tool = proposal.tool.lowercased()
        if proposal.isSlackApp {
            return isScheduledMessage ? "Schedule message" : "Send message"
        }
        if proposal.isCalendarApp {
            if tool.contains("create") { return "Create event" }
            if tool.contains("update") { return "Update event" }
            if tool.contains("delete") || tool.contains("remove") { return "Cancel event" }
            return "Confirm event"
        }
        if proposal.isGitHubApp {
            if tool.contains("pull_request") || tool.contains("pullrequest") { return "Create pull request" }
            if tool.contains("issue") && tool.contains("create") { return "Create issue" }
            if tool.contains("comment") { return "Add comment" }
            if tool.contains("merge") { return "Merge pull request" }
            if tool.contains("close") && tool.contains("issue") { return "Close issue" }
            if tool.contains("close") && tool.contains("pull") { return "Close pull request" }
            if tool.contains("update") && tool.contains("issue") { return "Update issue" }
            if tool.contains("update") && tool.contains("pull") { return "Update pull request" }
            if tool.contains("create") && (tool.contains("repo") || tool.contains("repository")) { return "Create repository" }
            return "Confirm GitHub action"
        }
        if proposal.isGmailApp {
            if tool.contains("reply") { return "Reply to email" }
            if tool.contains("forward") { return "Forward email" }
            if tool.contains("send") { return "Send email" }
            if tool.contains("draft") { return "Create draft" }
            if tool.contains("label") { return "Apply label" }
            if tool.contains("trash") { return "Move to trash" }
            if tool.contains("delete") { return "Delete email" }
            return "Confirm email"
        }
        if proposal.isNotionApp {
            if tool.contains("create") { return "Create page" }
            if tool.contains("update") || tool.contains("patch") { return "Update page" }
            if tool.contains("archive") { return "Archive page" }
            if tool.contains("restore") { return "Restore page" }
            if tool.contains("delete") { return "Delete page" }
            return "Confirm page"
        }
        if proposal.isLinearApp {
            if tool.contains("create") { return "Create issue" }
            if tool.contains("update") { return "Update issue" }
            return "Confirm issue"
        }
        return "Confirm action"
    }


    
    var isScheduledMessage: Bool {
        proposal.tool.lowercased().contains("schedule")
    }
    
    var confirmButtonTitle: String {
        let tool = proposal.tool.lowercased()
        
        // Slack-specific button titles
        if proposal.isSlackApp {
            if tool.contains("schedule") { return "Schedule message" }
            return "Send"
        }

        if proposal.isCalendarApp {
            if tool.contains("create") || tool.contains("quick_add") || tool.contains("import") { return "Create event" }
            if tool.contains("update") || tool.contains("patch") { return "Update event" }
            if tool.contains("delete") || tool.contains("remove") || tool.contains("clear") { return "Delete event" }
            if tool.contains("move") { return "Move event" }
            return "Confirm event"
        }

        if proposal.isGitHubApp {
            if tool.contains("pull_request") || tool.contains("pullrequest") { return "Create pull request" }
            if tool.contains("issue") && tool.contains("create") { return "Create issue" }
            if tool.contains("comment") { return "Add comment" }
            if tool.contains("merge") { return "Merge pull request" }
            if tool.contains("close") && tool.contains("issue") { return "Close issue" }
            if tool.contains("close") && tool.contains("pull") { return "Close pull request" }
            if tool.contains("update") && tool.contains("issue") { return "Update issue" }
            if tool.contains("update") && tool.contains("pull") { return "Update pull request" }
            if tool.contains("create") && (tool.contains("repo") || tool.contains("repository")) { return "Create repository" }
            return "Confirm GitHub action"
        }

        if proposal.isGmailApp {
            if tool.contains("reply") { return "Send reply" }
            if tool.contains("forward") { return "Forward email" }
            if tool.contains("send") { return "Send email" }
            if tool.contains("draft") { return "Save draft" }
            if tool.contains("label") { return "Apply label" }
            if tool.contains("trash") { return "Move to trash" }
            if tool.contains("delete") { return "Delete email" }
            return "Confirm email"
        }

        if proposal.isNotionApp {
            if tool.contains("create") { return "Create page" }
            if tool.contains("update") || tool.contains("patch") { return "Update page" }
            if tool.contains("archive") { return "Archive page" }
            if tool.contains("restore") { return "Restore page" }
            if tool.contains("delete") { return "Delete page" }
            return "Confirm page"
        }
        
        // Linear-specific button titles
        if tool.contains("create") { return "Create ticket" }
        if tool.contains("update") { return "Update ticket" }
        return "Confirm action"
    }
    
}

// MARK: - Private Helpers

private extension ConfirmationCardView {
    func startButtonGlow() {
        withAnimation(.easeInOut(duration: 0.45)) {
            showButtonGlow = true
        }
    }
    
    func endButtonGlow() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showButtonGlow = false
        }
    }

    func startGlowMotion() {
        guard !isGlowMotionActive else { return }
        isGlowMotionActive = true
        glowPhase = 0
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            glowPhase = 1
        }
    }
}

// MARK: - Extensions

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let value):
            return value.nilIfEmpty
        case .none:
            return nil
        }
    }
}
