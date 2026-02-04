# Backend

FastAPI + Composio tooling service used by the macOS app.

## Run
- `pip install -r requirements.txt`
- `uvicorn main:app --reload`

## Env
- `COMPOSIO_API_KEY` (required)
- `GOOGLE_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` (optional if you enter the key in the macOS app Quick Setup)
- optional `COMPOSIO_USER_ID`

Local providers (no API key required):
- Ollama default base URL: `http://localhost:11434/v1`
- LM Studio default base URL: `http://localhost:1234/v1`

## Notes
- Recent UI updates (draggable pill/confirmation card, status pill auto-sizing) are frontend-only.
- The app gates first-run setup on an API key plus at least one Composio integration (OAuth runs through the backend).
