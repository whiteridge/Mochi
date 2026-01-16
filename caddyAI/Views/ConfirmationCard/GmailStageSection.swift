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
                Text(subjectDisplay)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

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

                if !gmailMetadataItems.isEmpty {
                    MetadataGrid(items: gmailMetadataItems, columns: stageMetadataColumns)
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

    // MARK: - Gmail Display Helpers

    private var subjectDisplay: String {
        if let subject = proposal.emailSubject?.trimmingCharacters(in: .whitespacesAndNewlines),
           !subject.isEmpty {
            return subject
        }
        return "No subject"
    }

    private var bodyPreview: String? {
        if let body = proposal.emailBody?.trimmingCharacters(in: .whitespacesAndNewlines),
           !body.isEmpty {
            return body
        }
        return nil
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
}
