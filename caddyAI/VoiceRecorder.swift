import AVFoundation
import Foundation

@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
	enum RecorderError: LocalizedError {
		case microphoneUnavailable
		case failedToCreateFile
		case failedToStart(Error)
		case noAudioCaptured

		var errorDescription: String? {
			switch self {
			case .microphoneUnavailable:
				return "Unable to access the microphone. Check macOS privacy settings."
			case .failedToCreateFile:
				return "Could not prepare an audio file for recording."
			case .failedToStart(let error):
				return "Recording failed to start: \(error.localizedDescription)"
			case .noAudioCaptured:
				return "No audio was captured. Please try again and speak while recording."
			}
		}
	}

	@Published private(set) var isRecording = false

	private let audioEngine = AVAudioEngine()
	private var audioFile: AVAudioFile?
	private var outputURL: URL?
	private var recordingFormat: AVAudioFormat?
	private var converter: AVAudioConverter?
	private var hasTapInstalled = false

	func startRecording() async throws {
		let inputNode = audioEngine.inputNode
		
		// 1. Get the NATIVE hardware format (Fixes the 16kHz vs 44.1kHz crash)
		let hardwareFormat = inputNode.inputFormat(forBus: 0)
		
		// 2. Safety Check
		guard hardwareFormat.sampleRate > 0 else {
			print("Error: Invalid hardware sample rate (0).")
            throw RecorderError.failedToStart(NSError(domain: "VoiceRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid hardware sample rate (0)."]))
		}
		
		// 3. Cleanup & Tap
		if hasTapInstalled {
			inputNode.removeTap(onBus: 0)
			hasTapInstalled = false
		}
		
		// Setup output file and format (Preserving existing file logic)
		// We convert to a standard Float32 format but keep the sample rate to minimize conversion artifacts
		// or let the converter handle it if we want to enforce 16kHz later (Parakeet handles resampling).
		// Here we stick to hardware rate for recording to file, or 1 channel.
		guard let recordFormat = AVAudioFormat(
			commonFormat: .pcmFormatFloat32,
			sampleRate: hardwareFormat.sampleRate,
			channels: 1,
			interleaved: false
		) else {
			throw RecorderError.failedToCreateFile
		}
		
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("voice-\(UUID().uuidString)")
			.appendingPathExtension("caf")
		
		outputURL = url
		recordingFormat = recordFormat
		
		// Create converter if formats don't match
		if hardwareFormat != recordFormat {
			converter = AVAudioConverter(from: hardwareFormat, to: recordFormat)
			if converter == nil {
				throw RecorderError.failedToCreateFile
			}
		} else {
			converter = nil
		}
		
		// Create the audio file immediately with the recording format
		do {
			audioFile = try AVAudioFile(forWriting: url, settings: recordFormat.settings)
		} catch {
			throw RecorderError.failedToCreateFile
		}
		
		// 4. Install Tap using the EXACT hardware format
		// Do not try to change sample rate here. It causes the crash.
		inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, time in
			guard let self = self else { return }
			self.handleIncomingBuffer(buffer)
		}
		hasTapInstalled = true
		
		// 5. Prepare and Start
		if !audioEngine.isRunning {
			audioEngine.prepare()
			try audioEngine.start()
		}
		
		isRecording = true
		print("VoiceRecorder: Started successfully at \(hardwareFormat.sampleRate)Hz")
	}

	func stopRecording() async throws -> URL {
		guard isRecording else {
			if let url = outputURL {
				outputURL = nil
				return url
			}
			throw RecorderError.noAudioCaptured
		}

		// Stop engine FIRST to prevent new tap callbacks
		audioEngine.stop()
		print("VoiceRecorder: Audio engine stop requested")
		
		// Then remove tap
		if hasTapInstalled {
			audioEngine.inputNode.removeTap(onBus: 0)
			hasTapInstalled = false
			print("VoiceRecorder: Tap removed from input node")
		} else {
			print("VoiceRecorder: No tap installed at stopRecording time")
		}
		
		// Reset the engine
		audioEngine.reset()
		print("VoiceRecorder: Audio engine reset")

		// Ensure the file is fully written and closed
		print("VoiceRecorder: Recorded \(frameCount) frames")
		let capturedFrames = frameCount
		
		// Close the file handle explicitly by storing reference then niling
		let fileToClose = audioFile
		audioFile = nil
		if let fileToClose {
			print("VoiceRecorder: Closing audio file handle for \(fileToClose.url.lastPathComponent)")
		} else {
			print("VoiceRecorder: Audio file already nil before close")
		}
		// Allow time for any pending writes and file close
		try? await Task.sleep(nanoseconds: 100_000_000) // 100ms for safety
		
		// Explicitly release the file reference
		_ = fileToClose
		
		if let url = outputURL {
			logFileMetadata(at: url, context: "post-close pre-guard")
		}

		guard let url = outputURL else {
			isRecording = false
			frameCount = 0
			throw RecorderError.failedToCreateFile
		}
		
		outputURL = nil
		recordingFormat = nil
		converter = nil
		isRecording = false
		frameCount = 0
		
		// Validate that we actually captured audio
		guard capturedFrames > 0 else {
			// Clean up the empty file
			try? FileManager.default.removeItem(at: url)
			throw RecorderError.noAudioCaptured
		}
		
		// Additional safety: verify file exists and has size
		let fileExists = FileManager.default.fileExists(atPath: url.path)
		guard fileExists else {
			throw RecorderError.failedToCreateFile
		}
		
		logFileMetadata(at: url, context: "pre-return")
		
		return url
	}

	private var frameCount = 0
	
	private func handleIncomingBuffer(_ buffer: AVAudioPCMBuffer) {
		guard let audioFile = audioFile,
			  let recordingFormat = recordingFormat else { return }

		do {
			// If formats match, write directly
			if converter == nil {
				try audioFile.write(from: buffer)
				frameCount += Int(buffer.frameLength)
			} else {
				// Convert from hardware format to recording format
				guard let converter = converter else {
					print("VoiceRecorder: Converter unexpectedly nil")
					return
				}
				
				let ratio = recordingFormat.sampleRate / buffer.format.sampleRate
				let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
				
				guard let outputBuffer = AVAudioPCMBuffer(
					pcmFormat: recordingFormat,
					frameCapacity: max(outputFrameCapacity, 1)
				) else {
					print("VoiceRecorder: Failed to create output buffer")
					return
				}
				
				var error: NSError?
				let providedInput = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
				providedInput.initialize(to: false)
				defer {
					providedInput.deinitialize(count: 1)
					providedInput.deallocate()
				}
				
				let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
					if !providedInput.pointee {
						providedInput.pointee = true
						outStatus.pointee = .haveData
						return buffer
					} else {
						outStatus.pointee = .endOfStream
						return nil
					}
				}
				
				let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
				
				if let error = error {
					print("VoiceRecorder conversion error: \(error)")
					return
				}
				
				if status == .haveData && outputBuffer.frameLength > 0 {
					try audioFile.write(from: outputBuffer)
					frameCount += Int(outputBuffer.frameLength)
				}
			}
		} catch {
			print("VoiceRecorder write error: \(error)")
		}
	}
}

private extension VoiceRecorder {
	func logFileMetadata(at url: URL, context: String) {
		do {
			let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
			let size = (attrs[.size] as? NSNumber)?.int64Value ?? -1
			let modDate = attrs[.modificationDate] as? Date ?? .distantPast
			print("VoiceRecorder: [\(context)] file=\(url.lastPathComponent) size=\(size) bytes modified=\(modDate)")
		} catch {
			print("VoiceRecorder: [\(context)] failed to fetch file metadata for \(url.lastPathComponent): \(error)")
		}
	}
}

