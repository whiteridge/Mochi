# caddyAI

Native macOS overlay for fast local transcription and tool-assisted actions.

## Highlights
- Always-on-top bubble with chat expansion
- Local-first speech-to-text (FluidAudio/Parakeet)
- Gemini-powered intent parsing and tool calls via local backend
- Action confirmations for Linear, Slack, GitHub, Notion, Gmail, Google Calendar

## Implemented apps
- Linear
- Slack
- GitHub
- Notion
- Gmail
- Google Calendar

## Architecture
- UI: SwiftUI + NSWindow transparency for the glass effect
- Audio: FluidAudio / Parakeet TDT v3
- Reasoning: Google Gemini 2.5 Flash (tools)
- Backend: FastAPI agent + Composio tool layer
- Actions: SwiftUI proposal and confirmation cards

## Status
v0.5 MVP core. Action engine and integrations are in progress.

## Roadmap
See `ROADMAP.md` for current priorities and progress.

## Tech
- Swift 5.9+, SwiftUI
- URLSession networking
- ObservableObject state
- Python 3.11, FastAPI, Composio, google-genai

## Setup
- macOS app: open `caddyAI.xcodeproj` and run the `caddyAI` scheme
- Backend: `cd backend && pip install -r requirements.txt && uvicorn main:app --reload`
- Env: set `GOOGLE_API_KEY` and `COMPOSIO_API_KEY` (optional `COMPOSIO_USER_ID`)

## Contributing
Focus on stability and the action/tooling layer.
