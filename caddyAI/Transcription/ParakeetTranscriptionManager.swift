import Foundation
import FluidAudio
import OSLog

/// Portions of this file are adapted from Hex (MIT License).
/// Source: https://github.com/kitlangton/Hex
actor ParakeetTranscriptionManager {
	static let shared = ParakeetTranscriptionManager()

	private var asrManager: AsrManager?
	private var asrModels: AsrModels?
	private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "ParakeetManager")

	func transcribe(url: URL) async throws -> String {
		let manager = try await ensureManager()
		logger.notice("Submitting clip to Parakeet: \(url.lastPathComponent, privacy: .public)")
		do {
			let result = try await manager.transcribe(url)
			return result.text
		} catch {
			logger.error("Parakeet transcription failed: \(error.localizedDescription, privacy: .public)")
			throw error
		}
	}

	func reset() {
		asrManager = nil
		asrModels = nil
	}

	private func ensureManager() async throws -> AsrManager {
		if let asrManager {
			return asrManager
		}

		logger.notice("Loading Parakeet TDT v3 via FluidAudio")
		do {
			let models = try await AsrModels.downloadAndLoad(version: .v3)
			let manager = AsrManager(config: .init())
			try await manager.initialize(models: models)
			asrModels = models
			asrManager = manager
			logger.notice("Parakeet models ready")
			return manager
		} catch {
			logger.error("Failed to initialize Parakeet: \(error.localizedDescription, privacy: .public)")
			throw error
		}
	}
}


