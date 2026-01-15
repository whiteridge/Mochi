import SwiftUI

struct MetadataGrid: View {
    let items: [(String, String)]
    let columns: [GridItem]
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items, id: \.0) { title, value in
                MetadataGridItem(title: title, value: value)
            }
        }
    }
}

struct MetadataGridItem: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.tertiaryText)
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
