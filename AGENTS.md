# Repository Guidelines

## Project Structure & Module Organization
- `caddyAI/`: primary macOS SwiftUI app (views, view models, services, audio, settings).
- `Shared/`: shared integration/core models used across targets.
- `macos/MenuBarApp/`: menu bar companion app and settings UI.
- Tests: `caddyAITests/`, `caddyAIUITests/`, and `macos/MenuBarAppTests/` for XCTest; `backend/tests/` for pytest.
- Assets: `caddyAI/Assets.xcassets` and `macos/MenuBarApp/Assets.xcassets`.
- `backend/`: FastAPI + Composio tooling service (Python 3.11).
- Reference docs: `README.md`, `SETUP.md`, `KEYBOARD_INTERACTION.md`.

## Build, Test, and Development Commands
- macOS app (Xcode):
  - `open caddyAI.xcodeproj` to run/debug the `caddyAI` scheme.
  - `xcodebuild -scheme caddyAI -configuration Debug build` to build from CLI.
  - `xcodebuild test -scheme caddyAI -destination 'platform=macOS'` to run Swift tests.
- Backend (from `backend/`):
  - `pip install -r requirements.txt` to install deps.
  - `uvicorn main:app --reload` to run the API server locally.
  - `pytest` to run backend tests.

## Coding Style & Naming Conventions
- Swift: tabs for indentation, UpperCamelCase types, lowerCamelCase properties, file name matches the main type, SwiftUI views end with `View`.
- Python: 4-space indentation, snake_case modules/functions, PascalCase classes, `test_*.py` for tests.
- No repository-wide formatter/linter is enforced; match surrounding style.

## Testing Guidelines
- XCTest for macOS targets; add unit tests in `caddyAITests/` and UI tests in `caddyAIUITests/` or `macos/MenuBarAppTests/`.
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
