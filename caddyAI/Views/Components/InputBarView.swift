import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    var isRecording: Bool
    var startRecording: () -> Void
    var stopRecording: () -> Void
    var sendAction: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Logo icon with glass effect
            Circle()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                )
            
            // Text field
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Type to Caddy")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                TextField("", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .onSubmit(sendAction)
            }
            
            Spacer()
            
            // Microphone button / Stop button
            VoiceActionButton(
                size: 28,
                isRecording: isRecording,
                action: isRecording ? stopRecording : startRecording
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.black.opacity(0.75))
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}




