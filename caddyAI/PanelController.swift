import SwiftUI
import AppKit

// A custom NSPanel that can become the key window.
final class CaddyPanel: NSPanel {
	override var canBecomeKey: Bool { true }
}

final class PanelController {
	private(set) var panel: CaddyPanel
	private var hostingView: NSHostingView<AnyView>
	private var layoutObserver: NSObjectProtocol?

	init(rootView: AnyView) {
		// Create the panel and configure its style
		let frame = NSScreen.main?.visibleFrame ?? .zero
		panel = CaddyPanel(
			contentRect: frame,
			styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered,
			defer: false
		)

		// Configure panel behavior
		panel.level = .floating
		panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
		panel.isFloatingPanel = true
		panel.hidesOnDeactivate = false
		panel.isMovableByWindowBackground = false
		panel.hasShadow = false // Shadow is handled by SwiftUI view

		// Transparent background to let the blur show through
		panel.isOpaque = false
		panel.backgroundColor = .clear

		// Create the SwiftUI view and host it in the panel
		hostingView = NSHostingView(rootView: rootView)
		
		// Ensure hosting view fills the panel
		hostingView.autoresizingMask = [.width, .height]
		hostingView.frame = panel.contentView?.bounds ?? .zero
		panel.contentView = hostingView

		// Note: We no longer listen for layout updates to resize the window
		// The window is now a static full-screen overlay, and SwiftUI handles the positioning.
	}

	deinit {
		if let layoutObserver {
			NotificationCenter.default.removeObserver(layoutObserver)
		}
	}

	private func refreshLayout() {
		hostingView.layoutSubtreeIfNeeded()
	}

	func show() {
		refreshLayout()
		
		// Fade in animation
		panel.alphaValue = 0.0
		panel.orderFrontRegardless()
		
		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.2
			context.timingFunction = CAMediaTimingFunction(name: .easeOut)
			panel.animator().alphaValue = 1.0
		}
		
		// Make the panel the key window to receive keyboard events
		panel.makeKey()
		
		// Ensure the app is active to receive global keyboard events
		NSApp.activate(ignoringOtherApps: true)
		
		NotificationCenter.default.post(name: .voiceChatShouldStartRecording, object: nil)
	}

	func hide() {
		// Fade out animation before hiding
		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.2
			context.timingFunction = CAMediaTimingFunction(name: .easeOut)
			panel.animator().alphaValue = 0.0
		} completionHandler: { [weak self] in
			self?.panel.orderOut(nil)
			// Reset alpha for next show
			self?.panel.alphaValue = 1.0
			// Note: Removed .voiceChatShouldStopSession notification to prevent feedback loop
			// The cancel flow is handled by cancelVoiceSession() directly
		}
	}

	func toggle() {
		if panel.isVisible {
			hide()
		} else {
			show()
		}
	}
}


