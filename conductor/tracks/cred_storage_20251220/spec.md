# Specification: Secure Credential Storage & Initial Setup

## 1. Overview
This track focuses on establishing the security foundation for Caddy by implementing a secure credential storage system using macOS Keychain. It also includes the creation of a user-facing Settings interface to manage these credentials and an Onboarding flow to guide new users through the initial configuration of OpenAI, Slack, and Linear API keys.

## 2. Goals
- **Secure Storage:** Safely store sensitive API keys (OpenAI, Linear, Slack) using the macOS Keychain Services.
- **Management UI:** Provide a dedicated "Settings" view where users can view (masked), update, and delete their API keys.
- **Onboarding Experience:** Create a "Welcome" flow for first-time users that prompts them to enter the necessary credentials to get started.

## 3. Detailed Requirements

### 3.1. Keychain Wrapper
- **Functionality:** Create a Swift wrapper around `Security.framework` to handle generic password items.
- **Operations:** Support `save`, `read`, `update`, and `delete` operations for string-based secrets.
- **Service Name:** Use a consistent service identifier (e.g., `com.caddy.keys`) for all items.
- **Error Handling:** Gracefully handle cases where keys don't exist or access is denied.

### 3.2. Settings Interface (`SettingsView`)
- **Structure:** A tabbed interface or a dedicated section for "Integrations".
- **Fields:** Input fields for:
    - OpenAI API Key
    - Linear API Key
    - Slack User Token / Bot Token
- **State:**
    - Display keys as masked strings (e.g., `sk-....1234`).
    - Provide a "Reveal" toggle (optional) or just an "Edit" button.
    - Show validation status (e.g., "Valid" green checkmark) if possible (validation logic can be basic for now).

### 3.3. Onboarding Flow
- **Trigger:** Show this view automatically on app launch if no OpenAI key is found in the Keychain.
- **Steps:**
    1.  **Welcome:** Brief intro to Caddy.
    2.  **Intelligence:** Prompt for OpenAI API Key (Required).
    3.  **Integrations:** Prompt for Linear and Slack keys (Optional, can be skipped).
    4.  **Completion:** "You're all set!" screen that transitions to the main app.

## 4. Technical Constraints
- **Language:** Swift 5.9+
- **UI:** SwiftUI
- **Security:** Must use standard macOS Keychain APIs; do not store keys in `UserDefaults` or `plist` files.
