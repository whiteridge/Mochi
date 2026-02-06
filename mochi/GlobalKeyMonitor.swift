import AppKit
import Combine
import OSLog

/// Monitors global keyboard events for double-tap Command key detection
final class GlobalKeyMonitor: ObservableObject {
	/// Published event when double-tap Command is detected
	@Published var shouldToggleApp = false
	
	/// Callback invoked when double-tap is detected
	var onDoubleTapCommand: (() -> Void)?
	
	private var globalMonitor: Any?
	private var localMonitor: Any?
	private var lastCommandTap: TimeInterval = 0
	private var tapCount = 0
	private let doubleTapInterval: TimeInterval = 0.3
	private let logger = Logger(subsystem: "com.matteofari.mochi", category: "GlobalKeyMonitor")
	
	init() {
		logger.debug("GlobalKeyMonitor initialized")
	}
	
	/// Start monitoring for keyboard events
	func start() {
		stop() // Ensure we don't install duplicate monitors
		
		logger.info("Starting global key monitoring")
		
		// Global monitor - detects events even when app is not focused
		globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			self?.handleFlagsChanged(event)
		}
		
		// Local monitor - detects events when app is focused
		localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			self?.handleFlagsChanged(event)
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
		logger.debug("Global key monitoring stopped")
	}
	
	deinit {
		stop()
	}
	
	// MARK: - Private Methods
	
	private func handleFlagsChanged(_ event: NSEvent) {
		// Key codes: Left Command = 55, Right Command = 54
		guard event.keyCode == 54 || event.keyCode == 55 else { return }
		
		// Only count key down events (when Command becomes active)
		let isCommandDown = event.modifierFlags.contains(.command)
		guard isCommandDown else { return }
		
		let now = event.timestamp
		
		// Check if this tap is within the double-tap interval
		if now - lastCommandTap <= doubleTapInterval {
			tapCount += 1
		} else {
			// Reset count if too much time has passed
			tapCount = 1
		}
		
		lastCommandTap = now
		
		// If we've detected 2 taps, trigger the toggle
		if tapCount >= 2 {
			logger.debug("Double-tap Command detected")
			tapCount = 0
			
			// Dispatch to main thread
			DispatchQueue.main.async { [weak self] in
				self?.shouldToggleApp = true
				self?.onDoubleTapCommand?()
				
				// Reset the published property after a brief delay
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					self?.shouldToggleApp = false
				}
			}
		}
	}
}

