# Repository Guidelines

## Working Agreements
- Prefer small diffs. If a change is large, propose a plan first.
- Don’t add new dependencies (Swift packages / Python deps) without asking.
- Always search the documentation first when updating behavior or setup.

### Swift (macOS)
- After Swift code changes, run:
  - `xcodebuild test -scheme mochi -destination 'platform=macOS'`
- `swift test` applies only if a SwiftPM `Package.swift` is added.

### Python backend
- After Python code changes, run:
  - `pytest`
- Ruff, formatting, and mypy checks are not configured in this repo today; run them only if those tools are added.

### Docker
- Docker is not set up in this repo. If Docker Compose is added, run commands via:
  - `docker compose exec backend <cmd>` (Python)
  - `docker compose exec <service> <cmd>` (other services)
- Example:
  - `docker compose exec backend pytest`
  - `docker compose exec backend ruff check .`

## Project Structure & Module Organization
- `mochi/`: primary macOS SwiftUI app (views, view models, services, audio, settings).
- `Shared/`: shared integration/core models used across targets.
- `macos/MenuBarApp/`: menu bar companion app and settings UI.
- Tests: `mochiTests/`, `mochiUITests/`, and `macos/MenuBarAppTests/` for XCTest; `backend/tests/` for pytest.
- Assets: `mochi/Assets.xcassets` and `macos/MenuBarApp/Assets.xcassets`.
- `backend/`: FastAPI + Composio tooling service (Python 3.11).
- Reference docs: `README.md`, `SETUP.md`, `backend/README.md`.

## Build, Test, and Development Commands
- macOS app (Xcode):
  - `open mochi.xcodeproj` to run/debug the `mochi` scheme.
  - `xcodebuild -scheme mochi -configuration Debug build` to build from CLI.
  - `xcodebuild test -scheme mochi -destination 'platform=macOS'` to run Swift tests.
- Backend (from `backend/`):
  - `pip install -r requirements.txt` to install deps.
  - `uvicorn main:app --reload` to run the API server locally.
  - `pytest` to run backend tests.

## Coding Style & Naming Conventions
- Swift: tabs for indentation, UpperCamelCase types, lowerCamelCase properties, file name matches the main type, SwiftUI views end with `View`.
- Python: 4-space indentation, snake_case modules/functions, PascalCase classes, `test_*.py` for tests.
- No repository-wide formatter/linter is enforced; match surrounding style.

## Testing Guidelines
- XCTest for macOS targets; add unit tests in `mochiTests/` and UI tests in `mochiUITests/` or `macos/MenuBarAppTests/`.
- pytest + pytest-asyncio for backend flows in `backend/tests/`.
- Add or update tests when changing tool routing, integrations, or stateful UI logic.

## Commit & Pull Request Guidelines
- Use short, present-tense summaries; optional scope prefixes exist (e.g., `feat(backend): ...`).
- Keep commits focused; avoid mixing UI and backend changes without a clear rationale.
- PRs should include a concise description, testing notes, and screenshots for UI changes; link related issues when applicable.

## Security & Configuration Tips
- Backend expects `GOOGLE_API_KEY` and `COMPOSIO_API_KEY`; optional `COMPOSIO_USER_ID` and `COMPOSIO_*_AUTH_CONFIG_ID` values control integrations.
- The macOS app stores tokens in Keychain via the settings flow; follow `SETUP.md`.
- Never commit `.env` files or secrets.
