# Plan: Secure Credential Storage & Initial Setup

## Phase 1: Keychain Infrastructure [checkpoint: fdaf838]
Establish the secure storage layer using macOS Keychain Services.

- [x] Task: Create Keychain Service Wrapper [c66f3ea]
    - [ ] Subtask: Write unit tests for `KeychainService` (save, read, delete, update).
    - [ ] Subtask: Implement `KeychainService` using `Security.framework`.
    - [ ] Subtask: Verify tests pass.

- [x] Task: Create Credential Manager [314a1db]
    - [ ] Subtask: Write tests for `CredentialManager` (abstraction over Keychain for specific keys like `openaiKey`, `linearKey`).
    - [ ] Subtask: Implement `CredentialManager` with published properties for SwiftUI binding.
    - [ ] Subtask: Verify tests pass.

- [x] Task: Conductor - User Manual Verification 'Keychain Infrastructure' (Protocol in workflow.md) [fdaf838]

## Phase 2: Settings UI [checkpoint: 44366a1]
Build the user interface for managing credentials within the app's preferences.

- [x] Task: Create Settings View Structure [d44a2cf]
    - [x] Subtask: Create `SettingsView.swift` with a tab structure (General, Integrations).
    - [x] Subtask: Implement `IntegrationSettingsView` for API key management.

- [x] Task: Connect UI to Data [d44a2cf]
    - [x] Subtask: Bind `IntegrationSettingsView` input fields to `CredentialManager`.
    - [x] Subtask: Add logic to mask keys and handle "Save/Update" actions.
    - [x] Subtask: Manual verification: Run app and test saving/reading keys via UI.

- [x] Task: Conductor - User Manual Verification 'Settings UI' (Protocol in workflow.md) [44366a1]

## Phase 3: Onboarding Flow
Implement the first-run experience to guide users through setup.

- [ ] Task: Create Onboarding Views
    - [ ] Subtask: Create `OnboardingContainerView` to manage the page flow.
    - [ ] Subtask: Create `WelcomeView`, `APIKeyInputView` (reusable), and `CompletionView`.

- [ ] Task: Implement App Launch Logic
    - [ ] Subtask: Modify `CaddyApp.swift` (or main entry point) to check for existence of OpenAI key.
    - [ ] Subtask: Present `OnboardingContainerView` as a sheet or window if key is missing.
    - [ ] Subtask: Ensure seamless transition to main app state (`ContentView`) upon completion.

- [ ] Task: Conductor - User Manual Verification 'Onboarding Flow' (Protocol in workflow.md)
