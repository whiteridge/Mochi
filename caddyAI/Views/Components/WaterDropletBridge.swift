import SwiftUI

/// A custom shape that creates a fluid, inverted-radius "neck" connector
/// Mimics a metaball/liquid connection between two elements
struct WaterDropletBridge: View {
    var width: CGFloat = 40
    var height: CGFloat = 20
    var color: Color = .black.opacity(0.85)
    var borderGradient: LinearGradient? = nil
    
    var body: some View {
        ZStack {
            // The main fill - matching ConfirmationCard stack
            BridgeShape()
                .fill(.thickMaterial)
            BridgeShape()
                .fill(color)
            
            // The border strokes
            if let gradient = borderGradient {
                BridgeStroke()
                    .stroke(gradient, lineWidth: 1)
            }
        }
        .frame(width: width, height: height)
    }
}

/// The closed shape for filling the bridge
struct BridgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Start top-left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: width, y: 0))
        
        // Right side - concave curve (inward)
        // Control point is inward to create the "neck" effect
        path.addCurve(
            to: CGPoint(x: width, y: height),
            control1: CGPoint(x: width, y: height * 0.3),
            control2: CGPoint(x: width * 0.6, y: height * 0.7)
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: height))
        
        // Left side - concave curve (inward)
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: width * 0.4, y: height * 0.7),
            control2: CGPoint(x: 0, y: height * 0.3)
        )
        
        path.closeSubpath()
        return path
    }
}

/// The open shape for stroking the sides of the bridge
struct BridgeStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Right side
        path.move(to: CGPoint(x: width, y: 0))
        path.addCurve(
            to: CGPoint(x: width, y: height),
            control1: CGPoint(x: width, y: height * 0.3),
            control2: CGPoint(x: width * 0.6, y: height * 0.7)
        )
        
        // Left side
        path.move(to: CGPoint(x: 0, y: height))
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: width * 0.4, y: height * 0.7),
            control2: CGPoint(x: 0, y: height * 0.3)
        )
        
        return path
    }
}
