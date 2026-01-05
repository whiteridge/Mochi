# Plan: Gemini 3 Thinking Pill & Chat UI Height Cap

## Phase 1: Thinking Status Pill Implementation [checkpoint: 0f14738]
Implement the "Thinking" state and associated animations in the status pill component.

- [x] Task: Update `StatusPillView` to support "Thinking" state [0f14738]
    - [x] Subtask: Add `thinking` case to the status enum/state in `StatusPillView.swift`.
    - [x] Subtask: Define visual properties for the "Thinking" state (text, icon, colors).
- [x] Task: Implement State Transition Animation [0f14738]
    - [x] Subtask: Refactor `StatusPillView` to use a `Transition` for content changes.
    - [x] Subtask: Implement "slide down out" for exiting text and "slide up in" for entering text.
- [x] Task: Integrate "Thinking" state in `AgentViewModel` [0f14738]
    - [x] Subtask: Update `AgentViewModel` to emit the "Thinking" state when Gemini 3 Flash Thinking is processing.
- [ ] Task: Conductor - User Manual Verification 'Thinking Status Pill' (Protocol in workflow.md)

## Phase 2: Chat UI Height Constraint [checkpoint: 0f14738]
Enforce the 2/3 screen height limit and implement smart auto-scrolling.

- [x] Task: Apply Height Constraint to Chat UI [0f14738]
    - [x] Subtask: Calculate 2/3 of the active screen height in `CaddyView.swift` (or the main window container).
    - [x] Subtask: Set `frame(maxHeight:)` on the chat history container.
- [x] Task: Implement Smart Auto-Scroll logic [0f14738]
    - [x] Subtask: Update `ChatHistoryView` to automatically scroll to the bottom when new messages arrive.
    - [x] Subtask: Add a mechanism to detect manual user scrolling (up/down).
    - [x] Subtask: Implement logic to pause auto-scroll if manual scrolling is detected, and resume if the user is at the bottom.
- [ ] Task: Conductor - User Manual Verification 'Chat UI Height Constraint' (Protocol in workflow.md)

## Phase 3: Verification & Polish
- [~] Task: Manual Verification of Animation and Height Cap
    - [ ] Subtask: Verify smooth transition from Thinking to Searching.
    - [ ] Subtask: Verify window stops growing at 2/3 screen height.
    - [ ] Subtask: Verify auto-scroll follows generation and pauses on manual scroll.
- [ ] Task: Phase Completion Verification (Protocol in workflow.md)