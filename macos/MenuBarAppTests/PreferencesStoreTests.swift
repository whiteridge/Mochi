import XCTest
@testable import MenuBarApp

final class PreferencesStoreTests: XCTestCase {
	func testResetClearsValues() {
		let suiteName = "com.matteofari.caddyAI.menu.tests.pref"
		let store = UserDefaults(suiteName: suiteName)!
		store.removePersistentDomain(forName: suiteName)
		let prefs = PreferencesStore(store: store)
		prefs.updateAccentColor(hex: "#FFFFFF")
		prefs.updateAPI(key: "abc", baseURL: "https://example.com")
		prefs.hasCompletedSetup = true
		
		prefs.reset()
		
		XCTAssertEqual(prefs.accentColorHex, "#4A90E2")
		XCTAssertEqual(prefs.apiKey, "")
		XCTAssertEqual(prefs.apiBaseURL, "")
		XCTAssertFalse(prefs.hasCompletedSetup)
	}
	
	func testThemeSwitchUpdatesAppearance() {
		let suiteName = "com.matteofari.caddyAI.menu.tests.pref.appearance"
		let store = UserDefaults(suiteName: suiteName)!
		store.removePersistentDomain(forName: suiteName)
		let prefs = PreferencesStore(store: store)
		prefs.theme = .dark
		XCTAssertEqual(prefs.theme, .dark)
		
		prefs.theme = .light
		XCTAssertEqual(prefs.theme, .light)
	}
}

