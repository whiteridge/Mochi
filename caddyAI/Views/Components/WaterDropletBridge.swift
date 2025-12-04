import SwiftUI

/// A custom shape that creates a symmetrical bridge connector
/// Capsule-like with rounded ends, slightly narrower in the middle for visual softness
struct WaterDropletBridge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create a symmetrical capsule shape
        // Slightly wider at top and bottom, gently tapering in middle
        let cornerRadius = width / 2
        let middlePinch: CGFloat = 0.15  // How much to pinch in the middle (0 = no pinch)
        
        // Top-left corner
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
        
        // Top-right curve
        path.addArc(
            center: CGPoint(x: width - cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right side with gentle middle pinch
        let midY = height / 2
        let pinchAmount = width * middlePinch
        path.addQuadCurve(
            to: CGPoint(x: width, y: height - cornerRadius),
            control: CGPoint(x: width - pinchAmount, y: midY)
        )
        
        // Bottom-right curve
        path.addArc(
            center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: height))
        
        // Bottom-left curve
        path.addArc(
            center: CGPoint(x: cornerRadius, y: height - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left side with gentle middle pinch
        path.addQuadCurve(
            to: CGPoint(x: 0, y: cornerRadius),
            control: CGPoint(x: pinchAmount, y: midY)
        )
        
        // Top-left curve
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}
