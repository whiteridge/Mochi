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

    @Environment(\.colorScheme) private var colorScheme
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.2)
    }
    
    @State private var showButtonGlow: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if proposal.isCalendarApp {
                calendarHeaderSection
            } else {
                headerSection
            }
            
            // Dynamic content based on app type
            if proposal.isSlackApp {
                slackContentSection
            } else if proposal.isCalendarApp {
                calendarContentSection
            } else {
                linearContentSection
            }
            
            actionButtonsSection
        }
        .padding(22)
        .background(cardBackground)
        .overlay(glowOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: cardShadowColor, radius: 20, x: 0, y: 14)
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let summaryText = proposal.summaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(palette.secondaryText)
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

    var calendarHeaderSection: some View {
        HStack(alignment: .center, spacing: 12) {
            ToolBadgeView(iconName: "calendar", displayName: "Calendar")

            Spacer()

            Text(calendarHeaderDateText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)

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
    
    // MARK: - Slack Content Section
    
    @ViewBuilder
    var slackContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Message preview - the main content for Slack
            if let messageText = proposal.messageText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !messageText.isEmpty {
                Text(messageText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
                .background(palette.divider)
                .padding(.vertical, 2)
            
            // Channel/recipient display
            if let channel = slackChannelDisplay {
                HStack(spacing: 8) {
                    Text("Send to")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(palette.tertiaryText)
                    
                    Text(channel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                }
            }
        }
    }
    
    // MARK: - Linear Content Section
    
    @ViewBuilder
    var linearContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title
            Text(titleDisplay)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Description (if present)
            if let description = proposal.description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Only show metadata section if there are populated fields
            if hasAnyLinearMetadata {
                Divider()
                    .background(palette.divider)
                    .padding(.vertical, 2)
                
                linearMetadataSection
            }
        }
    }

    // MARK: - Calendar Content Section

    @ViewBuilder
    var calendarContentSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calendarDetails.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(calendarDateTimeLine)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(palette.secondaryText)

                    if let hint = calendarDetails.hintText {
                        Text(hint)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.tertiaryText)
                    }
                }

                Divider()
                    .background(palette.divider)
                    .padding(.vertical, 2)

                calendarAttendeesSection

                Divider()
                    .background(palette.divider)
                    .padding(.vertical, 2)

                calendarLocationSection

                Divider()
                    .background(palette.divider)
                    .padding(.vertical, 2)

                calendarDescriptionSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(palette.divider)
                .frame(width: 1)
                .padding(.vertical, 6)

            calendarTimelineSection
        }
    }
    
    // MARK: - Linear Metadata Section
    
    var hasAnyLinearMetadata: Bool {
        hasValidTeam || hasValidProject || hasValidStatus || hasValidPriority || hasValidAssignee
    }
    
    var hasValidTeam: Bool {
        hasValidValue(teamDisplay, excluding: ["Select", "Select Team"])
    }
    
    var hasValidProject: Bool {
        hasValidValue(projectDisplay, excluding: ["None"])
    }
    
    var hasValidStatus: Bool {
        // Show status if it's not the default "Todo"
        hasValidValue(statusDisplay, excluding: ["Todo"])
    }
    
    var hasValidPriority: Bool {
        hasValidValue(priorityDisplay, excluding: ["No Priority"])
    }
    
    var hasValidAssignee: Bool {
        hasValidValue(assigneeDisplay, excluding: ["Unassigned"])
    }
    
    @ViewBuilder
    var linearMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First row: Team & Project (only if at least one exists)
            if hasValidTeam || hasValidProject {
                HStack(spacing: 16) {
                    if hasValidTeam {
                        MetadataField(title: "Team", value: teamDisplay)
                    }
                    if hasValidProject {
                        MetadataField(title: "Project", value: projectDisplay)
                    }
                }
            }
            
            // Second row: Status, Priority, Assignee (only show populated ones)
            let secondRowFields = [
                hasValidStatus ? ("Status", statusDisplay) : nil,
                hasValidPriority ? ("Priority", priorityDisplay) : nil,
                hasValidAssignee ? ("Assignee", assigneeDisplay) : nil
            ].compactMap { $0 }
            
            if !secondRowFields.isEmpty {
                HStack(spacing: 16) {
                    ForEach(secondRowFields, id: \.0) { title, value in
                        MetadataField(title: title, value: value)
                    }
                }
            }
        }
    }
    
    // Helper to check if a field has a valid, non-placeholder value
    func hasValidValue(_ value: String, excluding defaults: [String] = []) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !defaults.contains(trimmed)
    }

    // MARK: - Calendar Detail Sections

    @ViewBuilder
    var calendarAttendeesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if calendarDetails.attendees.isEmpty {
                Text("Add participant")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.tertiaryText)
            } else {
                ForEach(Array(calendarDetails.attendees.enumerated()), id: \.element.id) { index, attendee in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(calendarAttendeeColor(index: index))
                            .frame(width: 8, height: 8)

                        Text(attendee.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)

                        Spacer(minLength: 6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var calendarLocationSection: some View {
        if let location = calendarDetails.locationDisplay {
            VStack(alignment: .leading, spacing: 6) {
                Text(location.primary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)

                if let secondary = location.secondary {
                    Text(secondary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.tertiaryText)
                        .lineLimit(1)
                }
            }
        } else {
            Text("Add location or conferencing")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(palette.tertiaryText)
        }
    }

    @ViewBuilder
    var calendarDescriptionSection: some View {
        if let description = calendarDetails.descriptionText {
            Text(description)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)
        } else {
            Text("Add description...")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(palette.tertiaryText)
        }
    }

    var calendarTimelineSection: some View {
        CalendarTimelineView(
            startDate: calendarDetails.startDate,
            endDate: calendarDetails.endDate,
            timeZone: calendarDetails.timeZone,
            title: calendarDetails.title,
            isAllDay: calendarDetails.isAllDay
        )
        .frame(width: 170)
    }
    
    // MARK: - Action Buttons Section
    
    @ViewBuilder
    var actionButtonsSection: some View {
        if proposal.isSlackApp {
            slackActionButtons
        } else {
            actionButton
        }
    }
    
    var slackActionButtons: some View {
        HStack(spacing: 12) {
            // Primary "Send" button
            Button {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                onConfirm()
            } label: {
                Text("Send")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(
                        RotatingLightBackground(
                            cornerRadius: 24,
                            shape: RotatingLightBackground.ShapeType.capsule,
                            rotationSpeed: 10.0,
                            glowColor: .green
                        )
                        .matchedGeometryEffect(id: "rotatingLight", in: rotatingLightNamespace)
                    )
            }
            .buttonStyle(.plain)
            
            // Secondary "Schedule message" button (only for scheduled message tool)
            if isScheduledMessage {
                Button {
                    // Schedule action - same as confirm for scheduled messages
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    onConfirm()
                } label: {
                    Text("Schedule message")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.primaryText)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(
                            LiquidGlassSurface(shape: .capsule, prominence: .subtle, shadowed: false)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var isScheduledMessage: Bool {
        proposal.tool.lowercased().contains("schedule")
    }
    
    var actionButton: some View {
        return Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            onConfirm()
        } label: {
            Text(confirmButtonTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .frame(height: 48)
                .background(
                    // Rotating light background that will morph via matchedGeometryEffect
                    RotatingLightBackground(
                        cornerRadius: 24,
                        shape: RotatingLightBackground.ShapeType.capsule,
                        rotationSpeed: 10.0,
                        glowColor: .green
                    )
                    .matchedGeometryEffect(id: "rotatingLight", in: rotatingLightNamespace)
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var cardBackground: some View {
        let background = LiquidGlassSurface(shape: .roundedRect(24), prominence: .strong, shadowed: false)
        if let morphNamespace {
            background
                .matchedGeometryEffect(id: "background", in: morphNamespace)
        } else {
            background
        }
    }
    
    var glowOverlay: some View {
        // Use the new RotatingGradientFill - gradient rotates inside a fixed clipped shape
        // This avoids the "square rotating" artifact from the old rotationEffect approach
        RotatingGradientFill(
            shape: .roundedRect(cornerRadius: 24),
            rotationSpeed: 8.0,
            intensity: showButtonGlow ? (isFinalAction ? 0.18 : 0.14) : 0
        )
        .matchedGeometryEffect(id: "gradientFill", in: rotatingLightNamespace)
        .opacity(showButtonGlow ? 1 : 0)
        .animation(.easeOut(duration: 0.5), value: showButtonGlow)
        .allowsHitTesting(false)
    }
}

// MARK: - Display Helpers

private extension ConfirmationCardView {
    
    // MARK: - Linear Display Helpers
    
    var titleDisplay: String {
        proposal.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled Issue"
    }
    
    var priorityDisplay: String {
        // First check for enriched priorityName from backend
        if let priorityName = (proposal.args["priorityName"] as? String)?.nilIfEmpty {
            return priorityName
        }
        return proposal.priority?.nilIfEmpty ?? "No Priority"
    }
    
    var statusDisplay: String {
        let stateName = proposal.args["stateName"] as? String
        if let name = stateName?.nilIfEmpty {
            return name
        }
        if let statusArg = (proposal.args["status"] as? String)?.nilIfEmpty {
            return statusArg
        }
        if let statusValue = proposal.status?.nilIfEmpty {
            if isUUID(statusValue) {
                return "Todo"
            }
            return statusValue
        }
        return "Todo"
    }
    
    var assigneeDisplay: String {
        // First check for enriched assignee name from backend
        if let name = (proposal.args["assigneeName"] as? String)?.nilIfEmpty {
            return name
        }
        // Fall back to assigneeId, but show user-friendly message if it's a UUID
        if let assigneeId = proposal.assigneeId?.nilIfEmpty {
            if isUUID(assigneeId) {
                return "Unassigned"
            }
            return assigneeId
        }
        return "Unassigned"
    }
    
    var teamDisplay: String {
        // First check for enriched team name from backend
        if let name = (proposal.args["teamName"] as? String)?.nilIfEmpty {
            return name
        }
        // Fall back to teamId, but show user-friendly message if it's a UUID
        if let teamId = proposal.teamId?.nilIfEmpty {
            if isUUID(teamId) {
                return "Select Team"
            }
            return teamId
        }
        return "Select"
    }
    
    var projectDisplay: String {
        // First check for enriched project name from backend
        if let name = (proposal.args["projectName"] as? String)?.nilIfEmpty {
            return name
        }
        // Fall back to projectId, but show user-friendly message if it's a UUID
        if let projectId = proposal.projectId?.nilIfEmpty {
            if isUUID(projectId) {
                return "None"
            }
            return projectId
        }
        return "None"
    }
    
    // MARK: - Slack Display Helpers
    
    var slackChannelDisplay: String? {
        // Prefer enriched channelName from backend
        if let channelName = proposal.channel?.nilIfEmpty {
            // Ensure it has # prefix for channels
            let name = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.hasPrefix("#") || name.hasPrefix("@") {
                return name
            }
            // If it's a channel ID (starts with C), just show generic text
            if name.hasPrefix("C") && name.count > 8 {
                return nil // Will be resolved by backend enrichment
            }
            return "#\(name)"
        }
        
        // Check for user target (DM)
        if let userName = proposal.userName?.nilIfEmpty {
            if userName.hasPrefix("@") {
                return userName
            }
            // If it's a user ID (starts with U), skip
            if userName.hasPrefix("U") && userName.count > 8 {
                return nil
            }
            return "@\(userName)"
        }
        
        return nil
    }

    // MARK: - Calendar Display Helpers

    var calendarDetails: CalendarProposalDetails {
        CalendarProposalDetails(args: proposal.args)
    }

    var calendarHeaderDateText: String {
        guard let startDate = calendarDetails.startDate else {
            return "Date TBD"
        }
        return calendarFormattedDate(startDate, formatter: Self.calendarHeaderDateFormatter)
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

    func calendarAttendeeColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(nsColor: .systemBlue).opacity(0.75),
            Color(nsColor: .systemOrange).opacity(0.75),
            Color(nsColor: .systemGreen).opacity(0.75),
            Color(nsColor: .systemPink).opacity(0.75)
        ]
        return colors[index % colors.count]
    }

    private func calendarFormattedDate(_ date: Date, formatter: DateFormatter) -> String {
        formatter.timeZone = calendarDetails.timeZone ?? TimeZone.current
        return formatter.string(from: date)
    }

    private func calendarWithTimeZone() -> Calendar {
        var calendar = Calendar.current
        if let timeZone = calendarDetails.timeZone {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    private static let calendarHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter
    }()

    private static let calendarFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let calendarTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let calendarDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Shared Helpers
    
    // Helper function to detect UUID format
    private func isUUID(_ string: String) -> Bool {
        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (8-4-4-4-12 hex digits)
        let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
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
}

// MARK: - Calendar Helpers

private struct CalendarAttendee: Identifiable {
    let id = UUID()
    let name: String
    let isOrganizer: Bool

    var displayName: String {
        if isOrganizer {
            return "\(name) (Organizer)"
        }
        return name
    }
}

private struct CalendarLocationDisplay {
    let primary: String
    let secondary: String?
}

private struct CalendarProposalDetails {
    let title: String
    let startDate: Date?
    let endDate: Date?
    let timeZone: TimeZone?
    let isAllDay: Bool
    let attendees: [CalendarAttendee]
    let locationDisplay: CalendarLocationDisplay?
    let descriptionText: String?
    let hintText: String?

    init(args: [String: Any]) {
        let rawTitle = Self.stringValue(args["summary"])
            ?? Self.stringValue(args["title"])
            ?? Self.stringValue(args["event_title"])
            ?? Self.stringValue(args["name"])

        title = rawTitle?.nilIfEmpty ?? "Untitled Event"

        let startInfo = Self.extractDate(from: args, keys: [
            "start",
            "start_datetime",
            "start_date_time",
            "start_time",
            "startDateTime",
            "startDate",
            "date",
            "day"
        ])
        let endInfo = Self.extractDate(from: args, keys: [
            "end",
            "end_datetime",
            "end_date_time",
            "end_time",
            "endDateTime",
            "endDate",
            "end_date",
            "end_day"
        ])

        var resolvedStart = startInfo.date
        var resolvedEnd = endInfo.date

        if resolvedEnd == nil, let durationMinutes = Self.extractDurationMinutes(from: args), let start = resolvedStart {
            resolvedEnd = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start)
        }

        startDate = resolvedStart
        endDate = resolvedEnd

        let allDayFlag = (args["all_day"] as? Bool) ?? (args["is_all_day"] as? Bool) ?? false
        isAllDay = allDayFlag || startInfo.isAllDay || endInfo.isAllDay

        timeZone = Self.extractTimeZone(from: args, startInfo: startInfo, endInfo: endInfo)

        let organizerName = Self.extractOrganizerName(from: args)
        attendees = Self.extractAttendees(from: args, organizerName: organizerName)

        descriptionText = (Self.stringValue(args["description"])
            ?? Self.stringValue(args["notes"])
            ?? Self.stringValue(args["body"])
            ?? Self.stringValue(args["details"]))?.nilIfEmpty

        let location = Self.stringValue(args["location"])
            ?? Self.stringValue(args["place"])
            ?? Self.stringValue(args["where"])
        let conferenceLink = Self.extractConferenceLink(from: args)
        locationDisplay = Self.buildLocationDisplay(location: location, conferenceLink: conferenceLink)

        if let calendarName = Self.extractCalendarName(from: args) {
            hintText = calendarName
        } else {
            hintText = nil
        }
    }

    private static func extractCalendarName(from args: [String: Any]) -> String? {
        let raw = stringValue(args["calendar_name"])
            ?? stringValue(args["calendarName"])
            ?? stringValue(args["calendar_id"])
            ?? stringValue(args["calendarId"])

        guard let trimmed = raw?.nilIfEmpty else { return nil }
        if trimmed.lowercased() == "primary" {
            return "Calendar: Primary"
        }
        return "Calendar: \(trimmed)"
    }

    private static func extractDurationMinutes(from args: [String: Any]) -> Int? {
        let raw = args["duration_minutes"]
            ?? args["durationMinutes"]
            ?? args["duration"]
            ?? args["length_minutes"]
            ?? args["length"]
        if let intValue = raw as? Int {
            return intValue > 600 ? max(intValue / 60, 1) : intValue
        }
        if let doubleValue = raw as? Double {
            let rounded = Int(doubleValue)
            return rounded > 600 ? max(rounded / 60, 1) : rounded
        }
        if let stringValue = raw as? String, let intValue = Int(stringValue) {
            return intValue > 600 ? max(intValue / 60, 1) : intValue
        }
        return nil
    }

    private static func extractTimeZone(from args: [String: Any], startInfo: DateInfo, endInfo: DateInfo) -> TimeZone? {
        let raw = stringValue(args["timeZone"])
            ?? stringValue(args["timezone"])
            ?? stringValue(args["time_zone"])
            ?? stringValue(args["tz"])

        if let raw, let tz = TimeZone(identifier: raw) {
            return tz
        }

        if let tz = startInfo.timeZone { return tz }
        if let tz = endInfo.timeZone { return tz }
        return nil
    }

    private static func extractOrganizerName(from args: [String: Any]) -> String? {
        if let organizer = args["organizer"] as? [String: Any] {
            return (stringValue(organizer["displayName"])
                ?? stringValue(organizer["name"])
                ?? stringValue(organizer["email"]))?.nilIfEmpty
        }
        return (stringValue(args["organizer"])
            ?? stringValue(args["organizer_name"])
            ?? stringValue(args["organizerName"]))?.nilIfEmpty
    }

    private static func extractAttendees(from args: [String: Any], organizerName: String?) -> [CalendarAttendee] {
        var attendees: [CalendarAttendee] = []

        if let attendeeList = args["attendees"] as? [[String: Any]] {
            for attendee in attendeeList {
                guard let rawName = stringValue(attendee["displayName"])
                        ?? stringValue(attendee["name"])
                        ?? stringValue(attendee["email"])
                        ?? stringValue(attendee["id"]),
                      let name = rawName.nilIfEmpty else {
                    continue
                }
                let isOrganizer = (attendee["organizer"] as? Bool) ?? false
                attendees.append(CalendarAttendee(name: name, isOrganizer: isOrganizer))
            }
        } else if let attendeeList = args["attendees"] as? [String] {
            attendees = attendeeList.compactMap { $0.nilIfEmpty }.map { CalendarAttendee(name: $0, isOrganizer: false) }
        } else if let attendeeList = args["attendee_emails"] as? [String] {
            attendees = attendeeList.compactMap { $0.nilIfEmpty }.map { CalendarAttendee(name: $0, isOrganizer: false) }
        } else if let attendeeList = args["participants"] as? [String] {
            attendees = attendeeList.compactMap { $0.nilIfEmpty }.map { CalendarAttendee(name: $0, isOrganizer: false) }
        } else if let attendeeName = stringValue(args["attendee"])
                    ?? stringValue(args["attendee_email"]),
                  let trimmed = attendeeName.nilIfEmpty {
            attendees = [CalendarAttendee(name: trimmed, isOrganizer: false)]
        }

        if let organizerName {
            if attendees.contains(where: { $0.name == organizerName }) {
                attendees = attendees.map {
                    if $0.name == organizerName {
                        return CalendarAttendee(name: $0.name, isOrganizer: true)
                    }
                    return $0
                }
            } else {
                attendees.insert(CalendarAttendee(name: organizerName, isOrganizer: true), at: 0)
            }
        }

        var seen: Set<String> = []
        attendees = attendees.filter { attendee in
            guard !seen.contains(attendee.name) else { return false }
            seen.insert(attendee.name)
            return true
        }

        return attendees
    }

    private static func extractConferenceLink(from args: [String: Any]) -> String? {
        let direct = stringValue(args["conferenceLink"])
            ?? stringValue(args["conference_link"])
            ?? stringValue(args["meeting_link"])
            ?? stringValue(args["meetingLink"])
            ?? stringValue(args["hangoutLink"])
        if let direct = direct?.nilIfEmpty { return direct }

        if let conferenceData = args["conferenceData"] as? [String: Any],
           let link = extractConferenceLink(from: conferenceData) {
            return link
        }
        if let conferenceData = args["conference_data"] as? [String: Any],
           let link = extractConferenceLink(from: conferenceData) {
            return link
        }
        return nil
    }

    private static func extractConferenceLink(from data: [String: Any]) -> String? {
        if let entryPoints = data["entryPoints"] as? [[String: Any]] {
            for entry in entryPoints {
                if let uri = stringValue(entry["uri"])?.nilIfEmpty {
                    return uri
                }
                if let label = stringValue(entry["label"])?.nilIfEmpty {
                    return label
                }
            }
        }
        return stringValue(data["uri"]) ?? stringValue(data["url"])
    }

    private static func buildLocationDisplay(location: String?, conferenceLink: String?) -> CalendarLocationDisplay? {
        let trimmedLocation = location?.nilIfEmpty
        let trimmedLink = conferenceLink?.nilIfEmpty

        guard trimmedLocation != nil || trimmedLink != nil else { return nil }

        if let link = trimmedLink {
            let primary = shortLinkDisplay(link)
            if let location = trimmedLocation, location != primary {
                return CalendarLocationDisplay(primary: primary, secondary: location)
            }
            return CalendarLocationDisplay(primary: primary, secondary: "Video conferencing")
        }

        if let location = trimmedLocation {
            return CalendarLocationDisplay(primary: location, secondary: "Location")
        }

        return nil
    }

    private static func shortLinkDisplay(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let host = url.host {
            return host
        }
        return trimmed
    }

    private struct DateInfo {
        let date: Date?
        let isAllDay: Bool
        let timeZone: TimeZone?
    }

    private static func extractDate(from args: [String: Any], keys: [String]) -> DateInfo {
        for key in keys {
            guard let rawValue = args[key] else { continue }
            let info = parseDateValue(rawValue)
            if info.date != nil {
                return info
            }
        }
        return DateInfo(date: nil, isAllDay: false, timeZone: nil)
    }

    private static func parseDateValue(_ value: Any) -> DateInfo {
        if let date = value as? Date {
            return DateInfo(date: date, isAllDay: false, timeZone: nil)
        }

        if let timestamp = value as? TimeInterval {
            return DateInfo(date: dateFromTimestamp(timestamp), isAllDay: false, timeZone: nil)
        }

        if let timestamp = value as? Int {
            return DateInfo(date: dateFromTimestamp(Double(timestamp)), isAllDay: false, timeZone: nil)
        }

        if let string = value as? String {
            let info = parseDateString(string)
            return DateInfo(date: info.date, isAllDay: info.isAllDay, timeZone: info.timeZone)
        }

        if let dict = value as? [String: Any] {
            let timeZone = extractTimeZoneFromDatePayload(dict)
            if let dateTime = stringValue(dict["dateTime"])
                ?? stringValue(dict["date_time"])
                ?? stringValue(dict["start"])
                ?? stringValue(dict["end"]) {
                let info = parseDateString(dateTime)
                return DateInfo(date: info.date, isAllDay: info.isAllDay, timeZone: timeZone ?? info.timeZone)
            }
            if let dateOnly = stringValue(dict["date"]) ?? stringValue(dict["day"]) {
                let info = parseDateString(dateOnly, treatAsAllDay: true)
                return DateInfo(date: info.date, isAllDay: true, timeZone: timeZone ?? info.timeZone)
            }
        }

        return DateInfo(date: nil, isAllDay: false, timeZone: nil)
    }

    private static func dateFromTimestamp(_ value: TimeInterval) -> Date {
        if value > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: value / 1000)
        }
        return Date(timeIntervalSince1970: value)
    }

    private static func parseDateString(_ string: String, treatAsAllDay: Bool? = nil) -> (date: Date?, isAllDay: Bool, timeZone: TimeZone?) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, false, nil) }

        let isAllDay = treatAsAllDay ?? !trimmed.contains("T")

        if !isAllDay {
            if let date = isoFormatterWithFractional.date(from: trimmed) {
                return (date, false, nil)
            }
            if let date = isoFormatter.date(from: trimmed) {
                return (date, false, nil)
            }
        }

        if let date = dateOnlyFormatter.date(from: trimmed) {
            return (date, true, nil)
        }

        if let date = dateTimeFormatter.date(from: trimmed) {
            return (date, false, nil)
        }

        if let date = dateTimeTFormatter.date(from: trimmed) {
            return (date, false, nil)
        }

        if let date = dateTimeShortFormatter.date(from: trimmed) {
            return (date, false, nil)
        }

        if let date = dateTimeTShortFormatter.date(from: trimmed) {
            return (date, false, nil)
        }

        return (nil, false, nil)
    }

    private static func extractTimeZoneFromDatePayload(_ dict: [String: Any]) -> TimeZone? {
        let raw = stringValue(dict["timeZone"])
            ?? stringValue(dict["timezone"])
            ?? stringValue(dict["time_zone"])
        if let raw, let tz = TimeZone(identifier: raw) {
            return tz
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let dateTimeShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let dateTimeTFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let dateTimeTShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()
}

private struct CalendarTimelineView: View {
    let startDate: Date?
    let endDate: Date?
    let timeZone: TimeZone?
    let title: String
    let isAllDay: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }

    private let rowHeight: CGFloat = 40
    private let rowSpacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            if isAllDay {
                allDayPill
            }

            ForEach(Array(timelineSlots.enumerated()), id: \.element.id) { index, slot in
                HStack(alignment: .center, spacing: 10) {
                    Text(slot.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(width: 40, alignment: .trailing)

                    timelineBlock(for: slot, placeholderIndex: index)
                }
                .frame(height: rowHeight)
            }
        }
    }

    private var allDayPill: some View {
        Text("All day")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LiquidGlassSurface(shape: .capsule, prominence: .subtle, shadowed: false)
            )
            .overlay(
                Capsule()
                    .stroke(palette.subtleBorder.opacity(0.6), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private func timelineBlock(for slot: TimelineSlot, placeholderIndex: Int) -> some View {
        let showPlaceholder = !slot.isEvent && placeholderIndex.isMultiple(of: 2)
        let fill = palette.iconBackground.opacity(slot.isEvent ? 0.9 : (showPlaceholder ? 0.25 : 0.12))

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.subtleBorder.opacity(slot.isEvent ? 0.6 : 0.25), lineWidth: 0.5)
                )

            if slot.isEvent {
                Rectangle()
                    .fill(Color(nsColor: .systemBlue).opacity(0.85))
                    .frame(width: 3)
                    .cornerRadius(2)
                    .padding(.leading, 6)

                VStack(alignment: .leading, spacing: 2) {
                    if slot.isPrimaryEvent {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(2)
                    }

                    Text("busy")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var timelineSlots: [TimelineSlot] {
        let baseDate = startDate ?? Date()
        let calendar = timelineCalendar
        let startHour = calendar.component(.hour, from: baseDate)
        var rangeStart = max(startHour - 1, 0)
        rangeStart = min(rangeStart, 20)

        return (0..<4).map { offset in
            let hour = rangeStart + offset
            let label = hourLabel(for: hour, baseDate: baseDate)
            let isEvent = eventIntersects(hour: hour, baseDate: baseDate)
            let isPrimaryEvent = isEvent && hour == startHour
            return TimelineSlot(hour: hour, label: label, isEvent: isEvent, isPrimaryEvent: isPrimaryEvent)
        }
    }

    private func eventIntersects(hour: Int, baseDate: Date) -> Bool {
        guard !isAllDay else { return false }
        guard let startDate = startDate else { return false }
        let endDate = resolvedEndDate ?? startDate

        guard let hourStart = timelineCalendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate),
              let hourEnd = timelineCalendar.date(byAdding: .hour, value: 1, to: hourStart) else {
            return false
        }
        return startDate < hourEnd && endDate > hourStart
    }

    private var resolvedEndDate: Date? {
        if let endDate { return endDate }
        guard let startDate else { return nil }
        return timelineCalendar.date(byAdding: .minute, value: 30, to: startDate)
    }

    private func hourLabel(for hour: Int, baseDate: Date) -> String {
        guard let labelDate = timelineCalendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) else {
            return ""
        }
        let formatter = Self.hourFormatter
        formatter.timeZone = timeZone ?? TimeZone.current
        return formatter.string(from: labelDate)
    }

    private var timelineCalendar: Calendar {
        var calendar = Calendar.current
        if let timeZone {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    private struct TimelineSlot: Identifiable {
        let id = UUID()
        let hour: Int
        let label: String
        let isEvent: Bool
        let isPrimaryEvent: Bool
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("ha")
        return formatter
    }()
}

// MARK: - Metadata Field

private struct MetadataField: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.tertiaryText)
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LiquidGlassSurface(shape: .roundedRect(14), prominence: .subtle, shadowed: false)
            )
        }
        .frame(maxWidth: .infinity)
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
