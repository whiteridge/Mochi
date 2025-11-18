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
		panel = CaddyPanel(
			contentRect: .zero,
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
		panel.hasShadow = true

		// Transparent background to let the blur show through
		panel.isOpaque = false
		panel.backgroundColor = .clear

		// Create the SwiftUI view and host it in the panel
		hostingView = NSHostingView(rootView: rootView)
		panel.contentView = hostingView

		// Give the panel an initial size that matches the SwiftUI view's intended size
		let initialSize = NSSize(width: 500, height: 200)
		panel.setFrame(NSRect(origin: .zero, size: initialSize), display: false)

		layoutObserver = NotificationCenter.default.addObserver(
			forName: .voiceChatLayoutNeedsUpdate,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.refreshLayout()
		}
	}

	deinit {
		if let layoutObserver {
			NotificationCenter.default.removeObserver(layoutObserver)
		}
	}

	private func calculatePanelPosition() {
		guard let screenFrame = NSScreen.main?.visibleFrame else { return }
		let panelSize = panel.frame.size

		// Centered horizontally, offset slightly above the bottom (about 12pt ≈ 1cm visually).
		let newX = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
		let newY = screenFrame.origin.y + 12
		panel.setFrameOrigin(NSPoint(x: newX, y: newY))
	}

	private func refreshLayout() {
		hostingView.layoutSubtreeIfNeeded()
		let fitting = hostingView.fittingSize
		guard fitting.width > 0, fitting.height > 0 else { return }

		let currentOrigin = panel.frame.origin
		panel.setFrame(NSRect(origin: currentOrigin, size: fitting), display: false)

		let contentSize = panel.contentRect(forFrameRect: panel.frame).size
		hostingView.frame = NSRect(origin: .zero, size: contentSize)

		calculatePanelPosition()
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
			NotificationCenter.default.post(name: .voiceChatShouldStopSession, object: nil)
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


