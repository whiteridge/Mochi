import SwiftUI

struct StatusPill: View {
	let title: String
	let isOn: Bool
	var action: (() -> Void)? = nil
	
	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(isOn ? Color.green : Color.gray.opacity(0.5))
				.frame(width: 10, height: 10)
			Text(title)
				.font(.caption)
				.foregroundStyle(.primary)
			if let action {
				Button(action: action) {
					Text(isOn ? "Review" : "Enable")
				}
				.buttonStyle(.link)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.fill(Color.secondary.opacity(0.12))
		)
	}
}


