# Get Started (From Zero)

This guide walks you from a clean machine to a working caddyAI setup (backend + macOS app) and connected integrations.

## 1) Requirements
- macOS with Xcode installed
- Python 3.11
- A Composio account + API key
- A Google Gemini API key

Optional but helpful:
- Homebrew
- A dedicated virtualenv for the backend

## 2) Clone the repo
```
cd ~/Desktop
# If you already have the repo, skip this
# git clone <your-repo-url>
cd caddyAI
```

## 3) Backend setup (FastAPI + Composio)
From the repo root:
```
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Environment variables
Create a `backend/.env` file (do not commit it) or export variables in your shell.
Minimum required:
```
COMPOSIO_API_KEY=your_composio_key
```

Model API key options (pick one):
```
GOOGLE_API_KEY=your_gemini_key
```
or enter the Gemini key in the macOS app Quick Setup (stored locally in Keychain and sent to the backend per request).

Recommended (keeps accounts stable across restarts):
```
COMPOSIO_USER_ID=caddyai-default
```

If you see “Auth config not found” errors, add the app-specific auth config IDs (from the Composio dashboard):
```
COMPOSIO_SLACK_AUTH_CONFIG_ID=...
COMPOSIO_LINEAR_AUTH_CONFIG_ID=...
COMPOSIO_NOTION_AUTH_CONFIG_ID=...
COMPOSIO_GITHUB_AUTH_CONFIG_ID=...
```

If Composio cache permission errors appear, set a writable cache dir:
```
COMPOSIO_CACHE_DIR=/tmp/composio-cache
```

### Run the backend
```
uvicorn main:app --reload
```
Keep this terminal running while you use the app.

## 4) Run the macOS app
From the repo root:
```
open caddyAI.xcodeproj
```
Then run the `caddyAI` scheme. The first time, macOS will ask for microphone access.

On first launch, a minimal Quick Setup window appears. Add your API key (stored locally in Keychain and sent to the backend) and connect at least one integration (Composio OAuth). You can connect additional tools later in Settings.

## 5) Connect integrations
In the app:
- Open Settings > Integrations
- Click “Connect” for Slack, Linear, etc.
- Complete OAuth in the browser
- Return to the app and wait for the status to show Connected

If the button says “Reconnect”, it means the token expired or is inactive. Click it to refresh access.

## 6) Quick smoke test
Try a multi-app prompt:
- “Create a Linear issue named blue bug for the Mobile app team and notify #billing-team in Slack.”

You should see a confirmation card before any write action.

## Troubleshooting
- Backend not running: start `uvicorn main:app --reload` in `backend/`.
- Auth config not found: set the correct `COMPOSIO_*_AUTH_CONFIG_ID` or create the auth config in Composio.
- Multiple connected accounts: remove duplicates in the Composio dashboard (Connected Accounts) and retry.
- Authentication expired: use the “Reconnect” button in Settings > Integrations.
- Rate limits: wait a minute and retry (Gemini quota limits apply).
- Composio cache not writable: set `COMPOSIO_CACHE_DIR` to a writable path.
- Microphone denied: System Settings > Privacy & Security > Microphone.
- `xcodebuild` error: open Xcode and select it in `xcode-select`.

## Tests (optional)
From repo root:
```
# Swift
xcodebuild test -scheme caddyAI -destination 'platform=macOS'

# Python
PYTHONPATH=. COMPOSIO_CACHE_DIR=/tmp/composio-cache pytest
```
