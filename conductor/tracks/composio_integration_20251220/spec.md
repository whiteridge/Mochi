# Specification: Seamless Integrations with Composio

## 1. Overview
This track replaces the manual API key entry for integrations (Slack, Linear, etc.) with a unified, seamless authentication flow using Composio. Users will be able to connect their favorite tools via a single interface without manually searching for and copying API keys.

## 2. Goals
- **Unified Auth:** Use Composio to handle OAuth and API key management for multiple integrations.
- **Improved UX:** Implement a "Connect" button that triggers the Composio auth flow (OAuth popup).
- **Service Integration:** Update the backend/service layer to utilize Composio tokens or the Composio SDK for executing actions.

## 3. Detailed Requirements

### 3.1. Composio Service Wrapper
- **Integration:** Add Composio SDK (Python for backend, or REST API for frontend).
- **Session Management:** Handle Composio session creation and management.
- **Entity Linking:** Link user accounts/entities in Caddy to Composio entities.

### 3.2. Settings UI Update
- **Refactor:** Remove manual `TextField` inputs for Slack and Linear keys.
- **New UI:** Add "Connect with Composio" buttons for each supported integration.
- **Status Mapping:** Map Composio connection status to the `IntegrationState` in the app.

### 3.3. Auth Flow
- **Trigger:** Clicking "Connect" opens the Composio authentication URL in the default browser.
- **Callback:** Handle the redirection/callback once the user authorizes the application in Composio.

## 4. Technical Constraints
- **Platform:** macOS (SwiftUI)
- **Backend:** Python (to handle Composio SDK calls if needed)
- **API:** Composio REST API / SDK
