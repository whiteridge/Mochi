import SwiftUI

struct GmailStageSection: View {
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
                // Action title header
                Text(actionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
                    .tracking(0.3)

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Subject")
                    Text(subjectDisplay)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Message")
                    if let bodyPreview {
                        ScrollableTextArea(maxHeight: 140, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                            Text(bodyPreview)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("No message body provided.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.tertiaryText)
                    }
                }

                if !gmailMetadataItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Recipients")
                        MetadataGrid(items: gmailMetadataItems, columns: stageMetadataColumns)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Title
    
    private var actionTitle: String {
        let tool = proposal.tool.lowercased()
        
        if tool.contains("reply") {
            return "Replying to Email"
        }
        if tool.contains("forward") {
            return "Forwarding Email"
        }
        if tool.contains("draft") {
            return "Saving Draft"
        }
        if tool.contains("label") {
            return "Applying Label"
        }
        if tool.contains("trash") {
            return "Moving to Trash"
        }
        if tool.contains("delete") {
            return "Deleting Email"
        }
        return "Sending Email"
    }

    // MARK: - Stage Container

    @ViewBuilder
    private func stageContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
    }

    // MARK: - Gmail Display Helpers

    private var subjectDisplay: String {
        if let subject = rawEmailSubject?.trimmingCharacters(in: .whitespacesAndNewlines),
           !subject.isEmpty {
            return subject
        }
        return "No subject"
    }

    private var bodyPreview: String? {
        guard let body = rawEmailBody else { return nil }
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : body
    }

    private var gmailMetadataItems: [(String, String)] {
        var items: [(String, String)] = []
        if let to = recipientDisplay(from: proposal.emailTo) {
            items.append(("To", to))
        }
        if let cc = recipientDisplay(from: proposal.emailCc) {
            items.append(("Cc", cc))
        }
        if let bcc = recipientDisplay(from: proposal.emailBcc) {
            items.append(("Bcc", bcc))
        }
        return items
    }

    private func recipientDisplay(from recipients: [String]) -> String? {
        let cleaned = recipients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        return cleaned.joined(separator: ", ")
    }

    private var rawEmailSubject: String? {
        rawStringValue(for: ["subject", "title"])
    }

    private var rawEmailBody: String? {
        rawStringValue(for: ["body", "message", "text", "content"])
    }

    private func rawStringValue(for keys: [String]) -> String? {
        for key in keys {
            if let value = proposal.args[key] as? String {
                return value
            }
            if let value = proposal.args[key] as? NSNumber {
                return value.stringValue
            }
            if let value = proposal.args[key] as? Int {
                return String(value)
            }
            if let value = proposal.args[key] as? Double {
                return String(value)
            }
            if let value = proposal.args[key] as? Bool {
                return value ? "true" : "false"
            }
        }
        return nil
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(palette.tertiaryText)
            .tracking(0.4)
    }
}
