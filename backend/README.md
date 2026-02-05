# Backend

FastAPI + Composio tooling service used by the macOS app.

## Run
See the repo root `SETUP.md` for the full app + backend walkthrough. For backend-only:

```bash
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export COMPOSIO_API_KEY=your_composio_key
uvicorn main:app --reload
```

Health check:
```bash
curl http://127.0.0.1:8000/health
```

## Env
- `COMPOSIO_API_KEY` (required)
- `COMPOSIO_USER_ID` (recommended)
- `GOOGLE_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` (optional if you enter the key in the macOS app Quick Setup)

Latest curated model IDs (in-app defaults):
- Google Gemini (best performance): `gemini-3-flash-preview`, `gemini-3-pro-preview`
- OpenAI: `gpt-5.2`, `gpt-5-mini`, `gpt-5-nano`
- Anthropic: `claude-sonnet-4-5-20250929`, `claude-opus-4-5-20251101`, `claude-haiku-4-5-20251001`

Local providers (no API key required):
- Ollama: `http://localhost:11434/v1`
- LM Studio: `http://localhost:1234/v1`

## Tests
```bash
pytest
```
Set `CADDYAI_LIVE_TESTS=1` to enable HTTP scenario tests (expects a backend running on `http://localhost:8000`).

## Notes
- Recent UI updates (draggable pill/confirmation card, status pill auto-sizing) are frontend-only.
- The app gates first-run setup on an API key plus at least one Composio integration (OAuth runs through the backend).
