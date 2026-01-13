# Keyboard Interaction

Shortcuts are designed to feel like Spotlight or Raycast.

## Global double-tap Command (Cmd Cmd)
- Hidden/idle: show the bubble and start recording
- Visible: hide the app and cancel the session

Implementation notes:
- `GlobalKeyMonitor.swift` listens to `NSEvent.flagsChanged`.
- Left Cmd keyCode 55 and right Cmd keyCode 54 are supported.
- Double-tap interval is 0.3 seconds (`doubleTapInterval`).

## Enter key behavior

| State | Enter action |
| --- | --- |
| Recording | Stop recording and move to transcription |
| Chat | Send the typed message |
| Transcribing | No action |
| Idle | No action |

Implementation notes:
- `.onKeyPress(.return)` on the main view calls `handleEnterKey()`.
- The text field also uses `.onSubmit` for natural input behavior.

## Focus behavior
- The app activates with `NSApp.activate(ignoringOtherApps: true)`.
- The panel becomes key with `panel.makeKey()` to accept input.

## Files
- `GlobalKeyMonitor.swift`
- `VoiceChatBubble.swift`
- `AppDelegate.swift`
- `PanelController.swift`
