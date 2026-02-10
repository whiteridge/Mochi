import SwiftUI
import AppKit

enum ModelProvider: String, CaseIterable, Identifiable, Codable {
	case google

	var id: String { rawValue }

	var displayName: String {
		"Google"
	}

	var requiresApiKey: Bool {
		true
	}

	var supportsBaseURL: Bool {
		false
	}

	var defaultBaseURL: String? {
		nil
	}

	var isLocal: Bool {
		false
	}
}

struct ModelCatalog {
	static let geminiFlashModel = "gemini-3-flash-preview"

	static func models(for provider: ModelProvider) -> [String] {
		_ = provider
		return [geminiFlashModel]
	}

	static func defaultModel(for provider: ModelProvider) -> String {
		_ = provider
		return geminiFlashModel
	}

	static func displayName(for modelId: String) -> String {
		if modelId == geminiFlashModel {
			return "Gemini 3 Flash"
		}
		return modelId
	}
}

enum ThemePreference: String, CaseIterable, Identifiable {
	case system, light, dark
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
		case .system: nil
		case .light: .aqua
		case .dark: .darkAqua
		}
	}
}

/// Available shortcut keys for voice activation
enum VoiceShortcutKey: String, CaseIterable, Identifiable {
	case fn = "fn"
	case option = "option"
	case control = "control"
	case command = "command"
	
	var id: String { rawValue }
	
	var label: String {
		switch self {
		case .fn: "Fn"
		case .option: "Option (⌥)"
		case .control: "Control (⌃)"
		case .command: "Command (⌘)"
		}
	}
	
	var icon: String {
		switch self {
		case .fn: "fn"
		case .option: "option"
		case .control: "control"
		case .command: "command"
		}
	}
	
	/// The key code for this modifier key
	var keyCode: UInt16 {
		switch self {
		case .fn: 63 // Fn key
		case .option: 58 // Left Option (Right Option is 61)
		case .control: 59 // Left Control (Right Control is 62)
		case .command: 55 // Left Command (Right Command is 54)
		}
	}
	
	/// Alternative key code (for left/right variants)
	var alternateKeyCode: UInt16? {
		switch self {
		case .fn: nil
		case .option: 61 // Right Option
		case .control: 62 // Right Control
		case .command: 54 // Right Command
		}
	}
	
	/// The modifier flag to check
	var modifierFlag: NSEvent.ModifierFlags? {
		switch self {
		case .fn: .function
		case .option: .option
		case .control: .control
		case .command: .command
		}
	}
}

/// Voice activation mode
enum VoiceActivationMode: String, CaseIterable, Identifiable {
	case holdToTalk = "hold"
	case toggle = "toggle"
	
	var id: String { rawValue }
	
	var label: String {
		switch self {
		case .holdToTalk: "Hold to Talk"
		case .toggle: "Toggle"
		}
	}
	
	var description: String {
		switch self {
		case .holdToTalk: "Press and hold to record, release to send"
		case .toggle: "Press once to start, press again to stop"
		}
	}
}

/// Glass effect style preference
enum GlassStyle: String, CaseIterable, Identifiable {
	case clear = "clear"
	case regular = "regular"
	
	var id: String { rawValue }
	
	var label: String {
		switch self {
		case .clear: "Clear"
		case .regular: "Regular"
		}
	}
	
	var description: String {
		switch self {
		case .clear: "Maximum transparency, works best over dark backgrounds"
		case .regular: "Frosted glass with better contrast over any background"
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
	enum Keys {
		static let accent = "accentColorHex"
		static let theme = "theme"
		static let apiKey = "apiKey"
		static let apiBaseURL = "apiBaseURL"
		static let hasCompletedSetup = "hasCompletedSetup"
		static let voiceShortcutKey = "voiceShortcutKey"
		static let voiceActivationMode = "voiceActivationMode"
		static let glassStyle = "glassStyle"
		static let modelProvider = "modelProvider"
		static let modelName = "modelName"
	}
	
	private let store: UserDefaults
	
	@Published var accentColorHex: String { didSet { store.set(accentColorHex, forKey: Keys.accent) } }
	@Published var themeRaw: String { didSet { store.set(themeRaw, forKey: Keys.theme) } }
	@Published var apiKey: String { didSet { store.set(apiKey, forKey: Keys.apiKey) } }
	@Published var apiBaseURL: String { didSet { store.set(apiBaseURL, forKey: Keys.apiBaseURL) } }
	@Published var modelProviderRaw: String { didSet { store.set(modelProviderRaw, forKey: Keys.modelProvider) } }
	@Published var modelName: String { didSet { store.set(modelName, forKey: Keys.modelName) } }
	@Published var hasCompletedSetup: Bool { didSet { store.set(hasCompletedSetup, forKey: Keys.hasCompletedSetup) } }
	@Published var voiceShortcutKeyRaw: String { didSet { store.set(voiceShortcutKeyRaw, forKey: Keys.voiceShortcutKey) } }
	@Published var voiceActivationModeRaw: String { didSet { store.set(voiceActivationModeRaw, forKey: Keys.voiceActivationMode) } }
	@Published var glassStyleRaw: String { didSet { store.set(glassStyleRaw, forKey: Keys.glassStyle) } }
	
	var accentColor: Color { Color(hex: accentColorHex) ?? .accentColor }
	var modelProvider: ModelProvider {
		get { ModelProvider(rawValue: modelProviderRaw) ?? .google }
		set { modelProviderRaw = newValue.rawValue }
	}
	var theme: ThemePreference {
		get { ThemePreference(rawValue: themeRaw) ?? .system }
		set { themeRaw = newValue.rawValue; applyTheme(newValue) }
	}
	
	// #region agent log
	private func debugLog(hypothesisId: String, location: String, message: String, data: [String: String] = [:]) {
		let logPath = "/Users/matteofari/Desktop/projects/mochi/.cursor/debug.log"
		let timestamp = Int(Date().timeIntervalSince1970 * 1000)
		let dataJson = data.isEmpty ? "{}" : "{\(data.map { "\"\($0.key)\":\"\($0.value)\"" }.joined(separator: ","))}"
		let logEntry = "{\"hypothesisId\":\"\(hypothesisId)\",\"location\":\"\(location)\",\"message\":\"\(message)\",\"data\":\(dataJson),\"timestamp\":\(timestamp)}\n"
		if let handle = FileHandle(forWritingAtPath: logPath) {
			handle.seekToEndOfFile()
			handle.write(logEntry.data(using: .utf8)!)
			handle.closeFile()
		} else {
			FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8), attributes: nil)
		}
	}
	// #endregion
	
	var voiceShortcutKey: VoiceShortcutKey {
		get {
			let result = VoiceShortcutKey(rawValue: voiceShortcutKeyRaw) ?? .fn
			// #region agent log
			debugLog(hypothesisId: "A", location: "PreferencesStore.voiceShortcutKey.get", message: "getter_called", data: ["rawValue": voiceShortcutKeyRaw, "result": result.rawValue])
			// #endregion
			return result
		}
		set {
			// #region agent log
			debugLog(hypothesisId: "A", location: "PreferencesStore.voiceShortcutKey.set", message: "setter_called", data: ["newValue": newValue.rawValue, "currentRaw": voiceShortcutKeyRaw])
			// #endregion
			voiceShortcutKeyRaw = newValue.rawValue
		}
	}
	
	var voiceActivationMode: VoiceActivationMode {
		get { VoiceActivationMode(rawValue: voiceActivationModeRaw) ?? .holdToTalk }
		set { voiceActivationModeRaw = newValue.rawValue }
	}
	
	var glassStyle: GlassStyle {
		get { GlassStyle(rawValue: glassStyleRaw) ?? .regular }
		set { glassStyleRaw = newValue.rawValue }
	}
	
	init(store: UserDefaults = UserDefaults.standard) {
		self.store = store
		self.accentColorHex = store.string(forKey: Keys.accent) ?? "#4A90E2"
		self.themeRaw = store.string(forKey: Keys.theme) ?? ThemePreference.dark.rawValue
		self.apiKey = store.string(forKey: Keys.apiKey) ?? ""
		self.apiBaseURL = store.string(forKey: Keys.apiBaseURL) ?? ""
		self.modelProviderRaw = ModelProvider.google.rawValue
		self.modelName = ModelCatalog.defaultModel(for: .google)
		self.hasCompletedSetup = store.bool(forKey: Keys.hasCompletedSetup)
		self.voiceShortcutKeyRaw = store.string(forKey: Keys.voiceShortcutKey) ?? VoiceShortcutKey.fn.rawValue
		self.voiceActivationModeRaw = store.string(forKey: Keys.voiceActivationMode) ?? VoiceActivationMode.holdToTalk.rawValue
		self.glassStyleRaw = store.string(forKey: Keys.glassStyle) ?? GlassStyle.regular.rawValue
		applyTheme(theme)
	}
	
	func updateAccentColor(hex: String) { accentColorHex = hex }
	func updateAPI(key: String, baseURL: String) { apiKey = key; apiBaseURL = baseURL }
	
	func reset() {
		accentColorHex = "#4A90E2"
		themeRaw = ThemePreference.dark.rawValue
		apiKey = ""
		apiBaseURL = ""
		modelProviderRaw = ModelProvider.google.rawValue
		modelName = ModelCatalog.defaultModel(for: .google)
		hasCompletedSetup = false
		voiceShortcutKeyRaw = VoiceShortcutKey.fn.rawValue
		voiceActivationModeRaw = VoiceActivationMode.holdToTalk.rawValue
		glassStyleRaw = GlassStyle.regular.rawValue
		
		store.removeObject(forKey: Keys.accent)
		store.removeObject(forKey: Keys.theme)
		store.removeObject(forKey: Keys.apiKey)
		store.removeObject(forKey: Keys.apiBaseURL)
		store.removeObject(forKey: Keys.modelProvider)
		store.removeObject(forKey: Keys.modelName)
		store.removeObject(forKey: Keys.hasCompletedSetup)
		store.removeObject(forKey: Keys.voiceShortcutKey)
		store.removeObject(forKey: Keys.voiceActivationMode)
		store.removeObject(forKey: Keys.glassStyle)
	}
	
	private func applyTheme(_ theme: ThemePreference) {
		NSApplication.shared.appearance = theme.appearance.flatMap { NSAppearance(named: $0) }
	}
}

extension Color {
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
