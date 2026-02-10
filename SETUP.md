# Setup

mochi has two parts:
1) `backend/` (FastAPI + Composio)
2) `mochi/` (macOS SwiftUI app)

## Requirements
- macOS + Xcode
- Python 3.11
- A Composio API key (`COMPOSIO_API_KEY`)
- A Gemini API key (`GOOGLE_API_KEY`)

Model used by mochi:
- Google Gemini: `gemini-3-flash-preview`

## Quick start

### 1) Run the backend
```bash
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# required
export COMPOSIO_API_KEY=your_composio_key
export GOOGLE_API_KEY=your_gemini_key

uvicorn main:app --reload
```
Keep this terminal running while you use the app.

### 2) Run the macOS app
```bash
cd ..
open mochi.xcodeproj
```
Run the `mochi` scheme. The first time, macOS will ask for microphone access.
The voice hotkey defaults to `Fn` and is configurable in Settings.

## Backend environment variables (optional)
Put these in `backend/.env` (never commit it) or export them in your shell.

Recommended:
```bash
COMPOSIO_USER_ID=mochi-default
```

If Composio says “Auth config not found”, add auth config IDs from the Composio dashboard:
```bash
COMPOSIO_SLACK_AUTH_CONFIG_ID=...
COMPOSIO_LINEAR_AUTH_CONFIG_ID=...
COMPOSIO_NOTION_AUTH_CONFIG_ID=...
COMPOSIO_GITHUB_AUTH_CONFIG_ID=...
```

If Composio cache permissions fail:
```bash
COMPOSIO_CACHE_DIR=/tmp/composio-cache
```

## First run (Quick Setup)
If you’re missing your Gemini key or any Composio connection, a Quick Setup window appears.
- Add your Gemini API key (stored in Keychain).
- Connect at least one integration (Settings → Integrations).

## Smoke test
Say:
- “Create a Linear issue titled ‘Login crash on iOS 17.3’ for the Mobile team, then notify #billing-team in Slack.”

You should see a confirmation card before any write action.

## Troubleshooting
- Backend not running: start `uvicorn main:app --reload` from `backend/`.
- “Agent service not initialized”: check `COMPOSIO_API_KEY`.
- “Auth config not found”: set the correct `COMPOSIO_*_AUTH_CONFIG_ID` in the backend env.
- Integration shows “Reconnect”: token expired or inactive → click Reconnect in Settings → Integrations.
- Microphone denied: System Settings → Privacy & Security → Microphone.
- Xcode CLI issues: open Xcode once, then select it via `xcode-select`.

## Tests (optional)
```bash
xcodebuild test -scheme mochi -destination 'platform=macOS'
cd backend && pytest
```
