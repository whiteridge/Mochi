import SwiftUI

struct CalendarTimelineView: View {
    let startDate: Date?
    let endDate: Date?
    let timeZone: TimeZone?
    let title: String
    let isAllDay: Bool

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
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
