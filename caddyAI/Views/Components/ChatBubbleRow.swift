import SwiftUI

struct ChatBubbleRow: View {
    let message: ChatMessage
    
    var body: some View {
        let isUser = message.role == .user
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            HStack {
                if isUser { Spacer(minLength: 40) }
                Text(message.content)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isUser {
                                // User bubble - slightly lighter dark glass
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.2),
                                                        Color.white.opacity(0.06)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                            } else {
                                // Assistant bubble - glass effect
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.15),
                                                        Color.white.opacity(0.04)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                            }
                        }
                    )
                if !isUser { Spacer(minLength: 40) }
            }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }
}

