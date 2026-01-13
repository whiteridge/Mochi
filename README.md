# caddyAI

Native macOS overlay for fast local transcription and tool-assisted actions.

## Highlights
- Always-on-top bubble with chat expansion
- Local-first speech-to-text (FluidAudio/Parakeet)
- OpenAI-powered intent parsing and tool calls (planned)
- Modular action layer for integrations

## Architecture
- UI: SwiftUI + NSWindow transparency for the glass effect
- Audio: FluidAudio / Parakeet TDT v3
- Reasoning: OpenAI Chat Completions (tools)
- Actions: Swift tool manager (Linear, Slack, macOS)

## Status
v0.5 MVP core. Action engine and integrations are in progress.

## Roadmap
- Tool-use protocol + ToolManager
- Keychain-backed settings
- Action preview states
- Linear, Slack, and macOS actions

## Tech
- Swift 5.9+, SwiftUI
- URLSession networking
- ObservableObject state

## Setup
See `SETUP.md` for step-by-step instructions.

## Docs
- `KEYBOARD_INTERACTION.md` - keyboard model and shortcuts
- `SETUP.md` - setup wizard and integrations

## Contributing
Focus on stability and the action/tooling layer.
