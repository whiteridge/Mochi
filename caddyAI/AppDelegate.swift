import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var panelController: PanelController?
	private let globalKeyMonitor = GlobalKeyMonitor()

	func applicationDidFinishLaunching(_ notification: Notification) {
		panelController = PanelController(rootView: AnyView(VoiceChatBubble()))

		// Set up double-tap Command key handler
		globalKeyMonitor.onDoubleTapCommand = { [weak self] in
			self?.handleDoubleCommandTap()
		}
		globalKeyMonitor.start()
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


