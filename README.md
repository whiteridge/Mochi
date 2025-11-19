# Caddy 🏌️‍♂️

**The Native AI Overlay for macOS.**
*Fast local transcription, beautiful glassmorphism UI, and deep tool integrations.*

## 🏗 Architecture Overview

Caddy is built as a lightweight macOS overlay that bridges the gap between **Voice Input**, **Local Intelligence**, and **Cloud Reasoning**.

*   **Frontend:** Native SwiftUI with extensive use of `NSWindow` transparency and `VisualEffectView` for the "Glass" aesthetic.
*   **Audio Engine:** Local-first transcription using **Parakeet TDT v3 (via FluidAudio)** for zero-latency, private speech-to-text.
*   **Reasoning Engine:** OpenAI (Chat Completions API) serving as the "Brain" to interpret intent and structure tool calls.
*   **Action Layer:** A modular system to execute tasks on external platforms (Linear, Slack, macOS System).

---

## 🚀 Current Status: v0.5 (MVP Core)

- [x] **Floating Interface:** Draggable, "Always on Top" bubble.
- [x] **State Machine:** Seamless transitions (Idle → Recording → Transcribing → Expanded Chat).
- [x] **Local Transcription:** Integrated FluidAudio/Parakeet for fast, offline ASR.
- [x] **UI/UX:** High-fidelity "Dark Glass" aesthetic with physics-based spring animations.
- [x] **Auto-Sizing:** Chat window adapts dynamically to content length.

---

## 🗺 Strategic Roadmap & To-Do

### Phase 1: The Action Engine (Architecture)
*Before adding specific tools, we need the plumbing to handle them.*

- [ ] **Tool Use Protocol (Function Calling):**
    - Implement OpenAI "Tools" schema.
    - Create a `ToolManager` in Swift that maps JSON responses to local Swift functions.
    - *Goal:* LLM outputs `{"tool": "linear_create_issue", "args": {...}}` instead of plain text.
- [ ] **Secure Credential Storage:**
    - Integrate **Keychain** to store API Keys (OpenAI, Linear, Slack) securely.
    - Build a `SettingsView` (General/Integrations tabs) to manage these keys.
- [ ] **Optimistic UI States:**
    - Create the `ActionPreviewPill` (e.g., "Creating Linear Ticket...").
    - Handle success/failure states with transient notifications (Green/Red pills).

### Phase 2: Third-Party Integrations (The "Work" Layer)

#### 🔷 Linear Integration
- [ ] **Authentication:** Personal Access Token (PAT) input in settings.
- [ ] **Action: Create Issue:** `POST /graphQL` to create tickets with title, description, and team assignment.
- [ ] **Action: My Issues:** Fetch and summarize "Issues assigned to me."

#### 💬 Slack Integration
- [ ] **Authentication:** Slack App OAuth flow or User Token.
- [ ] **Action: Send Message:** Send DMs or channel messages via voice.
- [ ] **Action: Set Status:** "Update my status to 'Focus Mode' until 4 PM."

#### 🍎 Native macOS Integrations
- [ ] **Calendar:** Use `EventKit` to read/write calendar events ("Clear my afternoon").
- [ ] **Reminders:** Add items to Apple Reminders.
- [ ] **Deep Linking:** Ability to open specific apps (e.g., `workspace://open?id=123`).

### Phase 3: Context Awareness & Intelligence
- [ ] **Screen Context (Vision):**
    - Capture active window screenshots (with permission).
    - Send to GPT-4o-Vision so Caddy can "see" what you are looking at (e.g., "Explain this code error").
- [ ] **Conversation History:**
    - Implement `SwiftData` or `CoreData` to persist chat logs locally.
    - Allow "Resume Session" after closing the app.

---

## 🛠 Tech Stack & Dependencies

| Component | Tech Choice | Reasoning |
| :--- | :--- | :--- |
| **Language** | Swift 5.9+ | Native performance, strict type safety. |
| **UI Framework** | SwiftUI | Declarative UI, rapid iteration. |
| **Transcription** | FluidAudio (Parakeet) | Fastest local model available for Apple Silicon. |
| **Networking** | URLSession | Zero-dependency networking. |
| **State Mgmt** | ObservableObject | Simple, robust state flow without TCA complexity. |

---

## 📦 Setup & Installation

1.  **Clone the Repo:**
    ```bash
    git clone https://github.com/yourusername/caddy.git
    ```
2.  **Resolve Dependencies:**
    Xcode should automatically fetch `FluidAudio` via SPM.
3.  **Environment Variables:**
    Create a `Secrets.plist` (excluded from Git) or set your `OPENAI_API_KEY` in the app settings after launch.
4.  **Permissions:**
    On first run, grant permissions for:
    - 🎤 Microphone (Audio Capture)
    - ⌨️ Accessibility (Global Hotkeys/Shortcuts)

---

## 🤝 Contributing

*Currently in Alpha.*
Please focus pull requests on **Stability** (Memory leaks, Concurrency) and **Architecture** (Tooling layer) before adding new UI features.