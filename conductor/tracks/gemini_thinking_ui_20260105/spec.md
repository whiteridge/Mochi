# Specification: Gemini 3 Thinking Pill & Chat UI Height Cap

## Overview
This feature introduces a visual "Thinking" indicator for the Gemini 3 Flash Thinking model, consistent with existing search status indicators, and includes smooth transition animations. Additionally, it enforces a maximum height constraint on the main chat interface to prevent it from occupying excessive screen space, with smart auto-scrolling behavior.

## Functional Requirements

### 1. Thinking Status Indicator
*   **Behavior:** When the Gemini 3 Flash Thinking model is processing (thinking), a status pill must be displayed.
*   **Component:** Reuse the existing `StatusPillView` (or equivalent shared component used for "Searching Linear", etc.).
*   **Appearance:** Visual style (color, typography, iconography) should align with existing status pills to maintain a cohesive UI.
*   **Animation:**
    *   Transitioning between states (e.g., from "Thinking" to "Searching Linear") must be animated.
    *   **Specific Animation:** The exiting text should slide down and fade out/disappear, while the entering status text slides in from the top.

### 2. Chat UI Height Cap
*   **Constraint:** The main chat window's height must not exceed 2/3 of the active screen's height.
*   **Behavior:**
    *   The window should grow dynamically to fit its content up to the 2/3 limit.
    *   Once the content exceeds the 2/3 height limit, the window stops growing.
    *   **Auto-Scroll Logic:**
        *   While text is being generated/streamed, the view should automatically scroll to the bottom to follow the new content.
        *   **User Interrupt:** If the user manually scrolls up or down during generation, the auto-scrolling must pause/stop to allow the user to read earlier content.

## Non-Functional Requirements
*   **Performance:** UI resizing and animations should be smooth (60fps target).
*   **Responsiveness:** Height calculations should respect different screen sizes/resolutions.

## Acceptance Criteria
*   [ ] A "Thinking" pill appears in the chat interface when the relevant agent state is active.
*   [ ] The status pill transitions between states (Thinking -> Searching) with a "slide down out / slide up in" animation.
*   [ ] The chat window expands with content but stops expanding at approximately 66% of the screen height.
*   [ ] The chat view auto-scrolls to the bottom during text generation when the max height is reached.
*   [ ] Auto-scrolling stops if the user manually interacts with the scroll view (scrolling up/down).
