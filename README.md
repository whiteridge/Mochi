# caddyAI

A native macOS voice overlay: transcribe locally, then propose actions across your tools (with confirmation before any write).

## What you get
- Always-on-top bubble + expandable chat
- Local speech-to-text (FluidAudio / Parakeet)
- Multi-provider model routing (Gemini, OpenAI, Anthropic, or local OpenAI-compatible)
- Default model (recommended): Gemini 3 Flash (`gemini-3-flash-preview`)
- Confirmation cards for tool writes (human-in-the-loop)

## Repo structure
- `caddyAI/`: macOS SwiftUI app
- `backend/`: FastAPI agent + Composio tool layer

## Integrations (via Composio)
Linear, Slack, GitHub, Notion, Gmail, Google Calendar.

## Docs
- `SETUP.md` — run the backend + macOS app
- `KEYBOARD_INTERACTION.md` — hold-to-talk / toggle + shortcut key
- `backend/README.md` — backend-only notes
- `ROADMAP.md` — current priorities
- `DEMO_PAIN_POINTS.md` — demo scripts / talking points
- `TESTS.md` — manual test checklist

## Status
MVP in progress.
