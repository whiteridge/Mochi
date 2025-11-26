import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var panelController: PanelController?
	private let globalKeyMonitor = GlobalKeyMonitor()
	private var dismissObserver: NSObjectProtocol?

	func applicationDidFinishLaunching(_ notification: Notification) {
		panelController = PanelController(rootView: AnyView(VoiceChatBubble()))

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
}


