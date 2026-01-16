# Roadmap

This roadmap lists the remaining work to reach a stable v1 of caddyAI. It is organized by priority and covers the macOS app, menu bar companion app, core action pipeline, and the backend tooling service.

## Now (UX, glass, and interaction flow)
- [ ] Finish the compact end-to-end flow: recording -> thinking/searching -> confirmation cards -> success.
- [ ] Remove the transcribing state from the UI and replace with compact clarification bubbles when needed.
- [ ] Finalize glass contrast for both Clear and Regular modes to match the Tahoe-style references (light/dark aware, readable over mixed backgrounds).
- [ ] Ensure all pills and bubbles use the same palette rules (thinking/searching, recording, assistant bubble, error bubble).
- [ ] Make confirmation card layout consistent and compact (header pills, app icons, multi-card sequencing).
- [ ] Smooth morphing animations across state transitions with consistent timing.

## Next (Core actions and confirmation pipeline)
- [ ] Implement and stabilize tool-use protocol + ToolManager routing.
- [ ] Add action preview states and a queue for multi-step tool plans.
- [ ] Per-action confirmation controls (approve, cancel) with clear feedback.
- [ ] Improve error/clarification handling to keep the UI compact.

## Integrations
- [ ] Complete Linear and Slack action flows (create, update, fetch).
- [ ] Standardize app icon + name mapping for all supported tools.

## Settings and onboarding
- [ ] Verify Keychain-backed token storage, migration, and reset flows.
- [ ] Finish onboarding for API keys and integrations with success/failure feedback.
- [ ] Align menu bar app settings UI with main app behavior.
 - [ ] Ensure MenuBarApp features stay in sync with the main app (appearance, shortcuts, onboarding).

## Backend (FastAPI + tooling)
- [ ] Observability for tool calls and action plans (logging, diagnostics).
- [ ] Harden integration auth flows and token refresh.

## Quality and release readiness
- [ ] XCTest coverage for UI state machine and confirmation flow.
- [ ] Backend pytest coverage for tool routing and integration adapters.
- [ ] Performance tuning for audio capture and animation smoothness.
- [ ] Documentation updates in README, SETUP, and keyboard behavior.
