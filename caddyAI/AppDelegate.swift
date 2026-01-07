import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var panelController: PanelController?
	private let globalKeyMonitor = GlobalKeyMonitor()
	private var dismissObserver: NSObjectProtocol?
	private var statusItemController: MenuBarStatusController?
	private var settingsWindow: NSWindow?
	private var quickSetupWindow: NSWindow?
	private let settingsEnvironment = SettingsEnvironment()

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Ensure the main app can present windows from the status item.
		NSApp.setActivationPolicy(.regular)
		
		panelController = PanelController(rootView: AnyView(VoiceChatBubble()))
		
		statusItemController = MenuBarStatusController(
			toggleBubble: { [weak self] in
				self?.handleDoubleCommandTap()
			},
			openSettings: { [weak self] in
				self?.showSettings()
			}
		)
		statusItemController?.install()

		// Set up double-tap Command key handler
		globalKeyMonitor.onDoubleTapCommand = { [weak self] in
			self?.handleDoubleCommandTap()
		}
		globalKeyMonitor.start()
		
		// Listen for dismiss notification (e.g., after success animation completes)
		dismissObserver = NotificationCenter.default.addObserver(
			forName: .voiceChatShouldDismissPanel,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.panelController?.hide()
		}
		
		// Show quick setup on first launch
		if !settingsEnvironment.preferences.hasCompletedSetup {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				self?.showQuickSetup()
			}
		}
	}
	
	/// Handle double-tap Command key event
	private func handleDoubleCommandTap() {
		guard let panelController = panelController else { return }
		
		if panelController.panel.isVisible {
			// If app is visible, hide it
			panelController.hide()
		} else {
			// If app is hidden, show it and activate
			NSApp.activate(ignoringOtherApps: true)
			panelController.show()
		}
	}
	
	private func showSettings() {
		print("[MenuBar] Settings clicked")
		
		// Ensure we are in a regular activation policy so the window can appear.
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
		
		if let settingsWindow {
			print("[MenuBar] Reusing existing settings window")
			settingsWindow.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
			settingsWindow.orderFrontRegardless()
			print("[MenuBar] Existing settings frame: \(settingsWindow.frame)")
			return
		}
		
		let hosting = NSHostingController(
			rootView: AppSettingsView()
				.environmentObject(settingsEnvironment.preferences)
				.environmentObject(settingsEnvironment.integrationService)
				.environmentObject(settingsEnvironment.viewModel)
		)
		let rect: NSRect
		if let screen = NSScreen.main {
			let frame = screen.visibleFrame
			let width: CGFloat = 840
			let height: CGFloat = 640
			rect = NSRect(
				x: frame.midX - width / 2,
				y: frame.midY - height / 2,
				width: width,
				height: height
			)
		} else {
			rect = NSRect(x: 0, y: 0, width: 840, height: 640)
		}
		
		let window = NSWindow(
			contentRect: rect,
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "caddyAI"
		window.contentViewController = hosting
		window.isReleasedWhenClosed = false
		window.setFrame(rect, display: true)
		window.orderFrontRegardless()
		settingsWindow = window
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		print("[MenuBar] Settings window presented at frame: \(window.frame)")
	}
	
	private func showQuickSetup() {
		// Ensure we are in a regular activation policy so the window can appear
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
		
		// If window already exists, just show it
		if let quickSetupWindow {
			quickSetupWindow.makeKeyAndOrderFront(nil)
			return
		}
		
		let hosting = NSHostingController(
			rootView: QuickSetupView(onComplete: { [weak self] in
				self?.quickSetupWindow?.close()
				self?.quickSetupWindow = nil
			})
			.environmentObject(settingsEnvironment.preferences)
			.environmentObject(settingsEnvironment.integrationService)
			.environmentObject(settingsEnvironment.viewModel)
		)
		
		let width: CGFloat = 420
		let height: CGFloat = 540
		let rect: NSRect
		if let screen = NSScreen.main {
			let frame = screen.visibleFrame
			rect = NSRect(
				x: frame.midX - width / 2,
				y: frame.midY - height / 2,
				width: width,
				height: height
			)
		} else {
			rect = NSRect(x: 0, y: 0, width: width, height: height)
		}
		
		let window = NSWindow(
			contentRect: rect,
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Quick Setup"
		window.contentViewController = hosting
		window.isReleasedWhenClosed = false
		window.setFrame(rect, display: true)
		window.center()
		window.makeKeyAndOrderFront(nil)
		quickSetupWindow = window
	}
}


