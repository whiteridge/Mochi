import Testing
@testable import caddyAI

struct AgentStatusTests {
    @Test func testAgentStatusLabels() {
        let thinking = AgentStatus.thinking(text: "Thinking...")
        #expect(thinking.labelText == "Thinking...")
        #expect(thinking.appName == "thinking")
        
        let searching = AgentStatus.searching(appName: "Slack")
        #expect(searching.labelText == "Searching Slack...")
        #expect(searching.appName == "Slack")
        
        let transcribing = AgentStatus.transcribing
        #expect(transcribing.labelText == "Transcribing...")
        #expect(transcribing.appName == nil)
    }
}
