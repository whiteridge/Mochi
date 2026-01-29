import SwiftUI
import AppKit
import Combine
import Foundation

// #region agent log
private func debugLog(hypothesisId: String, location: String, message: String, data: [String: String] = [:]) {
    let logPath = "/Users/matteofari/Desktop/projects/caddyAI/.cursor/debug.log"
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

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var panelController: PanelController?
	private let voiceKeyMonitor = VoiceActivationKeyMonitor()
	private var dismissObserver: NSObjectProtocol?
	private var preferencesObserver: AnyCancellable?
	private var statusItemController: MenuBarStatusController?
	private var settingsWindow: NSWindow?
	private var quickSetupWindow: NSWindow?
	private let settingsEnvironment = SettingsEnvironment()

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Ensure the main app can present windows from the status item.
		NSApp.setActivationPolicy(.regular)
		
		panelController = PanelController(rootView: AnyView(
			VoiceChatBubble()
				.environmentObject(settingsEnvironment.preferences)
		))
		
		statusItemController = MenuBarStatusController(
			toggleBubble: { [weak self] in
				self?.handleToggleBubble()
			},
			openSettings: { [weak self] in
				self?.showSettings()
			}
		)
		statusItemController?.install()

		// Configure voice key monitor with current preferences
		configureVoiceKeyMonitor()
		
		// Observe preference changes to reconfigure the monitor
		preferencesObserver = Publishers.CombineLatest(
			settingsEnvironment.preferences.$voiceShortcutKeyRaw,
			settingsEnvironment.preferences.$voiceActivationModeRaw
		)
		.dropFirst() // Skip initial value
		.sink { [weak self] newKeyRaw, newModeRaw in
			// #region agent log
			print("[AppDelegate] Combine observer fired: keyRaw=\(newKeyRaw), modeRaw=\(newModeRaw)")
			// #endregion
			// FIX: Use the emitted values directly instead of re-reading from property (race condition fix)
			guard let shortcutKey = VoiceShortcutKey(rawValue: newKeyRaw),
				  let activationMode = VoiceActivationMode(rawValue: newModeRaw) else {
				print("[AppDelegate] WARNING: Could not parse emitted values, falling back to property read")
				self?.configureVoiceKeyMonitor()
				return
			}
			print("[AppDelegate] Using emitted values directly: key=\(shortcutKey.rawValue), mode=\(activationMode.rawValue)")
			self?.configureVoiceKeyMonitorWith(shortcutKey: shortcutKey, activationMode: activationMode)
		}
		
		// Listen for dismiss notification (e.g., after success animation completes)
		dismissObserver = NotificationCenter.default.addObserver(
			forName: .voiceChatShouldDismissPanel,
			object: nil,
			queue: .main
		) { [weak self] _ in
			// Reset key held state in case panel was dismissed while key was held
			self?.voiceKeyMonitor.resetKeyState()
			self?.panelController?.hide()
		}
		
		// Show quick setup when required (missing API key or Composio connection)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			self?.evaluateInitialSetup()
		}
	}

	private func evaluateInitialSetup() {
		settingsEnvironment.viewModel.loadPersistedValues()
		let apiKeyMissing = settingsEnvironment.viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		if apiKeyMissing {
			showQuickSetup()
			return
		}
		
		refreshComposioStatuses()
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
			guard let self else { return }
			let stillMissingAPIKey = self.settingsEnvironment.viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			let hasAnyConnection = self.settingsEnvironment.integrationService.hasAnyComposioConnection
			if stillMissingAPIKey || !hasAnyConnection {
				self.showQuickSetup()
			}
		}
	}

	private func refreshComposioStatuses() {
		let apps = ["slack", "linear", "notion", "github", "gmail", "googlecalendar"]
		for app in apps {
			settingsEnvironment.integrationService.refreshComposioStatus(for: app)
		}
	}
	
	private func configureVoiceKeyMonitor() {
		// #region agent log
		print("[AppDelegate] configureVoiceKeyMonitor: rawKey=\(settingsEnvironment.preferences.voiceShortcutKeyRaw), rawMode=\(settingsEnvironment.preferences.voiceActivationModeRaw)")
		// #endregion
		
		let shortcutKey = settingsEnvironment.preferences.voiceShortcutKey
		let activationMode = settingsEnvironment.preferences.voiceActivationMode
		
		// #region agent log
		print("[AppDelegate] configureVoiceKeyMonitor: resolved shortcutKey=\(shortcutKey.rawValue), activationMode=\(activationMode.rawValue)")
		// #endregion
		
		configureVoiceKeyMonitorWith(shortcutKey: shortcutKey, activationMode: activationMode)
	}
	
	/// Configure the voice key monitor with explicit values (avoids race conditions when called from Combine)
	private func configureVoiceKeyMonitorWith(shortcutKey: VoiceShortcutKey, activationMode: VoiceActivationMode) {
		// #region agent log
		print("[AppDelegate] configureVoiceKeyMonitorWith: shortcutKey=\(shortcutKey.rawValue), activationMode=\(activationMode.rawValue)")
		// #endregion
		
		voiceKeyMonitor.configure(shortcutKey: shortcutKey, activationMode: activationMode)
		
		// Set up callbacks based on activation mode
		voiceKeyMonitor.onStartRecording = { [weak self] in
			self?.handleVoiceKeyPress()
		}
		
		voiceKeyMonitor.onStopRecording = { [weak self] in
			self?.handleVoiceKeyRelease()
		}
		
		voiceKeyMonitor.onToggle = { [weak self] in
			self?.handleToggleBubble()
		}
		
		voiceKeyMonitor.start()
	}
	
	/// Handle voice key press (hold-to-talk mode)
	private func handleVoiceKeyPress() {
		guard let panelController = panelController else { return }
		
		// Show panel and start recording
		if !panelController.panel.isVisible {
			NSApp.activate(ignoringOtherApps: true)
			panelController.show()
		}
		
		// Post notification to start recording
		NotificationCenter.default.post(name: .voiceKeyDidPress, object: nil)
	}
	
	/// Handle voice key release (hold-to-talk mode)
	private func handleVoiceKeyRelease() {
		// Post notification to stop recording and process
		NotificationCenter.default.post(name: .voiceKeyDidRelease, object: nil)
	}
	
	/// Handle toggle bubble (toggle mode or menu bar click)
	private func handleToggleBubble() {
		guard let panelController = panelController else { return }
		
		let isToggleMode = settingsEnvironment.preferences.voiceActivationMode == .toggle
		
		// #region agent log
		debugLog(hypothesisId: "C", location: "AppDelegate.handleToggleBubble", message: "toggle_bubble_called", data: ["panelIsVisible": "\(panelController.panel.isVisible)", "activationMode": "\(settingsEnvironment.preferences.voiceActivationMode)", "isToggleMode": "\(isToggleMode)"])
		// #endregion
		
		if isToggleMode {
			// In toggle mode: always post notification, VoiceChatBubble handles start/stop logic
			if !panelController.panel.isVisible {
				// Show panel first if not visible
				// #region agent log
				debugLog(hypothesisId: "C", location: "AppDelegate.handleToggleBubble", message: "showing_panel_for_toggle", data: [:])
				// #endregion
				NSApp.activate(ignoringOtherApps: true)
				panelController.show()
			}
			// #region agent log
			debugLog(hypothesisId: "C", location: "AppDelegate.handleToggleBubble", message: "posting_toggle_notification", data: [:])
			// #endregion
			NotificationCenter.default.post(name: .voiceToggleRequested, object: nil)
		} else {
			// Non-toggle mode: just show/hide panel
			if panelController.panel.isVisible {
				// #region agent log
				debugLog(hypothesisId: "C", location: "AppDelegate.handleToggleBubble", message: "hiding_panel", data: [:])
				// #endregion
				panelController.hide()
			} else {
				// #region agent log
				debugLog(hypothesisId: "C", location: "AppDelegate.handleToggleBubble", message: "showing_panel", data: [:])
				// #endregion
				NSApp.activate(ignoringOtherApps: true)
				panelController.show()
			}
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

