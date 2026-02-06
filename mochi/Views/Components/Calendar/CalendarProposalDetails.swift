import SwiftUI
import Foundation

// MARK: - Calendar Attendee

struct CalendarAttendee: Identifiable {
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

// MARK: - Calendar Location Display

struct CalendarLocationDisplay {
    let primary: String
    let secondary: String?
}

// MARK: - Calendar Proposal Details

struct CalendarProposalDetails {
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

        let resolvedStart = startInfo.date
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
           let link = extractConferenceLinkFromPayload(conferenceData) {
            return link
        }
        if let conferenceData = args["conference_data"] as? [String: Any],
           let link = extractConferenceLinkFromPayload(conferenceData) {
            return link
        }
        return nil
    }

    private static func extractConferenceLinkFromPayload(_ data: [String: Any]) -> String? {
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

    // MARK: - Date Info

    struct DateInfo {
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

    // MARK: - Date Formatters

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

// MARK: - String Extension

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
