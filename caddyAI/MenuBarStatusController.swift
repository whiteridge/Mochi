import AppKit
import SwiftUI

/// Lightweight status-item menu for the main caddyAI app so users always see the tray icon.
final class MenuBarStatusController: NSObject {
	private let statusItem: NSStatusItem
	private let menu = NSMenu()
	private let toggleBubble: () -> Void
	private let openSettings: () -> Void
	
	init(
		toggleBubble: @escaping () -> Void,
		openSettings: @escaping () -> Void
	) {
		self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		self.toggleBubble = toggleBubble
		self.openSettings = openSettings
		super.init()
	}
	
	func install() {
		if let button = statusItem.button {
			button.image = NSImage(
				systemSymbolName: "bubble.left.and.bubble.right.fill",
				accessibilityDescription: "caddyAI"
			)
			button.imagePosition = .imageOnly
		}
		configureMenu()
		statusItem.menu = menu
	}
	
	func invalidate() {
		NSStatusBar.system.removeStatusItem(statusItem)
	}
	
	@objc private func handleToggleBubble() {
		print("[MenuBar] Toggle bubble tapped")
		toggleBubble()
	}
	
	@objc private func handleOpenSettings() {
		print("[MenuBar] Settings menu tapped")
		openSettings()
	}
	
	@objc private func handleCheckUpdates() {
		print("[MenuBar] Check for updates tapped")
		let alert = NSAlert()
		alert.messageText = "You're up to date"
		alert.informativeText = "Automatic updates will surface here once configured."
		alert.alertStyle = .informational
		alert.runModal()
	}
	
	@objc private func handleQuit() {
		print("[MenuBar] Quit tapped")
		NSApp.terminate(nil)
	}
	
	private func configureMenu() {
		menu.autoenablesItems = false
		
		let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(handleCheckUpdates), keyEquivalent: "")
		updateItem.target = self
		menu.addItem(updateItem)
		
		let settingsItem = NSMenuItem(title: "Settings…", action: #selector(handleOpenSettings), keyEquivalent: ",")
		settingsItem.target = self
		menu.addItem(settingsItem)
		
		menu.addItem(.separator())
		
		let toggleItem = NSMenuItem(title: "Show/Hide Bubble", action: #selector(handleToggleBubble), keyEquivalent: "")
		toggleItem.target = self
		menu.addItem(toggleItem)
		
		let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)
	}
}


