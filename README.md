# mochi

Native macOS voice overlay for work: local transcription, smart tool actions, and confirmation before writes.

## Why mochi
- Fast voice-to-action flow on desktop
- Local speech-to-text with Parakeet (via FluidAudio)
- Gemini models (default: Gemini 3 Flash, `gemini-3-flash-preview`)
- Human-in-the-loop confirmations for write actions

## Quick start
1. Start backend:
   ```bash
   cd backend
   python3.11 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   export COMPOSIO_API_KEY=your_key
   uvicorn main:app --reload
   ```
2. Run macOS app:
   ```bash
   open mochi.xcodeproj
   ```

Full setup: `SETUP.md`

## Integrations
Linear, Slack, GitHub, Notion, Gmail, Google Calendar (via Composio).

## Project layout
- `mochi/` macOS SwiftUI app
- `backend/` FastAPI agent + tool layer
- `Shared/` shared models/integration code

## Docs
- `SETUP.md` setup guide
- `backend/README.md` backend notes
- `ABOUT.md` project story

## Contributing
Issues and PRs are welcome.
