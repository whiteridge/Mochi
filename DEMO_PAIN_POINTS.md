# caddyAI Demo: 2 Flagship Flows (with “Y” + full execution flow)

This doc gives two demoable flows that map directly to what caddyAI does today (overlay → local transcription → tool proposals → human confirmation → execution).

If you want the presenter script + pacing, see `DEMO_PLAYBOOK.md`.

---

## Demo 1 (2 apps) — Linear + Slack: capture action items without switching apps

### Y (why this is real)
- **Work is fragmented and interruption-heavy.** A CHI field study observing 24 information workers found work to be highly fragmented, with **57% of working spheres interrupted** and an average of **~11 minutes** in a working sphere before switching/interrupting.  
  Source: Mark, Gonzalez, Harris (CHI 2005), “No Task Left Behind? Examining the Nature of Fragmented Work.”  
- **Interruptions increase stress and force speed-ups.** A CHI paper (“The Cost of Interrupted Work: More Speed and Stress”) reports measurable stress/speed tradeoffs when people are interrupted.  
  Source: Mark, Gudith, Klocke (CHI 2008).

### Demo prompt
> “Create a Linear issue titled ‘Login crash on iOS 17.3’ for the Mobile team, then notify #billing-team in Slack.”

### What to show
1) Always-on-top bubble appears (you never leave the current app).
2) Speak once; transcript appears immediately (local STT).
3) Status pill: Thinking → Searching (Linear/Slack).
4) Confirmation card 1: Linear issue preview → Confirm.
5) Confirmation card 2: Slack message preview → Confirm.
6) Success state.

---

## Demo 2 (3 apps) — GitHub + Notion + Calendar: turn notification noise into a plan + time block

### Y (why this is real)
- **Work gets “chaotic and fragmented” under constant pings.** Microsoft’s Work Trend Index special report (“Breaking down the infinite workday”) highlights frequent interruptions and a sense of fragmentation for knowledge workers.  
  Source: Microsoft WorkLab / Work Trend Index (2025).  
- **Users trust automation more when they can control/correct it.** Research on “algorithm aversion” found people are more willing to use imperfect algorithms when they can modify outputs (even slightly).  
  Source: Dietvorst, Simmons, Massey (2016), “Overcoming Algorithm Aversion…” (abstract).  
- **Good AI UX requires calibrated trust + user control.** Google PAIR’s People + AI Guidebook emphasizes setting clear mental models, calibrating trust, and providing feedback/control.  
  Source: Google PAIR Guidebook v2.

### Demo prompt
> “Summarize my GitHub notifications, log a digest in Notion, and schedule 30 minutes tomorrow to review.”

### What to show
1) Multi-app pills show GitHub → Notion → Calendar.
2) Confirmation 1 (GitHub): create a digest issue in a triage repo → Confirm.
3) Confirmation 2 (Notion): create a structured daily digest page → Cancel once (prove control).
4) Confirmation 3 (Calendar): block a 30-minute focus window → Confirm.
5) Success state.

---

## Full flow of execution (caddyAI)

**UI / local audio**
1) Hold-to-talk key triggers recording: `caddyAI/VoiceActivationKeyMonitor.swift` → `caddyAI/VoiceChatBubble.swift`
2) Stop recording, normalize clip, transcribe locally: `caddyAI/Transcription/ParakeetTranscriptionService.swift`
3) Transcript is pushed into the agent state machine (sets “thinking” immediately): `caddyAI/ViewModels/AgentViewModel+ThinkingFix.swift`

**Swift → backend request**
4) `LLMService.sendMessage(...)` POSTs `ChatRequest` to `POST /api/chat` (NDJSON stream): `caddyAI/Services/LLMService.swift`

**Backend orchestration**
5) `AgentService.run_agent(...)` loads tools and starts the Gemini chat: `backend/agent_service.py`
6) `AgentDispatcher` streams events and **intercepts writes into proposals**: `backend/agent/dispatcher.py`

**Human-in-the-loop**
7) UI renders a `proposal` as a confirmation card: `caddyAI/Views/ConfirmationCardView.swift`
8) Confirm sends `confirmed_tool` (tool + args + app_id) back to backend: `caddyAI/ViewModels/AgentViewModel+Streaming.swift`
9) Backend executes only the confirmed tool and streams completion: `backend/main.py`

---

## Mock backend mapping (for deterministic demos)
- `test 1` → Linear + Slack demo: `backend/mock_main.py`
- `test 2` → GitHub + Notion + Calendar demo: `backend/mock_main.py`

---

## Sources (external)
- Mark, Gonzalez, Harris (CHI 2005): “No Task Left Behind? Examining the Nature of Fragmented Work.”  
  https://dl.acm.org/doi/10.1145/1054972.1055017
- Mark, Gudith, Klocke (CHI 2008): “The cost of interrupted work: more speed and stress.”  
  https://dl.acm.org/doi/10.1145/1357054.1357072
- Microsoft WorkLab (Work Trend Index): “Breaking down the infinite workday”  
  https://www.microsoft.com/en-us/worklab/work-trend-index/breaking-down-infinite-workday
- Dietvorst, Simmons, Massey (2016): “Overcoming Algorithm Aversion…” (UPenn ScholarlyCommons)  
  https://repository.upenn.edu/handle/20.500.14332/39569
- Google PAIR Guidebook v2 (chapters)  
  https://pair.withgoogle.com/guidebook-v2/chapters

