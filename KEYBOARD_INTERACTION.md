# Keyboard Interaction Model

## Overview

The VoiceChatBubble app now supports native keyboard interactions similar to Spotlight or Raycast.

## Features

### 1. Global Double-Tap Command (⌘⌘)

The app monitors for double-tapping the Command key globally (works even when the app is not focused).

**Behavior:**
- **When app is hidden/idle**: Double-tap ⌘ → Activates the app, shows the bubble, and starts recording immediately
- **When app is visible**: Double-tap ⌘ → Hides the app and cancels the current session

**Implementation:**
- `GlobalKeyMonitor.swift` - Monitors `NSEvent.flagsChanged` events globally
- Detects both left (keyCode 55) and right (keyCode 54) Command keys
- Double-tap interval: 0.3 seconds

### 2. Contextual Enter Key

The Enter key performs different actions based on the current app state:

| State | Enter Key Action |
|-------|-----------------|
| **Recording** | Stops recording and transitions to transcription |
| **Chat** | Sends the typed message to the LLM |
| **Transcribing** | No action (ignored) |
| **Idle** | No action (ignored) |

**Implementation:**
- `.onKeyPress(.return)` modifier on the main view
- `handleEnterKey()` method with state-based switch logic
- TextField also has `.onSubmit` for natural text field behavior

### 3. Window Focus Management

When the double-tap Command is triggered:
- `NSApp.activate(ignoringOtherApps: true)` ensures the app comes to the front
- `panel.makeKey()` makes the panel the key window to receive keyboard events
- Input field or recording bubble immediately gets keyboard focus

## Architecture

```
GlobalKeyMonitor (ObservableObject)
  ├─ Monitors global keyboard events
  └─ Publishes double-tap events
  
AppDelegate
  ├─ Creates and manages GlobalKeyMonitor
  ├─ Handles toggle logic (show/hide)
  └─ Manages PanelController
  
PanelController
  ├─ Shows/hides the panel
  ├─ Manages window positioning
  └─ Ensures keyboard focus on show
  
VoiceChatBubble
  ├─ Handles Enter key based on state
  ├─ Listens to start/stop notifications
  └─ Manages recording and chat lifecycle
```

## Usage

### For Users

1. **Start a voice session**: Double-tap ⌘ (Command key)
2. **Stop recording**: Press Enter or click the stop button
3. **Send a typed message**: Type in the text field and press Enter
4. **Hide the app**: Double-tap ⌘ again

### For Developers

**Adding new keyboard shortcuts:**

```swift
.onKeyPress(.escape) { _ in
    // Handle Escape key
    return .handled
}
```

**Modifying double-tap interval:**

Edit `GlobalKeyMonitor.swift`:
```swift
private let doubleTapInterval: TimeInterval = 0.3 // Adjust as needed
```

## Files Modified/Created

- ✅ `GlobalKeyMonitor.swift` - New file for global keyboard monitoring
- ✅ `VoiceChatBubble.swift` - Added Enter key handling
- ✅ `AppDelegate.swift` - Updated to use GlobalKeyMonitor
- ✅ `PanelController.swift` - Enhanced focus management

## Testing

To test the keyboard interactions:

1. **Double-tap Command**: 
   - Try with left Command key
   - Try with right Command key
   - Try when app is hidden
   - Try when app is visible

2. **Enter Key**:
   - Press Enter while recording
   - Press Enter in chat with text input
   - Press Enter in chat without text input
   - Press Enter while transcribing (should be ignored)

3. **Focus Management**:
   - Verify the app comes to front when double-tapping ⌘
   - Verify the text field is ready for input after recording
   - Verify Enter key works in the small "pill" recording bubble

## Notes

- The TextField's `.onSubmit` and the global `.onKeyPress` work together without conflict
- SwiftUI's responder chain ensures the TextField captures Enter when focused
- The global handler catches Enter when no other view consumes it
- `sendManualMessage()` already guards against empty input, so it's safe to call anytime

