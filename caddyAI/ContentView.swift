//
//  ContentView.swift
//  caddyAI
//
//  Created by Matteo Fari on 15/11/25.
//

import SwiftUI

struct ContentView: View {
	@Environment(\.colorScheme) private var colorScheme

	private var backgroundGradient: LinearGradient {
		let colors: [Color] = colorScheme == .dark
			? [
				Color(red: 0.06, green: 0.07, blue: 0.08),
				Color(red: 0.1, green: 0.12, blue: 0.14)
			]
			: [
				Color(red: 0.96, green: 0.97, blue: 0.98),
				Color(red: 0.88, green: 0.9, blue: 0.93)
			]
		return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
	}

	var body: some View {
		ZStack {
			backgroundGradient
			.ignoresSafeArea()

			VoiceChatBubble()
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
		}
	}
}

#Preview {
	ContentView()
		.frame(width: 800, height: 600)
}
