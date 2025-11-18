import AVFoundation
import Foundation
import OSLog

protocol TranscriptionService {
	func transcribeFile(at url: URL) async throws -> String
}

enum ParakeetTranscriptionError: LocalizedError {
	case emptyTranscript

	var errorDescription: String? {
		switch self {
		case .emptyTranscript:
			return "Parakeet returned an empty transcription. Please try again."
		}
	}
}

final class ParakeetTranscriptionService: TranscriptionService {
	private let manager: ParakeetTranscriptionManager
	private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "ParakeetService")

	init(manager: ParakeetTranscriptionManager = .shared) {
		self.manager = manager
	}

	func transcribeFile(at url: URL) async throws -> String {
		logger.notice("Preparing audio clip for Parakeet: \(url.lastPathComponent, privacy: .public)")

		let normalizedClip = try ParakeetAudioNormalizer.normalizeClip(at: url, logger: logger)
		let paddedClip = try ParakeetClipPadder.ensureMinimumDuration(url: normalizedClip.url, logger: logger)

		defer {
			paddedClip.cleanup()
			normalizedClip.cleanup()
		}

		let rawText = try await manager.transcribe(url: paddedClip.url)
		let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			throw ParakeetTranscriptionError.emptyTranscript
		}
		return trimmed
	}
}

// MARK: - Audio Preparation

private struct PreparedClip {
	let url: URL
	private let cleanupURL: URL?

	init(url: URL, cleanupURL: URL?) {
		self.url = url
		self.cleanupURL = cleanupURL
	}

	func cleanup() {
		guard let cleanupURL else { return }
		try? FileManager.default.removeItem(at: cleanupURL)
	}
}

private enum ParakeetAudioNormalizer {
	private static let targetSampleRate: Double = 16_000
	private static let targetChannels: AVAudioChannelCount = 1
	private static let targetFormat = AVAudioFormat(
		commonFormat: .pcmFormatFloat32,
		sampleRate: targetSampleRate,
		channels: targetChannels,
		interleaved: false
	)

	enum NormalizerError: LocalizedError {
		case converterUnavailable
		case bufferAllocationFailed

		var errorDescription: String? {
			switch self {
			case .converterUnavailable:
				return "Unable to convert audio into the format Parakeet expects."
			case .bufferAllocationFailed:
				return "Failed to allocate buffer while converting audio."
			}
		}
	}

	static func normalizeClip(at url: URL, logger: Logger) throws -> PreparedClip {
		logger.notice("Opening source file for normalization: \(url.lastPathComponent, privacy: .public)")
		
		// Verify file exists and has content
		guard FileManager.default.fileExists(atPath: url.path) else {
			logger.error("Source file does not exist: \(url.path, privacy: .public)")
			throw NormalizerError.converterUnavailable
		}
		
		let sourceFile: AVAudioFile
		do {
			sourceFile = try AVAudioFile(forReading: url)
		} catch {
			logger.error("Failed to open audio file: \(error.localizedDescription, privacy: .public)")
			throw error
		}
		
		let format = sourceFile.processingFormat
		logger.notice("Source format: \(format.sampleRate, format: .fixed(precision: 0))Hz, \(format.channelCount) ch, \(String(describing: format.commonFormat))")
		
		guard let targetFormat else {
			throw NormalizerError.converterUnavailable
		}

		let alreadyNormalized = format.sampleRate == targetSampleRate &&
			format.channelCount == targetChannels &&
			format.commonFormat == .pcmFormatFloat32

		if alreadyNormalized {
			logger.notice("File already normalized, skipping conversion")
			return PreparedClip(url: url, cleanupURL: nil)
		}

		guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
			logger.error("Failed to create audio converter from \(String(describing: format)) to \(String(describing: targetFormat))")
			throw NormalizerError.converterUnavailable
		}

		let destinationURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("parakeet-normalized-\(UUID().uuidString).caf")

		if FileManager.default.fileExists(atPath: destinationURL.path) {
			try FileManager.default.removeItem(at: destinationURL)
		}

		// Create output file with the target format's settings
		guard let settings = targetFormat.settings as? [String: Any] else {
			logger.error("Failed to get settings from target format")
			throw NormalizerError.converterUnavailable
		}
		
		let outputFile = try AVAudioFile(forWriting: destinationURL, settings: settings)
		let bufferCapacity: AVAudioFrameCount = 4096

		logger.notice("Converting clip to 16kHz mono Float32 for Parakeet")
		logger.notice("Source file has \(sourceFile.length) frames")

		while true {
			guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else {
				logger.error("Failed to allocate input buffer")
				throw NormalizerError.bufferAllocationFailed
			}
			
			do {
				try sourceFile.read(into: inputBuffer)
			} catch {
				logger.error("Failed to read from source file: \(error.localizedDescription, privacy: .public)")
				throw error
			}

			if inputBuffer.frameLength == 0 {
				logger.notice("Finished reading source file")
				break
			}

			let ratio = targetSampleRate / format.sampleRate
			let convertedCapacity = AVAudioFrameCount(ceil(Double(inputBuffer.frameLength) * ratio))
			guard let convertedBuffer = AVAudioPCMBuffer(
				pcmFormat: targetFormat,
				frameCapacity: max(convertedCapacity, 1)
			) else {
				throw NormalizerError.bufferAllocationFailed
			}

			var providedInput = false
			let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
				if providedInput {
					outStatus.pointee = .endOfStream
					return nil
				}
				providedInput = true
				outStatus.pointee = .haveData
				return inputBuffer
			}

			var error: NSError?
			converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

			if let error {
				throw error
			}

			if convertedBuffer.frameLength > 0 {
				try outputFile.write(from: convertedBuffer)
			}
		}

		return PreparedClip(url: destinationURL, cleanupURL: destinationURL)
	}
}

private enum ParakeetClipPadder {
	private static let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "ParakeetPadder")

	enum PadderError: LocalizedError {
		case unsupportedFormat
		case bufferAllocationFailed

		var errorDescription: String? {
			switch self {
			case .unsupportedFormat:
				return "Parakeet can only pad mono Float32 recordings."
			case .bufferAllocationFailed:
				return "Unable to allocate buffer while preparing Parakeet audio."
			}
		}
	}

	/// Portions of this helper are adapted from Hex (MIT License).
	/// Source: https://github.com/kitlangton/Hex
	static func ensureMinimumDuration(
		url: URL,
		minimumDuration: TimeInterval = 1.5,
		logger: Logger = logger
	) throws -> PreparedClip {
		let audioFile = try AVAudioFile(forReading: url)
		let format = audioFile.processingFormat
		let duration = Double(audioFile.length) / format.sampleRate

		logger.debug("Parakeet clip duration=\(duration, format: .fixed(precision: 3))s")

		guard duration < minimumDuration else {
			return PreparedClip(url: url, cleanupURL: nil)
		}

		guard format.commonFormat == .pcmFormatFloat32 else {
			throw PadderError.unsupportedFormat
		}

		let minimumFrames = AVAudioFrameCount((minimumDuration * format.sampleRate).rounded(.up))

		guard
			let readBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: minimumFrames),
			let paddedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: minimumFrames)
		else {
			throw PadderError.bufferAllocationFailed
		}

		try audioFile.read(into: readBuffer)
		let framesRead = min(readBuffer.frameLength, minimumFrames)

		guard
			let sourceChannels = readBuffer.floatChannelData,
			let paddedChannels = paddedBuffer.floatChannelData
		else {
			throw PadderError.unsupportedFormat
		}

		let channelCount = Int(format.channelCount)
		for channel in 0..<channelCount {
			let destination = paddedChannels[channel]
			let source = sourceChannels[channel]
			if framesRead > 0 {
				destination.assign(from: source, count: Int(framesRead))
			}
			let padCount = Int(minimumFrames - framesRead)
			if padCount > 0 {
				destination.advanced(by: Int(framesRead)).initialize(repeating: 0, count: padCount)
			}
		}

		paddedBuffer.frameLength = minimumFrames

		let paddedURL = url.deletingLastPathComponent()
			.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-parakeet-padded.wav")

		if FileManager.default.fileExists(atPath: paddedURL.path) {
			try FileManager.default.removeItem(at: paddedURL)
		}

		let paddedFile = try AVAudioFile(forWriting: paddedURL, settings: audioFile.fileFormat.settings)
		try paddedFile.write(from: paddedBuffer)

		logger.notice(
			"Padded Parakeet clip from \(duration, format: .fixed(precision: 3))s to \(minimumDuration, format: .fixed(precision: 3))s"
		)

		return PreparedClip(url: paddedURL, cleanupURL: paddedURL)
	}
}


