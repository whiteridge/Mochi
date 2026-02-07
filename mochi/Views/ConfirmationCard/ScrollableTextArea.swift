import SwiftUI

struct ScrollableTextArea<Content: View>: View {
    let maxHeight: CGFloat
    let indicatorWidth: CGFloat
    let indicatorPadding: CGFloat
    let indicatorColor: Color
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    init(
        maxHeight: CGFloat = 140,
        indicatorWidth: CGFloat = 3,
        indicatorPadding: CGFloat = 6,
        indicatorColor: Color = Color.primary.opacity(0.2),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxHeight = maxHeight
        self.indicatorWidth = indicatorWidth
        self.indicatorPadding = indicatorPadding
        self.indicatorColor = indicatorColor
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .onPreferenceChange(ContentHeightKey.self) { newValue in
            contentHeight = newValue
        }
        .frame(height: resolvedHeight)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            scrollOffset = offset
        }
        .overlay(alignment: .topTrailing) {
            if shouldShowIndicator {
                Capsule()
                    .fill(indicatorColor)
                    .frame(width: indicatorWidth, height: indicatorHeight)
                    .padding(.trailing, 2)
                    .padding(.top, indicatorPadding)
                    .offset(y: indicatorOffset)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.12), value: indicatorOffset)
            }
        }
    }

    private var resolvedHeight: CGFloat {
        guard contentHeight > 0 else { return maxHeight }
        return min(contentHeight, maxHeight)
    }

    private var shouldShowIndicator: Bool {
        contentHeight > resolvedHeight + 1
    }

    private var indicatorHeight: CGFloat {
        guard contentHeight > 0, resolvedHeight > 0 else { return 0 }
        let ratio = resolvedHeight / contentHeight
        let rawHeight = ratio * resolvedHeight
        let minHeight: CGFloat = 16
        let maxHeight: CGFloat = resolvedHeight * 0.45
        return min(max(rawHeight, minHeight), maxHeight)
    }

    private var indicatorOffset: CGFloat {
        guard contentHeight > resolvedHeight, resolvedHeight > 0 else { return 0 }
        let scrollableHeight = contentHeight - resolvedHeight
        let progress = min(max(scrollOffset / scrollableHeight, 0), 1)
        let trackHeight = max(resolvedHeight - (indicatorPadding * 2) - indicatorHeight, 0)
        return progress * trackHeight
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
