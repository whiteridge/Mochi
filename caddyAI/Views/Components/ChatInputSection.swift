import SwiftUI

struct InputViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ChatInputSection: View {
    @Binding var text: String
    let isRecording: Bool
    let startRecording: () -> Void
    let stopRecording: () -> Void
    let sendAction: () -> Void
    let animation: Namespace.ID
    
    var body: some View {
        InputBarView(
            text: $text,
            isRecording: isRecording,
            startRecording: startRecording,
            stopRecording: stopRecording,
            sendAction: sendAction
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .matchedGeometryEffect(id: "actionButton", in: animation, isSource: false)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: InputViewHeightKey.self, value: geo.size.height)
            }
        )
    }
}
