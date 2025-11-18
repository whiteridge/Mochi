import SwiftUI

@main
struct HexBubbleApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	var body: some Scene {
		Settings {
			EmptyView()
		}
	}
}

