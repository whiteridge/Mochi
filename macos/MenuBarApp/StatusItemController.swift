import AppKit

final class StatusItemController: NSObject {
	private let statusItem: NSStatusItem
	private let menu = NSMenu()
	private let openSettings: () -> Void
	private let openOnboarding: () -> Void
	
	init(
		openSettings: @escaping () -> Void,
		openOnboarding: @escaping () -> Void
	) {
		self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		self.openSettings = openSettings
		self.openOnboarding = openOnboarding
		super.init()
	}
	
	func install() {
		if let button = statusItem.button {
			button.image = NSImage(
				systemSymbolName: "bubble.left.and.bubble.right.fill",
				accessibilityDescription: "caddyAI Setup"
			)
			button.imagePosition = .imageOnly
		}
		configureMenu()
		statusItem.menu = menu
	}
	
	func invalidate() {
		NSStatusBar.system.removeStatusItem(statusItem)
	}
	
	private func configureMenu() {
		menu.autoenablesItems = false
		
		let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
		updateItem.target = self
		menu.addItem(updateItem)
		
		let onboardingItem = NSMenuItem(title: "Run Setup Wizard…", action: #selector(openOnboardingTapped), keyEquivalent: "")
		onboardingItem.target = self
		menu.addItem(onboardingItem)
		
		let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsTapped), keyEquivalent: ",")
		settingsItem.target = self
		menu.addItem(settingsItem)
		
		menu.addItem(.separator())
		
		let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)
	}
	
	@objc private func openSettingsTapped() {
		openSettings()
	}
	
	@objc private func openOnboardingTapped() {
		openOnboarding()
	}
	
	@objc private func quitApp() {
		NSApp.terminate(nil)
	}
	
	@objc private func checkForUpdates() {
		let alert = NSAlert()
		alert.messageText = "You're up to date"
		alert.informativeText = "Automatic updates are not configured yet. We'll notify you here when they are available."
		alert.alertStyle = .informational
		alert.runModal()
	}
}

