# Backend

FastAPI + Composio tooling service used by the macOS app.

## Run
- `pip install -r requirements.txt`
- `uvicorn main:app --reload`

## Env
- `GOOGLE_API_KEY`, `COMPOSIO_API_KEY` (optional `COMPOSIO_USER_ID`)

## Notes
- Recent UI updates (draggable pill/confirmation card, status pill auto-sizing) are frontend-only.
