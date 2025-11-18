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
		guard !isRecording else { return }
		
		// Ensure clean state
		frameCount = 0
		
		// Aggressively clean up any existing state
		if audioEngine.isRunning {
			print("VoiceRecorder: Stopping running engine")
			audioEngine.stop()
			// Give the audio system time to fully stop
			try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
		}
		
		// Remove any existing taps before resetting
		if hasTapInstalled {
			print("VoiceRecorder: Removing existing taps")
			audioEngine.inputNode.removeTap(onBus: 0)
			hasTapInstalled = false
		}
		
		print("VoiceRecorder: Resetting audio engine")
		audioEngine.reset()
		
		// Critical: Give the audio system time to fully reset and release resources
		// This prevents the "there already is a thread" error (HALC_IOThread error)
		// Especially important on first run when audio hardware is initializing
		try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
		
		// Get a fresh reference to inputNode after reset
		let inputNode = audioEngine.inputNode
		let hardwareFormat = inputNode.inputFormat(forBus: 0)
		print("VoiceRecorder: Hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount) ch")

		guard hardwareFormat.channelCount > 0 else {
			throw RecorderError.microphoneUnavailable
		}

		// Use a standard format for recording that CAF files support well
		// We'll convert to 16kHz mono later for Parakeet
		guard let recordFormat = AVAudioFormat(
			commonFormat: .pcmFormatFloat32,
			sampleRate: hardwareFormat.sampleRate,
			channels: min(hardwareFormat.channelCount, 1),
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

		inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
			self?.handleIncomingBuffer(buffer)
		}
		hasTapInstalled = true

		audioEngine.prepare()
		do {
			try audioEngine.start()
			isRecording = true
			print("VoiceRecorder: Audio engine started successfully")
			print("VoiceRecorder: Recording format: \(recordFormat.sampleRate)Hz, \(recordFormat.channelCount) ch")
			print("VoiceRecorder: Hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount) ch")
			
			// Give the audio system time to actually start capturing audio data
			// This is especially important on the first recording attempt when
			// the audio hardware is initializing for the first time
			try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
			print("VoiceRecorder: Ready to capture audio")
		} catch {
			print("VoiceRecorder: Failed to start audio engine: \(error)")
			inputNode.removeTap(onBus: 0)
			hasTapInstalled = false
			audioFile = nil
			throw RecorderError.failedToStart(error)
		}
	}

	func stopRecording() async throws -> URL {
		guard isRecording else {
			if let url = outputURL {
				outputURL = nil
				return url
			}
			throw RecorderError.noAudioCaptured
		}

		if hasTapInstalled {
			audioEngine.inputNode.removeTap(onBus: 0)
			hasTapInstalled = false
		}
		audioEngine.stop()
		audioEngine.reset()

		// Ensure the file is fully written and closed
		print("VoiceRecorder: Recorded \(frameCount) frames")
		let capturedFrames = frameCount
		audioFile = nil
		
		// Give the file system a moment to finalize the write
		try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

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
				let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
					outStatus.pointee = .haveData
					return buffer
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

