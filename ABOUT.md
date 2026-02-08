# About the project

mochi is a native macOS voice overlay: you talk, it transcribes on-device, then it proposes actions across your tools with a confirmation step before anything that writes data.

## Inspiration

I wanted a voice assistant that feels *native* to the desktop: lightweight, always available, and fast enough to use in the middle of real work. Most importantly, I didn’t want a “black box” that can silently send messages, create tickets, or modify documents. mochi is built around the idea that voice can be a great interface for intent, but humans should stay in control of side effects.

## What I learned

- **Latency is a product feature.** Every step—audio capture, speech-to-text, model calls, and UI updates—adds up. Gemini 3 Flash stood out here: consistently fast enough to keep the conversation feeling live, so I learned to treat the whole pipeline like a performance budget.
- **Tool use needs UX, not just prompting.** It’s not enough to *tell* a model to be careful; you need UI primitives that make “preview → confirm → execute” the default path.
- **Gemini 3 Flash is great at practical tool orchestration.** It’s quick to map intent to structured tool calls, handles multi-step tool flows cleanly, and stays responsive while doing it.
- **Provider-agnostic design pays off.** Supporting multiple LLM providers (and local OpenAI-compatible servers) pushed me to be explicit about schemas, streaming, and error handling.

## How I built it

The system is intentionally split into two parts:

1. **macOS app (SwiftUI):** an always-on-top bubble + expandable chat UI, audio capture, and local speech-to-text.
2. **Backend (FastAPI):** an agent service that routes to an LLM provider and uses Composio to talk to integrations like Linear, Slack, GitHub, Notion, Gmail, and Google Calendar.

At a high level, the speech part is the usual ASR objective: given audio $x(t)$, find the most likely text $\hat{y}$:

$$
\hat{y} = \arg\max_y p(y \mid x(t)).
$$

Once there’s text, the backend plans tool calls. Any “write” action (send a message, create an issue, update a doc, etc.) is queued for explicit confirmation. Conceptually:

$$
\operatorname{execute}(a) =
\begin{cases}
1, & \neg\operatorname{write}(a) \\
\operatorname{userConfirms}(a), & \operatorname{write}(a)
\end{cases}
$$

## Challenges I faced

- **Audio preprocessing:** making transcription reliable meant handling resampling, mono conversion, and short clips without introducing noticeable delay.
- **Streaming + state:** merging streaming model output with a UI that can switch between “thinking”, “proposing”, and “awaiting confirmation” is trickier than a simple request/response chat.
- **Integration edge cases:** real tools have messy failure modes (expired auth, missing permissions, rate limits), so the agent and UI need to fail *gracefully* and guide recovery.
