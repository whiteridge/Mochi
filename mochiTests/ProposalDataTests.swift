import Testing
@testable import mochi

struct ProposalDataTests {
	@Test func testSlackChannelDisplayPreferredOverRawId() {
		let proposal = ProposalData(
			tool: "SLACK_SEND_MESSAGE",
			args: [
				"channelDisplay": "#general (C0A101WM3T4)",
				"channelName": "#general",
				"channel": "C0A101WM3T4",
			]
		)

		#expect(proposal.channelDisplay == "#general (C0A101WM3T4)")
		#expect(proposal.channel == "#general (C0A101WM3T4)")
	}

	@Test func testSlackChannelFallsBackToChannelNameThenRawId() {
		let namedProposal = ProposalData(
			tool: "SLACK_SEND_MESSAGE",
			args: [
				"channelName": "#social",
				"channel": "C08RU6X11UJ",
			]
		)
		#expect(namedProposal.channel == "#social")

		let rawProposal = ProposalData(
			tool: "SLACK_SEND_MESSAGE",
			args: [
				"channel": "C08RU6X11UJ",
			]
		)
		#expect(rawProposal.channel == "C08RU6X11UJ")
	}
}
