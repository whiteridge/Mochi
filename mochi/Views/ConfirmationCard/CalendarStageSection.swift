import SwiftUI

private struct CalendarDetailsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CalendarStageSection: View {
    let proposal: ProposalData
    let stageCornerRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var detailsHeight: CGFloat = 0
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var calendarDetails: CalendarProposalDetails {
        CalendarProposalDetails(args: proposal.args)
    }
    
    var body: some View {
        stageContainer {
            VStack(alignment: .leading, spacing: 12) {
                // Action title header
                Text(actionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .tracking(0.3)
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(calendarDetails.title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        calendarScheduleSection
                        calendarAttendeesSection
                        calendarLocationSection
                        calendarDescriptionSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CalendarDetailsHeightKey.self, value: geo.size.height)
                        }
                    )

                    calendarTimelineSection
                }
            }
        }
        .onPreferenceChange(CalendarDetailsHeightKey.self) { detailsHeight = $0 }
    }
    
    // MARK: - Action Title
    
    private var actionTitle: String {
        let tool = proposal.tool.lowercased()
        
        if tool.contains("create") || tool.contains("quick_add") || tool.contains("import") {
            return "Creating Event"
        }
        if tool.contains("update") || tool.contains("patch") {
            return "Updating Event"
        }
        if tool.contains("delete") || tool.contains("remove") || tool.contains("clear") {
            return "Deleting Event"
        }
        if tool.contains("move") {
            return "Moving Event"
        }
        return "Creating Event"
    }
    
    // MARK: - Stage Container
    
    @ViewBuilder
    private func stageContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
    }

    @ViewBuilder
    private func calendarFieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let boxOpacity = preferences.glassStyle == .regular ? 0.6 : 0.8
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LiquidGlassSurface(shape: .roundedRect(12), prominence: .subtle, shadowed: false)
                .opacity(boxOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.subtleBorder.opacity(0.5), lineWidth: 0.6)
        )
    }
    
    // MARK: - Calendar Detail Sections

    @ViewBuilder
    var calendarScheduleSection: some View {
        calendarFieldContainer {
            Text("Schedule")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)

            Text(calendarDateTimeLine)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.primaryText)

            if let hint = calendarDetails.hintText {
                Text(hint)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    @ViewBuilder
    var calendarAttendeesSection: some View {
        calendarFieldContainer {
            Text("People")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)

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
        calendarFieldContainer {
            Text("Location")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)

            if let location = calendarDetails.locationDisplay {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.primary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(2)

                        if let secondary = location.secondary {
                            Text(secondary)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("Add location or conferencing")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
    }

    @ViewBuilder
    var calendarDescriptionSection: some View {
        calendarFieldContainer {
            Text("Notes")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)

            if let description = calendarDetails.descriptionText {
                ScrollableTextArea(maxHeight: 120, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Add description...")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .padding(.bottom, notesBottomPadding)
    }

    var calendarTimelineSection: some View {
        let boxOpacity = preferences.glassStyle == .regular ? 0.6 : 0.8
        return CalendarTimelineView(
            startDate: calendarDetails.startDate,
            endDate: calendarDetails.endDate,
            timeZone: calendarDetails.timeZone,
            title: calendarDetails.title,
            isAllDay: calendarDetails.isAllDay
        )
        .padding(8)
        .frame(width: 170, height: timelineTargetHeight)
        .background(
            LiquidGlassSurface(shape: .roundedRect(14), prominence: .subtle, shadowed: false)
                .opacity(boxOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.subtleBorder.opacity(0.5), lineWidth: 0.6)
        )
    }
    
    // MARK: - Calendar Display Helpers

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

    func calendarAttendeeColor(index _: Int) -> Color {
        palette.iconSecondary.opacity(0.75)
    }
    
    private var notesBottomPadding: CGFloat {
        guard let description = calendarDetails.descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else { return 0 }
        if description.contains("\n") || description.count > 90 {
            return 6
        }
        return 0
    }
    
    private var timelineTargetHeight: CGFloat {
        let minHeight: CGFloat = 160
        return max(detailsHeight, minHeight)
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
}
