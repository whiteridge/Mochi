import AppKit

final class HotkeyManager {
	var onToggle: (() -> Void)?

	private var globalMonitor: Any?
	private var localMonitor: Any?
	private var lastCommandTap: TimeInterval = 0
	private var tapCount = 0
	private let doubleTapInterval: TimeInterval = 0.35

	func start() {
		stop() // Ensure we don't install duplicate monitors.

		globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			self?.handleCommandEvent(event)
		}

		localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			self?.handleCommandEvent(event)
			return event
		}
	}

	func stop() {
		if let globalMonitor {
			NSEvent.removeMonitor(globalMonitor)
			self.globalMonitor = nil
		}
		if let localMonitor {
			NSEvent.removeMonitor(localMonitor)
			self.localMonitor = nil
		}
	}

	deinit {
		stop()
	}

	private func handleCommandEvent(_ event: NSEvent) {
		// Left Command = 55, Right Command = 54
		guard event.keyCode == 54 || event.keyCode == 55 else { return }

		let isCommandDown = event.modifierFlags.contains(.command)
		guard isCommandDown else { return } // Only count downward taps.

		let now = event.timestamp
		if now - lastCommandTap <= doubleTapInterval {
			tapCount += 1
		} else {
			tapCount = 1
		}
		lastCommandTap = now

		if tapCount >= 2 {
			tapCount = 0
			DispatchQueue.main.async { [weak self] in
				self?.onToggle?()
			}
		}
	}
}
