import SwiftUI
import AppKit

final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
	static var environment: MenuBarEnvironment?
	
	private var statusItemController: StatusItemController?
	private var settingsWindowController: SettingsWindowController?
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		guard let environment = Self.environment else { return }
		
		settingsWindowController = SettingsWindowController(environment: environment)
		
		statusItemController = StatusItemController(
			openSettings: { [weak self] in
				self?.settingsWindowController?.showSettings()
			},
			openOnboarding: { [weak self] in
				self?.settingsWindowController?.showOnboarding()
			}
		)
		statusItemController?.install()
	}
	
	func applicationWillTerminate(_ notification: Notification) {
		statusItemController?.invalidate()
	}
}

final class SettingsWindowController {
	private var settingsWindow: NSWindow?
	private var onboardingWindow: NSWindow?
	private let environment: MenuBarEnvironment
	
	init(environment: MenuBarEnvironment) {
		self.environment = environment
	}
	
	func showSettings() {
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
		
		if settingsWindow == nil {
			let rootView = SettingsContainerView()
				.environmentObject(environment.preferences)
				.environmentObject(environment.integrationService)
				.environmentObject(environment.settingsViewModel)
			
			let hostingController = NSHostingController(rootView: rootView)
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 840, height: 640),
				styleMask: [.titled, .closable, .miniaturizable, .resizable],
				backing: .buffered,
				defer: false
			)
			window.title = "mochi Setup"
			window.contentViewController = hostingController
			window.center()
			settingsWindow = window
		}
		
		settingsWindow?.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}
	
	func showOnboarding() {
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
		
		if let onboardingWindow {
			onboardingWindow.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
			return
		}
		
		let onboarding = OnboardingView()
			.environmentObject(environment.preferences)
			.environmentObject(environment.integrationService)
			.environmentObject(environment.settingsViewModel)
		
		let controller = NSHostingController(rootView: onboarding)
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "First-time Setup"
		window.contentViewController = controller
		window.center()
		onboardingWindow = window
		
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}
}
