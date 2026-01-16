import SwiftUI
import Foundation

struct SlackStageSection: View {
    let proposal: ProposalData
    let stageCornerRadius: CGFloat
    let stageMetadataColumns: [GridItem]
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var body: some View {
        stageContainer {
            VStack(alignment: .leading, spacing: 12) {
                if let messageText = slackMessageDisplay {
                    ScrollableTextArea(maxHeight: 140, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                        if let markdown = slackAttributedText(from: messageText) {
                            Text(markdown)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(messageText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                if !slackMetadataItems.isEmpty {
                    MetadataGrid(items: slackMetadataItems, columns: stageMetadataColumns)
                }
            }
        }
    }
    
    // MARK: - Stage Container
    
    @ViewBuilder
    private func stageContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(stageBackground)
            .clipShape(RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous)
                    .stroke(palette.subtleBorder.opacity(0.6), lineWidth: 0.5)
            )
    }
    
    @ViewBuilder
    private var stageBackground: some View {
        ZStack {
            LiquidGlassSurface(shape: .roundedRect(stageCornerRadius), prominence: .subtle, shadowed: false)
            if preferences.glassStyle == .clear {
                RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.07))
            }
        }
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

    var slackScheduleDisplay: String? {
        guard let scheduledTime = proposal.scheduledTime else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(scheduledTime))
        return Self.slackScheduleFormatter.string(from: date)
    }

    var slackMetadataItems: [(String, String)] {
        var items: [(String, String)] = []
        if let channel = slackChannelDisplay {
            items.append(("Channel", channel))
        }
        if let recipient = slackRecipientDisplay {
            items.append(("Recipient", recipient))
        }
        if let schedule = slackScheduleDisplay {
            items.append(("Schedule", schedule))
        }
        return items
    }

    private var slackMessageDisplay: String? {
        guard let messageText = proposal.messageText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !messageText.isEmpty else {
            return nil
        }
        var output = messageText
        output = output.replacingOccurrences(of: "\\r\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\t", with: "\t")
        output = replaceSlackLinks(in: output)
        return output
    }

    private func slackAttributedText(from text: String) -> AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return try? AttributedString(markdown: text, options: options)
    }

    private func replaceSlackLinks(in text: String) -> String {
        var output = text
        output = replaceRegex(in: output, pattern: #"<([^>|]+)\|([^>]+)>"#) { match, source in
            let url = source.substring(with: match.range(at: 1))
            let label = source.substring(with: match.range(at: 2))
            return "[\(label)](\(url))"
        }
        output = replaceRegex(in: output, pattern: #"<(https?://[^>]+)>"#) { match, source in
            let url = source.substring(with: match.range(at: 1))
            return "[\(url)](\(url))"
        }
        return output
    }

    private func replaceRegex(
        in text: String,
        pattern: String,
        replacement: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let source = text as NSString
        var output = text
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: source.length))
        for match in matches.reversed() {
            let value = replacement(match, source)
            output = (output as NSString).replacingCharacters(in: match.range, with: value)
        }
        return output
    }
    
    private static let slackScheduleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Slack Action Buttons

struct SlackActionButtons: View {
    let proposal: ProposalData
    let isExecuting: Bool
    let onConfirm: () -> Void
    var gradientNamespace: Namespace.ID? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var isScheduledMessage: Bool {
        proposal.tool.lowercased().contains("schedule")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Primary "Send" button
            ActionGlowButton(
                title: "Send",
                isExecuting: isExecuting,
                action: {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    onConfirm()
                },
                gradientNamespace: gradientNamespace
            )
            
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
