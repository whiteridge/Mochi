import AppKit
import Combine
import OSLog
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

/// Monitors keyboard events for voice activation with support for hold-to-talk and toggle modes
final class VoiceActivationKeyMonitor: ObservableObject {
	/// Callback when recording should start
	var onStartRecording: (() -> Void)?
	
	/// Callback when recording should stop
	var onStopRecording: (() -> Void)?
	
	/// Callback for toggle mode (single press toggles state)
	var onToggle: (() -> Void)?
	
	private var globalMonitor: Any?
	private var localMonitor: Any?
	private var isKeyHeld = false
	private var lastKeyDown: TimeInterval = 0
	private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "VoiceActivationKeyMonitor")
	
	// Configuration
	private var shortcutKey: VoiceShortcutKey = .fn
	private var activationMode: VoiceActivationMode = .holdToTalk
	
	init() {
		logger.debug("VoiceActivationKeyMonitor initialized")
	}
	
	/// Update the configuration
	func configure(shortcutKey: VoiceShortcutKey, activationMode: VoiceActivationMode) {
		// #region agent log
		debugLog(hypothesisId: "D", location: "VoiceActivationKeyMonitor.configure", message: "configure_called", data: ["newKey": shortcutKey.rawValue, "newMode": activationMode.rawValue, "currentKey": self.shortcutKey.rawValue, "currentMode": self.activationMode.rawValue])
		// #endregion
		
		let needsRestart = self.shortcutKey != shortcutKey || self.activationMode != activationMode
		self.shortcutKey = shortcutKey
		self.activationMode = activationMode
		
		// #region agent log
		debugLog(hypothesisId: "D", location: "VoiceActivationKeyMonitor.configure", message: "after_assignment", data: ["storedKey": self.shortcutKey.rawValue, "storedMode": self.activationMode.rawValue, "needsRestart": "\(needsRestart)", "hasMonitor": "\(globalMonitor != nil)"])
		// #endregion
		
		if needsRestart && globalMonitor != nil {
			logger.info("Configuration changed, restarting monitor")
			stop()
			start()
		}
	}
	
	/// Start monitoring for keyboard events
	func start() {
		stop() // Ensure we don't install duplicate monitors
		
		logger.info("Starting voice activation key monitoring for \(self.shortcutKey.label, privacy: .public) in \(self.activationMode.label, privacy: .public) mode")
		
		// Global monitor - detects events even when app is not focused
		globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
			self?.handleKeyEvent(event)
		}
		
		// Local monitor - detects events when app is focused
		localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
			self?.handleKeyEvent(event)
			return event
		}
	}
	
	/// Stop monitoring for keyboard events
	func stop() {
		if let globalMonitor {
			NSEvent.removeMonitor(globalMonitor)
			self.globalMonitor = nil
		}
		if let localMonitor {
			NSEvent.removeMonitor(localMonitor)
			self.localMonitor = nil
		}
		isKeyHeld = false
		logger.debug("Voice activation key monitoring stopped")
	}
	
	/// Reset the key held state (call when panel is dismissed via ESC while key might be held)
	func resetKeyState() {
		if isKeyHeld {
			logger.debug("Resetting isKeyHeld state (was true)")
			isKeyHeld = false
		}
	}
	
	deinit {
		stop()
	}
	
	// MARK: - Private Methods
	
	private func handleKeyEvent(_ event: NSEvent) {
		// Check if this is our configured shortcut key
		guard isConfiguredKey(event) else { return }
		
		let isKeyDown = isKeyPressed(event)
		
		switch activationMode {
		case .holdToTalk:
			handleHoldToTalkEvent(isKeyDown: isKeyDown, timestamp: event.timestamp)
		case .toggle:
			handleToggleEvent(isKeyDown: isKeyDown, timestamp: event.timestamp)
		}
	}
	
	private func isConfiguredKey(_ event: NSEvent) -> Bool {
		// For modifier keys, check keyCode
		if event.type == .flagsChanged {
			if event.keyCode == shortcutKey.keyCode {
				return true
			}
			if let alternateCode = shortcutKey.alternateKeyCode, event.keyCode == alternateCode {
				return true
			}
		}
		
		// For Fn key, we need special handling since it doesn't always trigger flagsChanged
		if shortcutKey == .fn {
			// Check if the function modifier flag changed
			if let flag = shortcutKey.modifierFlag {
				return event.modifierFlags.contains(flag) || (!event.modifierFlags.contains(flag) && isKeyHeld)
			}
		}
		
		return false
	}
	
	private func isKeyPressed(_ event: NSEvent) -> Bool {
		guard let flag = shortcutKey.modifierFlag else { return false }
		return event.modifierFlags.contains(flag)
	}
	
	private func handleHoldToTalkEvent(isKeyDown: Bool, timestamp: TimeInterval) {
		if isKeyDown && !isKeyHeld {
			// Key pressed down - start recording
			isKeyHeld = true
			lastKeyDown = timestamp
			logger.debug("Hold-to-talk: Key pressed, starting recording")
			DispatchQueue.main.async { [weak self] in
				self?.onStartRecording?()
			}
		} else if !isKeyDown && isKeyHeld {
			// Key released - stop recording
			isKeyHeld = false
			logger.debug("Hold-to-talk: Key released, stopping recording")
			DispatchQueue.main.async { [weak self] in
				self?.onStopRecording?()
			}
		}
	}
	
	private func handleToggleEvent(isKeyDown: Bool, timestamp: TimeInterval) {
		// #region agent log
		debugLog(hypothesisId: "B", location: "VoiceActivationKeyMonitor.handleToggleEvent", message: "toggle_event_received", data: ["isKeyDown": "\(isKeyDown)", "isKeyHeld": "\(isKeyHeld)", "timestamp": "\(timestamp)"])
		// #endregion
		// In toggle mode, only act on key down
		if isKeyDown && !isKeyHeld {
			isKeyHeld = true
			lastKeyDown = timestamp
			logger.debug("Toggle: Key pressed, toggling state")
			// #region agent log
			debugLog(hypothesisId: "B", location: "VoiceActivationKeyMonitor.handleToggleEvent", message: "toggle_triggered", data: ["action": "calling_onToggle"])
			// #endregion
			DispatchQueue.main.async { [weak self] in
				self?.onToggle?()
			}
		} else if !isKeyDown {
			// #region agent log
			debugLog(hypothesisId: "B", location: "VoiceActivationKeyMonitor.handleToggleEvent", message: "key_released", data: ["wasHeld": "\(isKeyHeld)"])
			// #endregion
			isKeyHeld = false
		}
	}
}
