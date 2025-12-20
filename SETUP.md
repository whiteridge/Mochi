# caddyAI Quick Setup

Use this guide to go from a fresh install to a working caddyAI with API access and integrations.

## 1) Open Settings
- Click the caddyAI tray icon (speech bubbles) in the macOS menu bar.
- Choose **Settings…**. The left sidebar lists: General, API & Accounts, Integrations, Setup.

## 2) General
- Pick an **Accent Color** and **Appearance** (Follow system / Light / Dark).
- Check **Permissions**:
  - Microphone: click **Enable** if off.
  - Accessibility: click **Enable** to open System Settings and grant access.

## 3) API & Accounts
- Paste your LLM **API key**.
- If self-hosted, add the **Base URL**.
- Click **Save**, then **Test connection** to confirm the key is stored (kept locally in Keychain).
- You can reset everything with **Reset setup data**.

## 4) Integrations
- **Slack**
  - Create a Slack app → OAuth & Permissions → generate a **Bot token (xoxb…)** with the scopes you need (e.g., `chat:write`, `channels:read`).
  - Paste your token and click **Connect**. Use **Test Slack** to verify; nothing is preloaded—only your workspace/token is used.
  - Tokens stay local in Keychain. Use **Disconnect** to clear.
- **Linear**
  - In Linear, go to **Settings → API** to generate a **Personal API key**.
  - Team key is your team URL slug (e.g., `mobile` from `https://linear.app/acme/team/mobile`).
  - Paste key + team key, click **Connect**, then **Test Linear**. No sample projects are preloaded; only your account data is used when connected. (Team/project pickers are intentionally hidden until real API fetching is wired.)
  - Keys stay local in Keychain. Use **Disconnect** to clear.

## 5) Setup (Onboarding)
- Run the **Setup** wizard to ensure API + integrations are in place.
- You can **Skip for now** and return later; a reminder stays until setup is complete.

## Quick Checklist
- Tray icon visible; Settings opens.
- Accent color/theme set; microphone & accessibility permissions granted.
- API key saved and tested.
- Slack connected and tested.
- Linear connected and tested.
- Onboarding marked complete.

