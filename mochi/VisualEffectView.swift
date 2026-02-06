import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
	var material: NSVisualEffectView.Material
	var blendingMode: NSVisualEffectView.BlendingMode
	var state: NSVisualEffectView.State

	init(
		material: NSVisualEffectView.Material = .hudWindow,
		blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
		state: NSVisualEffectView.State = .active
	) {
		self.material = material
		self.blendingMode = blendingMode
		self.state = state
	}

	func makeNSView(context: Context) -> NSVisualEffectView {
		let view = NSVisualEffectView()
		view.blendingMode = blendingMode
		view.state = state
		view.material = material
		return view
	}

	func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
		nsView.blendingMode = blendingMode
		nsView.state = state
		nsView.material = material
	}
}








