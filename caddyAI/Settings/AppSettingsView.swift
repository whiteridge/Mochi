import SwiftUI

// MARK: - Main Settings View

struct AppSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	
	var body: some View {
		NavigationSplitView {
			sidebarView
		} detail: {
			detailView
		}
		.onAppear { viewModel.loadPersistedValues() }
	}
	
	private var sidebarView: some View {
		VStack(alignment: .leading, spacing: 0) {
			List(selection: $viewModel.selectedSection) {
				// Main sections
				Label("General", systemImage: "gearshape")
					.tag(SettingsSection.general)
				Label("Integrations", systemImage: "link")
					.tag(SettingsSection.integrations)
				
				// Visual separator
				Section {
					Label("About", systemImage: "info.circle")
						.tag(SettingsSection.about)
				}
			}
			.listStyle(.sidebar)
		}
		.frame(width: 180)
	}
	
	@ViewBuilder
	private var detailView: some View {
		switch viewModel.selectedSection {
		case .general:
			GeneralSettingsView()
		case .integrations:
			IntegrationsSettingsView()
		case .about:
			AboutSettingsView()
		}
	}
}
