import SwiftUI

enum LiquidGlassProminence {
    case subtle
    case regular
    case strong
}

struct LiquidGlassPalette {
    let colorScheme: ColorScheme

    var primaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.85)
    }

    var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    var tertiaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45)
    }

    var iconPrimary: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.75)
    }

    var iconSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }

    var iconBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06)
    }

    var iconStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.12)
    }

    var divider: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    var subtleBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.1)
    }
}

struct LiquidGlassSurface: View {
    enum ShapeType {
        case roundedRect(CGFloat)
        case capsule
        case circle
    }

    var shape: ShapeType
    var prominence: LiquidGlassProminence = .regular
    var tint: Color? = nil
    var shadowed: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            nativeSurface
        } else {
            legacySurface
        }
    }
    
    // MARK: - Native Glass Effect (macOS 26+ / iOS 26+)
    
    @available(macOS 26.0, iOS 26.0, *)
    @ViewBuilder
    private var nativeSurface: some View {
        switch shape {
        case .roundedRect(let radius):
            Color.clear
                .glassEffect(preferences.glassStyle == .clear ? .clear : .regular, in: .rect(cornerRadius: radius))
                .shadow(
                    color: shadowed ? shadowColor : .clear,
                    radius: shadowed ? shadowRadius : 0,
                    x: 0,
                    y: shadowed ? shadowY : 0
                )
        case .capsule:
            Color.clear
                .glassEffect(preferences.glassStyle == .clear ? .clear : .regular, in: .capsule)
                .shadow(
                    color: shadowed ? shadowColor : .clear,
                    radius: shadowed ? shadowRadius : 0,
                    x: 0,
                    y: shadowed ? shadowY : 0
                )
        case .circle:
            Color.clear
                .glassEffect(preferences.glassStyle == .clear ? .clear : .regular, in: .circle)
                .shadow(
                    color: shadowed ? shadowColor : .clear,
                    radius: shadowed ? shadowRadius : 0,
                    x: 0,
                    y: shadowed ? shadowY : 0
                )
        }
    }
    
    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12)
    }
    
    private var shadowRadius: CGFloat {
        switch prominence {
        case .subtle: return 6
        case .regular: return 8
        case .strong: return 10
        }
    }
    
    private var shadowY: CGFloat {
        switch prominence {
        case .subtle: return 3
        case .regular: return 4
        case .strong: return 5
        }
    }
    
    // MARK: - Legacy Glass Effect (pre-macOS 26)
    
    @ViewBuilder
    private var legacySurface: some View {
        switch shape {
        case .roundedRect(let radius):
            legacySurfaceImpl(for: RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            legacySurfaceImpl(for: Capsule())
        case .circle:
            legacySurfaceImpl(for: Circle())
        }
    }

    @ViewBuilder
    private func legacySurfaceImpl<S: InsettableShape>(for shape: S) -> some View {
        let metrics = LiquidGlassMetrics(colorScheme: colorScheme, prominence: prominence, tintOverride: tint)

        ZStack {
            if reduceTransparency {
                shape.fill(metrics.fallbackFill)
            } else {
                shape.fill(metrics.materialStyle)
            }

            shape.fill(metrics.tint)
            shape.fill(metrics.ambientGradient).opacity(metrics.ambientOpacity)
            shape.fill(metrics.glossGradient).opacity(metrics.glossOpacity)
            shape.fill(metrics.bottomShade).opacity(metrics.bottomShadeOpacity)
        }
        .overlay(
            shape.strokeBorder(metrics.rimGradient, lineWidth: metrics.rimWidth)
        )
        .overlay(
            shape.strokeBorder(Color.white, lineWidth: metrics.innerWidth)
                .blur(radius: metrics.innerBlur)
                .opacity(metrics.innerOpacity)
        )
        .shadow(
            color: shadowed ? metrics.shadowColor : .clear,
            radius: shadowed ? metrics.shadowRadius : 0,
            x: 0,
            y: shadowed ? metrics.shadowY : 0
        )
        .opacity(metrics.overallOpacity)
        .animation(.easeInOut(duration: 0.2), value: colorScheme)
    }
}

private struct LiquidGlassMetrics {
    let materialStyle: Material
    let tint: Color
    let fallbackFill: Color
    let ambientGradient: LinearGradient
    let ambientOpacity: Double
    let glossGradient: LinearGradient
    let glossOpacity: Double
    let bottomShade: LinearGradient
    let bottomShadeOpacity: Double
    let rimGradient: LinearGradient
    let rimWidth: CGFloat
    let innerWidth: CGFloat
    let innerBlur: CGFloat
    let innerOpacity: Double
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let overallOpacity: Double

    init(colorScheme: ColorScheme, prominence: LiquidGlassProminence, tintOverride: Color?) {
        let isDark = colorScheme == .dark
        let level = LiquidGlassLevel(colorScheme: colorScheme, prominence: prominence)

        materialStyle = level.materialStyle
        tint = tintOverride ?? Color.white.opacity(level.tintOpacity)
        fallbackFill = isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.7)

        ambientGradient = LinearGradient(
            colors: [
                Color.white.opacity(isDark ? 0.35 : 0.65),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        ambientOpacity = level.ambientOpacity

        glossGradient = LinearGradient(
            colors: [
                Color.white.opacity(isDark ? 0.45 : 0.7),
                Color.white.opacity(isDark ? 0.12 : 0.25),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        glossOpacity = level.glossOpacity

        bottomShade = LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(isDark ? 0.35 : 0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        bottomShadeOpacity = level.bottomShadeOpacity

        rimGradient = LinearGradient(
            colors: [
                Color.white.opacity(level.rimOpacity),
                Color.black.opacity(isDark ? 0.35 : 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        rimWidth = prominence == .strong ? 1.1 : 0.8

        innerWidth = 0.6
        innerBlur = 1.0
        innerOpacity = level.innerOpacity

        shadowColor = Color.black.opacity(level.shadowOpacity)
        shadowRadius = level.shadowRadius
        shadowY = level.shadowY
        overallOpacity = 1.0
    }
}

private struct LiquidGlassLevel {
    let materialStyle: Material
    let tintOpacity: Double
    let ambientOpacity: Double
    let glossOpacity: Double
    let bottomShadeOpacity: Double
    let rimOpacity: Double
    let innerOpacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    init(colorScheme: ColorScheme, prominence: LiquidGlassProminence) {
        let isDark = colorScheme == .dark

        switch (isDark, prominence) {
        case (true, .subtle):
            materialStyle = .ultraThin
            tintOpacity = 0.08
            ambientOpacity = 0.12
            glossOpacity = 0.12
            bottomShadeOpacity = 0.18
            rimOpacity = 0.22
            innerOpacity = 0.12
            shadowOpacity = 0.18
            shadowRadius = 8
            shadowY = 4
        case (true, .regular):
            materialStyle = .thin
            tintOpacity = 0.12
            ambientOpacity = 0.16
            glossOpacity = 0.16
            bottomShadeOpacity = 0.2
            rimOpacity = 0.26
            innerOpacity = 0.14
            shadowOpacity = 0.22
            shadowRadius = 10
            shadowY = 5
        case (true, .strong):
            materialStyle = .regular
            tintOpacity = 0.16
            ambientOpacity = 0.2
            glossOpacity = 0.2
            bottomShadeOpacity = 0.24
            rimOpacity = 0.3
            innerOpacity = 0.16
            shadowOpacity = 0.26
            shadowRadius = 12
            shadowY = 6
        case (false, .subtle):
            materialStyle = .ultraThin
            tintOpacity = 0.18
            ambientOpacity = 0.16
            glossOpacity = 0.22
            bottomShadeOpacity = 0.1
            rimOpacity = 0.18
            innerOpacity = 0.12
            shadowOpacity = 0.08
            shadowRadius = 6
            shadowY = 3
        case (false, .regular):
            materialStyle = .thin
            tintOpacity = 0.24
            ambientOpacity = 0.2
            glossOpacity = 0.28
            bottomShadeOpacity = 0.12
            rimOpacity = 0.22
            innerOpacity = 0.14
            shadowOpacity = 0.1
            shadowRadius = 8
            shadowY = 4
        case (false, .strong):
            materialStyle = .regular
            tintOpacity = 0.3
            ambientOpacity = 0.24
            glossOpacity = 0.32
            bottomShadeOpacity = 0.14
            rimOpacity = 0.26
            innerOpacity = 0.16
            shadowOpacity = 0.12
            shadowRadius = 10
            shadowY = 5
        }
    }
}
