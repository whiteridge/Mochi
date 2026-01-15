import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    var isRecording: Bool
    var startRecording: () -> Void
    var stopRecording: () -> Void
    var sendAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Logo icon with glass effect
            Circle()
                .fill(palette.iconBackground)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    palette.iconStroke.opacity(0.9),
                                    palette.iconStroke.opacity(0.25)
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
                        .foregroundStyle(palette.iconSecondary)
                )
            
            // Text field
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Type to Caddy")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(palette.secondaryText)
                }
                
                TextField("", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(palette.primaryText)
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
            LiquidGlassSurface(shape: .capsule, prominence: .strong, shadowed: false)
        )
        .clipShape(Capsule())
    }
}



















