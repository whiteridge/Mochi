//
//  ContentView.swift
//  caddyAI
//
//  Created by Matteo Fari on 15/11/25.
//

import SwiftUI

struct ContentView: View {
	var body: some View {
		ZStack {
			LinearGradient(
				colors: [
					Color(nsColor: .windowBackgroundColor),
					Color(nsColor: .controlBackgroundColor)
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
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
