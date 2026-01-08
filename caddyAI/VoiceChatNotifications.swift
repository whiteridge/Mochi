import Foundation

extension Notification.Name {
	static let voiceChatShouldStartRecording = Notification.Name("voiceChatShouldStartRecording")
	static let voiceChatShouldStopSession = Notification.Name("voiceChatShouldStopSession")
	static let voiceChatLayoutNeedsUpdate = Notification.Name("voiceChatLayoutNeedsUpdate")
	static let voiceChatShouldDismissPanel = Notification.Name("voiceChatShouldDismissPanel")
	
	// Voice activation key events (hold-to-talk)
	static let voiceKeyDidPress = Notification.Name("voiceKeyDidPress")
	static let voiceKeyDidRelease = Notification.Name("voiceKeyDidRelease")
	
	// Voice activation toggle event
	static let voiceToggleRequested = Notification.Name("voiceToggleRequested")
}

