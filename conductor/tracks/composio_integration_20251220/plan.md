# Plan: Seamless Integrations with Composio

## Phase 1: Composio Infrastructure [checkpoint: c0ca10]
Set up the necessary services to interact with the Composio API.

- [x] Task: Set up Composio Backend Service [c0ca10]
    - [x] Subtask: Install Composio SDK in the Python backend.
    - [x] Subtask: Create a service/module to handle Composio authentication and entity management.
    - [x] Subtask: Implement API endpoints for the Swift app to trigger auth flows.

- [x] Task: Swift Composio Client [c0ca10]
    - [x] Subtask: Implement a Swift client to interact with the backend's Composio endpoints.
    - [x] Subtask: Add logic to open the browser for the Composio auth URL.

## Phase 2: UI Refactoring [checkpoint: c0ca10]
Update the Settings UI to use the new connection flow.

- [x] Task: Refactor `IntegrationSettingsView` [c0ca10]
    - [x] Subtask: Replace manual key input fields with "Connect" buttons.
    - [x] Subtask: Add status indicators that query Composio for connection state.

- [x] Task: Update `SettingsViewModel` [c0ca10]
    - [x] Subtask: Implement `connectViaComposio()` logic.
    - [x] Subtask: Handle the refresh of connection states after successful auth.

## Phase 3: Verification & Polish
- [~] Task: Manual Verification of Integration Flow
    - [ ] Subtask: Verify connecting Slack via Composio.
    - [ ] Subtask: Verify connecting Linear via Composio.
- [ ] Task: Phase Completion Verification (Protocol in workflow.md)
