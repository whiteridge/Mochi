import SwiftUI

struct ChatBubbleRow: View {
    let message: ChatMessage
    
    var body: some View {
        let isUser = message.role == .user
        
        if isUser {
            // User messages have bubble styling
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Spacer(minLength: 60)
                    Text(message.content.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(GlassBackground(cornerRadius: 22))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            // Assistant messages are plain text, no bubble
            HStack {
                Text(message.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .transition(.opacity)
        }
    }
}




















