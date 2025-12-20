import SwiftUI

struct VoiceActionButton: View {
    let size: CGFloat
    let isRecording: Bool
    let action: () -> Void
    
    // Vibrant Orange Color: #FF5500
    private let brandOrange = Color(red: 1.0, green: 0.33, blue: 0.0)
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                Circle()
                    .fill(brandOrange)
                
                // Icon
                Group {
                    if isRecording {
                        Image(systemName: "square.fill")
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: size * 0.5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle()) // Ensure hit testing works on the whole circle
        }
        .buttonStyle(.plain)
        .shadow(color: brandOrange.opacity(0.4), radius: size * 0.2, x: 0, y: size * 0.1)
    }
}

#Preview {
    HStack(spacing: 20) {
        VoiceActionButton(size: 50, isRecording: false, action: {})
        VoiceActionButton(size: 50, isRecording: true, action: {})
        VoiceActionButton(size: 30, isRecording: false, action: {})
        VoiceActionButton(size: 30, isRecording: true, action: {})
    }
    .padding()
    .background(Color.black)
}

