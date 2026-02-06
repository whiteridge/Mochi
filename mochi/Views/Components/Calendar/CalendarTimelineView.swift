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

    private let labelWidth: CGFloat = 40
    private let columnSpacing: CGFloat = 10
    private let rowInset: CGFloat = 6
    private let minRowHeight: CGFloat = 28
    private let minEventHeight: CGFloat = 20
    private let slotCount: Int = 4

    var body: some View {
        GeometryReader { proxy in
            let layout = timelineLayout(for: proxy.size)
            if isAllDay {
                allDayPill
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                timelineGrid(layout: layout)
            }
        }
    }

    private func timelineGrid(layout: TimelineLayout) -> some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(layout.slots) { slot in
                    Text(slot.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(height: layout.rowHeight)
                        .frame(width: labelWidth, alignment: .trailing)
                }
            }

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(Array(layout.slots.enumerated()), id: \.element.id) { index, _ in
                        placeholderBlock(index: index, rowHeight: layout.rowHeight)
                    }
                }

                if let eventFrame = layout.eventFrame {
                    eventBlock(height: eventFrame.height)
                        .offset(y: eventFrame.offsetY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var allDayPill: some View {
        let boxOpacity = preferences.glassStyle == .regular ? 0.6 : 0.8
        return Text("All day")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LiquidGlassSurface(shape: .capsule, prominence: .subtle, shadowed: false)
                    .opacity(boxOpacity)
            )
            .overlay(
                Capsule()
                    .stroke(palette.subtleBorder.opacity(0.5), lineWidth: 0.6)
            )
    }

    private func placeholderBlock(index: Int, rowHeight: CGFloat) -> some View {
        let showPlaceholder = index.isMultiple(of: 2)
        let fill = colorScheme == .dark
            ? palette.iconBackground.opacity(showPlaceholder ? 0.25 : 0.12)
            : Color.black.opacity(showPlaceholder ? 0.08 : 0.04)
        let inset = min(rowInset, rowHeight * 0.3)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.subtleBorder.opacity(0.4), lineWidth: 0.5)
                )
                .padding(.vertical, inset)
        }
        .frame(height: max(rowHeight, 1))
    }

    private func eventBlock(height: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.iconBackground.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.subtleBorder.opacity(0.6), lineWidth: 0.5)
                )

            Rectangle()
                .fill(Color(nsColor: .systemBlue).opacity(0.85))
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)

                Text("busy")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: max(height, 1))
    }

    private func timelineLayout(for size: CGSize) -> TimelineLayout {
        let baseDate = startDate ?? Date()
        let range = timelineRange(baseDate: baseDate)
        let rowHeight = max(size.height / CGFloat(range.slotCount), minRowHeight)
        let eventFrame = eventFrame(rangeStart: range.startDate, rowHeight: rowHeight, slotCount: range.slotCount)
        return TimelineLayout(slots: range.slots, rowHeight: rowHeight, eventFrame: eventFrame)
    }

    private func timelineRange(baseDate: Date) -> TimelineRange {
        let calendar = timelineCalendar
        let startHour = calendar.component(.hour, from: baseDate)
        let resolvedEnd = resolvedEndDate ?? baseDate
        let endHour = calendar.component(.hour, from: resolvedEnd)
        let endMinute = calendar.component(.minute, from: resolvedEnd)
        let endHourCeil = min(endHour + (endMinute > 0 ? 1 : 0), 24)

        var rangeStart = max(startHour - 1, 0)
        if rangeStart + slotCount < endHourCeil {
            rangeStart = max(endHourCeil - slotCount, 0)
        }
        if rangeStart + slotCount > 24 {
            rangeStart = max(24 - slotCount, 0)
        }

        let startDate = calendar.date(bySettingHour: rangeStart, minute: 0, second: 0, of: baseDate) ?? baseDate
        let slots = (0..<slotCount).map { offset in
            let slotDate = calendar.date(byAdding: .hour, value: offset, to: startDate) ?? startDate
            return TimelineSlot(label: hourLabel(for: slotDate))
        }

        return TimelineRange(startDate: startDate, slots: slots, slotCount: slotCount)
    }

    private func eventFrame(rangeStart: Date, rowHeight: CGFloat, slotCount: Int) -> EventFrame? {
        guard !isAllDay, let startDate else { return nil }
        let endDate = resolvedEndDate ?? startDate
        let rangeMinutes = Double(slotCount * 60)
        let startMinutes = clampMinutes(minutesBetween(rangeStart, startDate), max: rangeMinutes)
        let endMinutes = clampMinutes(minutesBetween(rangeStart, endDate), max: rangeMinutes)

        guard endMinutes > startMinutes else { return nil }

        let offsetY = CGFloat(startMinutes / 60.0) * rowHeight
        var height = CGFloat((endMinutes - startMinutes) / 60.0) * rowHeight
        height = max(height, minEventHeight)

        let maxHeight = rowHeight * CGFloat(slotCount) - offsetY
        return EventFrame(offsetY: offsetY, height: min(height, maxHeight))
    }

    private func clampMinutes(_ minutes: Double, max maxMinutes: Double) -> Double {
        min(max(minutes, 0), maxMinutes)
    }

    private func minutesBetween(_ start: Date, _ end: Date) -> Double {
        end.timeIntervalSince(start) / 60.0
    }

    private var resolvedEndDate: Date? {
        if let endDate { return endDate }
        guard let startDate else { return nil }
        return timelineCalendar.date(byAdding: .minute, value: 30, to: startDate)
    }

    private func hourLabel(for date: Date) -> String {
        let formatter = Self.hourFormatter
        formatter.timeZone = timeZone ?? TimeZone.current
        return formatter.string(from: date)
    }

    private var timelineCalendar: Calendar {
        var calendar = Calendar.current
        if let timeZone {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    private struct TimelineLayout {
        let slots: [TimelineSlot]
        let rowHeight: CGFloat
        let eventFrame: EventFrame?
    }

    private struct TimelineRange {
        let startDate: Date
        let slots: [TimelineSlot]
        let slotCount: Int
    }

    private struct TimelineSlot: Identifiable {
        let id = UUID()
        let label: String
    }

    private struct EventFrame {
        let offsetY: CGFloat
        let height: CGFloat
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("ha")
        return formatter
    }()
}
