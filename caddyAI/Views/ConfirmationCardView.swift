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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            stageSection
            footerSection
        }
        .padding(22)
        .background(cardBackground)
        .overlay(glowOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: cardShadowColor, radius: 20, x: 0, y: 14)
        .frame(maxWidth: 560)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: isExecuting) { _, newValue in
            if newValue {
                startButtonGlow()
            } else {
                endButtonGlow()
            }
        }
        .onChange(of: proposal.proposalIndex) { _, _ in
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
                headerIcon
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(headerAppName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.tertiaryText)
                    
                    Text(headerActionTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let target = headerTargetText?.nilIfEmpty {
                        Text(target)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let summaryText = proposal.summaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !summaryText.isEmpty {
                        Text(summaryText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
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
        }
    }
    
    @ViewBuilder
    var stageSection: some View {
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
        // Use cone style - gradient emanates from bottom-left where action button is
        RotatingGradientFill(
            shape: .roundedRect(cornerRadius: 24),
            rotationSpeed: 6.0,
            intensity: showButtonGlow ? (isFinalAction ? 0.25 : 0.18) : 0,
            renderStyle: .cone(origin: UnitPoint(x: 0.15, y: 0.9))  // Bottom-left near action button
        )
        .matchedGeometryEffect(id: "gradientFill", in: rotatingLightNamespace)
        .opacity(showButtonGlow ? 1 : 0)
        .animation(.easeOut(duration: 0.5), value: showButtonGlow)
        .allowsHitTesting(false)
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

    var headerCustomIconName: String? {
        switch normalizedAppId {
        case "linear":
            return "linear-icon"
        case "slack":
            return "slack-icon"
        case "notion":
            return "notion-icon"
        case "gmail", "googlemail":
            return "gmail-icon"
        case "calendar", "googlecalendar", "google":
            return "calendar-icon"
        case "github":
            return "github-icon"
        default:
            return nil
        }
    }

    var headerSymbolName: String {
        switch normalizedAppId {
        case "slack":
            return "bubble.left.and.bubble.right.fill"
        case "calendar", "googlecalendar", "google":
            return "calendar"
        case "gmail", "googlemail":
            return "envelope"
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "linear":
            return "rectangle.grid.1x2"
        default:
            return "sparkles"
        }
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
        if proposal.isLinearApp {
            if tool.contains("create") { return "Create issue" }
            if tool.contains("update") { return "Update issue" }
            return "Confirm issue"
        }
        return "Confirm action"
    }

    var headerTargetText: String? {
        if proposal.isSlackApp {
            return slackChannelDisplay ?? slackRecipientDisplay
        }
        if proposal.isCalendarApp {
            return calendarDateTimeLine
        }
        if proposal.isLinearApp {
            if hasValidProject { return projectDisplay }
            if hasValidTeam { return teamDisplay }
        }
        return nil
    }

    var headerIcon: some View {
        ZStack {
            Circle()
                .fill(palette.iconBackground)
                .frame(width: 36, height: 36)
            
            Group {
                if let customIcon = headerCustomIconName {
                    Image(customIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                } else {
                    Image(systemName: headerSymbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.iconPrimary)
                }
            }
        }
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
        
        // Linear-specific button titles
        if tool.contains("create") { return "Create ticket" }
        if tool.contains("update") { return "Update ticket" }
        return "Confirm action"
    }
    
    // MARK: - Slack Display Helpers (for header)
    
    var slackChannelDisplay: String? {
        if let channelName = proposal.channel?.nilIfEmpty {
            let name = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.hasPrefix("#") || name.hasPrefix("@") {
                return name
            }
            if name.hasPrefix("C") && name.count > 8 {
                return nil
            }
            return "#\(name)"
        }
        return nil
    }

    var slackRecipientDisplay: String? {
        guard let userName = proposal.userName?.nilIfEmpty else { return nil }
        if userName.hasPrefix("@") {
            return userName
        }
        if userName.hasPrefix("U") && userName.count > 8 {
            return nil
        }
        return "@\(userName)"
    }
    
    // MARK: - Linear Display Helpers (for header)
    
    var hasValidTeam: Bool {
        hasValidValue(teamDisplay, excluding: ["Select", "Select Team"])
    }
    
    var hasValidProject: Bool {
        hasValidValue(projectDisplay, excluding: ["None"])
    }
    
    var teamDisplay: String {
        if let name = (proposal.args["teamName"] as? String)?.nilIfEmpty {
            return name
        }
        if let teamId = proposal.teamId?.nilIfEmpty {
            if isUUID(teamId) {
                return "Select Team"
            }
            return teamId
        }
        return "Select"
    }
    
    var projectDisplay: String {
        if let name = (proposal.args["projectName"] as? String)?.nilIfEmpty {
            return name
        }
        if let projectId = proposal.projectId?.nilIfEmpty {
            if isUUID(projectId) {
                return "None"
            }
            return projectId
        }
        return "None"
    }
    
    func hasValidValue(_ value: String, excluding defaults: [String] = []) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !defaults.contains(trimmed)
    }
    
    func isUUID(_ string: String) -> Bool {
        let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }
    
    // MARK: - Calendar Display Helpers (for header)
    
    var calendarDetails: CalendarProposalDetails {
        CalendarProposalDetails(args: proposal.args)
    }

    var calendarDateTimeLine: String {
        guard let startDate = calendarDetails.startDate else {
            return "Date TBD"
        }

        let calendar = calendarWithTimeZone()
        let dateText = calendarFormattedDate(startDate, formatter: Self.calendarFullDateFormatter)

        if calendarDetails.isAllDay {
            return "\(dateText) All day"
        }

        guard let endDate = calendarDetails.endDate else {
            let timeText = calendarFormattedDate(startDate, formatter: Self.calendarTimeFormatter)
            return "\(dateText) \(timeText)"
        }

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            let startTime = calendarFormattedDate(startDate, formatter: Self.calendarTimeFormatter)
            let endTime = calendarFormattedDate(endDate, formatter: Self.calendarTimeFormatter)
            return "\(dateText) \(startTime) - \(endTime)"
        }

        let startText = calendarFormattedDate(startDate, formatter: Self.calendarDateTimeFormatter)
        let endText = calendarFormattedDate(endDate, formatter: Self.calendarDateTimeFormatter)
        return "\(startText) - \(endText)"
    }

    func calendarFormattedDate(_ date: Date, formatter: DateFormatter) -> String {
        formatter.timeZone = calendarDetails.timeZone ?? TimeZone.current
        return formatter.string(from: date)
    }

    func calendarWithTimeZone() -> Calendar {
        var calendar = Calendar.current
        if let timeZone = calendarDetails.timeZone {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    static let calendarFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let calendarTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let calendarDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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
