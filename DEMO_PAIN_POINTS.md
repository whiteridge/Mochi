# caddyAI Demo: 2 Pain Points (with “Y” + full execution flow)

This doc gives two demoable pain points that map directly to what caddyAI already does today (overlay → local transcription → tool proposals → human confirmation → execution).

---

## Pain point 1 — Context switching kills focus (and action items die in the gaps)

### Y (why this is real)
- **Work is fragmented and interruption-heavy.** A CHI field study observing 24 information workers found work to be highly fragmented, with **57% of working spheres interrupted** and an average of **~11 minutes in a working sphere before switching / interruption**.  
  Source: Mark, Gonzalez, Harris (CHI 2005), “No Task Left Behind? Examining the Nature of Fragmented Work.”  
- **Returning to the original task isn’t instant.** In a UCI Podcast interview, Gloria Mark describes a typical pattern of switching across projects and notes it can take **~25.5 minutes to pick up the original interrupted project**.  
  Source: UCI News podcast transcript (2023).  
- **Interruptions aren’t “free”; they raise stress and force speed-ups.** A CHI paper (“The Cost of Interrupted Work: More Speed and Stress”) documents measurable stress/speed tradeoffs when people are interrupted.  
  Source: Mark, Gudith, Klocke (CHI 2008).

Why it matters for a demo: if the audience agrees that “switching tools breaks flow,” an always-on-top voice overlay that executes actions across apps becomes immediately compelling.

### Demo (what to show)
**Pitch line:** “Don’t leave the conversation—capture the action item and ship it to the right tools in one breath.”

**Prompt to say (good default):**
> “Create a Linear issue titled ‘Login crash on iOS 17.3’ for the Mobile team, then notify #billing-team in Slack.”

**What the audience should see:**
1) Always-on-top bubble appears.  
2) You speak once; transcript appears immediately (local STT).  
3) Status pill: Thinking → Searching (Linear/Slack).  
4) **Confirmation card** for the Linear issue (preview). You click Confirm.  
5) Next confirmation card for the Slack message. You click Confirm.  
6) Success state.

### Full flow of execution (caddyAI)
**UI / local audio**
1) Hold-to-talk key (default `Fn`) triggers recording (`VoiceActivationKeyMonitor` → `VoiceChatBubble.startRecording()`).
2) Release key stops recording (`VoiceChatBubble.stopRecording()`), writes a local clip, then runs local transcription (`ParakeetTranscriptionService.transcribeFile`).
3) Transcript is pushed into the agent state machine (`AgentViewModel.processInputWithThinking`), which shows an immediate “thinking” pill for responsiveness.

**Swift → backend request**
4) `LLMService.sendMessage(...)` POSTs `ChatRequest` to `POST /api/chat` (NDJSON stream).

**Backend orchestration**
5) `AgentService.run_agent(...)` pre-detects likely apps (Linear/Slack), loads Composio tools for the connected accounts, and starts a Gemini chat with tool schemas.
6) `AgentDispatcher` streams events:
   - `thinking` and/or `early_summary` (“I’ll create a ticket in Linear and notify on Slack.”)
   - tool calls for any safe reads needed to resolve IDs (team, channel, etc.)
   - **write actions are intercepted and queued as `proposal` events** (no write happens yet).

**Human-in-the-loop**
7) SwiftUI renders `proposal` as a confirmation card (`ConfirmationCardView`) with Confirm/Cancel.
8) On Confirm, the app sends the exact tool name + args back as `confirmed_tool`.
9) Backend executes only that confirmed tool (`composio_service.execute_tool(...)`), then continues until the next write proposal is ready (repeat).

**Where to point in code**
- Recording → transcription → submit: `caddyAI/VoiceChatBubble.swift`
- “Thinking immediately” + submit: `caddyAI/ViewModels/AgentViewModel+ThinkingFix.swift`
- Streaming request: `caddyAI/Services/LLMService.swift`
- Confirmation → confirmed_tool execution: `caddyAI/ViewModels/AgentViewModel.swift`, `caddyAI/ViewModels/AgentViewModel+Streaming.swift`
- NDJSON endpoint + agent orchestration: `backend/main.py`, `backend/agent_service.py`, `backend/agent/dispatcher.py`

### Success criteria (what to measure)
- “Time-to-action” from voice stop → proposal card displayed.
- “Time-to-done” for the Linear+Slack two-step flow.
- Cancel rate (did people feel safe to confirm?).

---

## Pain point 2 — People don’t trust AI to take actions without oversight (especially across work tools)

### Y (why this is real)
- **Human oversight is a first-class risk control.** NIST’s AI Risk Management Framework explicitly calls out defining roles/responsibilities for *human-AI configurations and oversight* and defining processes for *human oversight* as part of risk management.  
  Source: NIST AI RMF 1.0 (2023), GOVERN 3.2 and MAP 3.5.

Why it matters for a demo: even when an audience loves “automation,” they will ask: “What stops it from posting the wrong message / creating the wrong ticket?” A confirmation card answers that viscerally.

### Demo (what to show)
**Pitch line:** “caddyAI proposes actions, but it never writes to your tools until you approve.”

**Prompt to say (Slack-only, simple + high-trust):**
> “Post ‘We’re shipping at 6pm—please hold deploys’ in #announcements.”

**Show the safety moment:**
1) The assistant proposes the exact Slack action (channel + text) in a confirmation card.
2) You point out: “This is where mistakes would be catastrophic.”
3) Click **Cancel** once to prove nothing is executed. Then run again and click **Confirm**.

Optional variant (stronger): Use a multi-step request and **cancel only the Slack step** after confirming the Linear ticket. This demonstrates partial approval across a plan.

### Full flow of execution (caddyAI)
This is the same pipeline as pain point #1, but the key mechanism is:
- Backend classifies tool calls as **read** vs **write** and only emits `proposal` for writes.
- Writes require an explicit `confirmed_tool` round-trip from the UI before `execute_tool(...)` is called.

**Where to point in code**
- Backend interception logic: `backend/agent/dispatcher.py`
- UI confirm/cancel: `caddyAI/ViewModels/AgentViewModel.swift` + `caddyAI/Views/ConfirmationCardView.swift`
- “Write actions become proposals” is also asserted by tests: `backend/tests/test_scenarios.py`, `backend/tests/test_slack_scenarios.py`

### Success criteria (what to measure)
- % of users who say they’d trust it after seeing preview/confirm.
- % of users who use Cancel (signals control, not failure).

---

## Sources (external)
- Mark, Gonzalez, Harris (CHI 2005): “No Task Left Behind? Examining the Nature of Fragmented Work.”  
  https://dl.acm.org/doi/10.1145/1054972.1055017
- Mark, Gudith, Klocke (CHI 2008): “The cost of interrupted work: more speed and stress.”  
  https://dl.acm.org/doi/10.1145/1357054.1357072
- UCI News (2023): “UCI Podcast: If you can’t pay attention, you’re not alone” (Gloria Mark interview transcript).  
  https://news.uci.edu/2023/05/05/uci-podcast-if-you-cant-pay-attention-youre-not-alone/
- NIST (2023): Artificial Intelligence Risk Management Framework (AI RMF 1.0), NIST AI 100-1.  
  https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=936225
