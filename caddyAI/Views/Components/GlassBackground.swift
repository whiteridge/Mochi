import SwiftUI

struct GlassBackground: View {
    var cornerRadius: CGFloat
    var prominence: LiquidGlassProminence = .regular
    var tint: Color? = nil
    var shadowed: Bool = true

    var body: some View {
        LiquidGlassSurface(
            shape: .roundedRect(cornerRadius),
            prominence: prominence,
            tint: tint,
            shadowed: shadowed
        )
    }
}




















