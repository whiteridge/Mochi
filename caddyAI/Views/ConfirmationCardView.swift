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
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.2)
    }
    
    @State private var showButtonGlow: Bool = false
    @State private var previousProposalIndex: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            animatedStageSection
            footerSection
        }
        .padding(22)
        .background(cardBackground)
        .overlay(glowOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: cardShadowColor, radius: 20, x: 0, y: 14)
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
                    
                    if let summaryText = proposal.summaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !summaryText.isEmpty {
                        Text(summaryText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
            SlackActionButtons(proposal: proposal, isExecuting: isExecuting, onConfirm: onConfirm)
        } else {
            actionButton
        }
    }
    
    var actionButton: some View {
        return ActionGlowButton(title: confirmButtonTitle, isExecuting: isExecuting) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            onConfirm()
        }
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
        Group {
            if !isExecuting {
                RotatingGradientFill(
                    shape: .roundedRect(cornerRadius: 24),
                    rotationSpeed: 6.0,
                    intensity: showButtonGlow ? (isFinalAction ? 0.25 : 0.18) : 0,
                    renderStyle: .cone(origin: UnitPoint(x: 0.85, y: 0.9))
                )
                .matchedGeometryEffect(id: "gradientFill", in: rotatingLightNamespace)
                .opacity(showButtonGlow ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: showButtonGlow)
                .allowsHitTesting(false)
            } else {
                EmptyView()
            }
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
        withAnimation(.easeOut(duration: 0.5)) {
            showButtonGlow = true
        }
    }
    
    func endButtonGlow() {
        withAnimation(.easeOut(duration: 0.35)) {
            showButtonGlow = false
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
