* **Test Case 01 (Schedule a Meeting with Constraints):** Verify Caddy successfully checks calendar availability and books a meeting based on specific constraints (e.g., "when she's busy").
* **Test Case 02 (Contextual Bug Reporting):** Test Caddy's ability to scrape the current webpage URL and context to generate an accurate bug ticket in a project management tool.
* **Test Case 03 (Tone-Specific Email Drafting):** Ensure Caddy generates email drafts that accurately match the requested sentiment (e.g., "confident," "polite").
* **Test Case 04 (Multi-Step Cross-App Automation):** Verify Caddy can execute compound commands that require actions in multiple apps simultaneously (e.g., posting to Slack and creating a Calendar event).
* **Test Case 05 (Calendar Availability Sync):** Test if Caddy accurately detects and reports real-time availability or conflicts from the connected calendar API.
* **Test Case 06 (Ambiguity Handling):** Verify that Caddy asks for clarification or correctly infers context when given vague commands (e.g., "Schedule a meeting with her").
* **Test Case 07 (Context Retention):** Test if Caddy understands follow-up commands using pronouns (e.g., "Send *it*") referring to an object created in the previous step.
* **Test Case 08 (Noise & Interruption Handling):** Ensure Caddy distinguishes between direct commands and background conversation or noise.
* **Test Case 09 (Impossible Scheduling):** Verify that Caddy flags errors or asks for confirmation when requested to schedule events at invalid times or non-existent dates.
* **Test Case 10 (Missing Permissions):** Test that Caddy provides an appropriate error message or prompt when attempting to access a disconnected third-party application (e.g., Slack or Linear).
* **Test Case 11 (First-run Setup Gate):** Verify Quick Setup appears when the API key or integrations are missing, and that it closes after both are set.
