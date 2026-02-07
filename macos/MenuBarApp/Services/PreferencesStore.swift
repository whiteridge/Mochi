import SwiftUI
import AppKit

enum ThemePreference: String, CaseIterable, Identifiable {
	case system
	case light
	case dark
	
	var id: String { rawValue }
	var label: String {
		switch self {
		case .system: "Follow system"
		case .light: "Light"
		case .dark: "Dark"
		}
	}
	
	var appearance: NSAppearance.Name? {
		switch self {
		case .system:
			nil
		case .light:
			.lightAqua
		case .dark:
			.darkAqua
		}
	}
}

struct AccentColorOption: Identifiable, Hashable {
	let id: String
	let name: String
	let color: Color
	let hex: String
}

final class PreferencesStore: ObservableObject {
	private enum Keys {
		static let accent = "accentColorHex"
		static let theme = "theme"
		static let apiKey = "apiKey"
		static let apiBaseURL = "apiBaseURL"
		static let hasCompletedSetup = "hasCompletedSetup"
	}
	
	private let store: UserDefaults
	
	@Published var accentColorHex: String {
		didSet { store.set(accentColorHex, forKey: Keys.accent) }
	}
	
	@Published var themeRaw: String {
		didSet { store.set(themeRaw, forKey: Keys.theme) }
	}
	
	@Published var apiKey: String {
		didSet { store.set(apiKey, forKey: Keys.apiKey) }
	}
	
	@Published var apiBaseURL: String {
		didSet { store.set(apiBaseURL, forKey: Keys.apiBaseURL) }
	}
	
	@Published var hasCompletedSetup: Bool {
		didSet { store.set(hasCompletedSetup, forKey: Keys.hasCompletedSetup) }
	}
	
	var accentColor: Color {
		Color(hex: accentColorHex) ?? .accentColor
	}
	
	var theme: ThemePreference {
		get { ThemePreference(rawValue: themeRaw) ?? .system }
		set {
			themeRaw = newValue.rawValue
			applyTheme(newValue)
		}
	}
	
	init(store: UserDefaults = UserDefaults(suiteName: "com.matteofari.mochi.menu") ?? .standard) {
		self.store = store
		self.accentColorHex = store.string(forKey: Keys.accent) ?? "#4A90E2"
		self.themeRaw = store.string(forKey: Keys.theme) ?? ThemePreference.dark.rawValue
		self.apiKey = store.string(forKey: Keys.apiKey) ?? ""
		self.apiBaseURL = store.string(forKey: Keys.apiBaseURL) ?? ""
		self.hasCompletedSetup = store.bool(forKey: Keys.hasCompletedSetup)
		applyTheme(theme)
	}
	
	func updateAccentColor(hex: String) {
		accentColorHex = hex
	}
	
	func updateAPI(key: String, baseURL: String) {
		apiKey = key
		apiBaseURL = baseURL
	}
	
	func reset() {
		accentColorHex = "#4A90E2"
		themeRaw = ThemePreference.dark.rawValue
		apiKey = ""
		apiBaseURL = ""
		hasCompletedSetup = false
		
		store.removeObject(forKey: Keys.accent)
		store.removeObject(forKey: Keys.theme)
		store.removeObject(forKey: Keys.apiKey)
		store.removeObject(forKey: Keys.apiBaseURL)
		store.removeObject(forKey: Keys.hasCompletedSetup)
	}
	
	private func applyTheme(_ theme: ThemePreference) {
		if let appearanceName = theme.appearance {
			NSApplication.shared.appearance = NSAppearance(named: appearanceName)
		} else {
			NSApplication.shared.appearance = nil
		}
	}
}

private extension Color {
	init?(hex: String) {
		var formatted = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		formatted = formatted.replacingOccurrences(of: "#", with: "")
		
		var rgb: UInt64 = 0
		guard Scanner(string: formatted).scanHexInt64(&rgb) else { return nil }
		
		let r = Double((rgb & 0xFF0000) >> 16) / 255.0
		let g = Double((rgb & 0x00FF00) >> 8) / 255.0
		let b = Double(rgb & 0x0000FF) / 255.0
		self = Color(red: r, green: g, blue: b)
	}
}
