import AVFoundation
import Foundation

final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
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

	@MainActor @Published private(set) var isRecording = false
	@MainActor @Published var normalizedAmplitude: CGFloat = 0.0

	private var audioRecorder: AVAudioRecorder?
	private var outputURL: URL?
	private var meteringTimer: Timer?
	private var isStartingRecording = false

	@MainActor
	func startRecording() async throws {
		// Prevent concurrent calls
		guard !isStartingRecording else {
			print("VoiceRecorder: Already starting recording, ignoring duplicate call")
			return
		}
		isStartingRecording = true
		defer { isStartingRecording = false }
		
		// If already recording, don't start again
		guard !isRecording else {
			print("VoiceRecorder: Already recording, ignoring start call")
			return
		}
		
		// Check microphone permission
		let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
		print("VoiceRecorder: Microphone authorization status: \(micStatus.rawValue) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)")
		
		if micStatus == .notDetermined {
			print("VoiceRecorder: Requesting microphone permission...")
			let granted = await AVCaptureDevice.requestAccess(for: .audio)
			print("VoiceRecorder: Microphone permission granted: \(granted)")
			guard granted else {
				throw RecorderError.microphoneUnavailable
			}
		} else if micStatus != .authorized {
			print("VoiceRecorder: Microphone not authorized!")
			throw RecorderError.microphoneUnavailable
		}
		
		// Stop any existing recorder
		if let existingRecorder = audioRecorder {
			print("VoiceRecorder: Stopping existing recorder")
			existingRecorder.stop()
			audioRecorder = nil
		}
		
		// Create output URL
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("voice-\(UUID().uuidString)")
			.appendingPathExtension("m4a")
		outputURL = url
		
		// Configure recording settings for high quality mono audio
		// Using AAC format which is well-supported and produces smaller files
		let settings: [String: Any] = [
			AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
			AVSampleRateKey: 44100.0,
			AVNumberOfChannelsKey: 1,
			AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
		]
		
		print("VoiceRecorder: Creating recorder with settings: \(settings)")
		
		do {
			let recorder = try AVAudioRecorder(url: url, settings: settings)
			recorder.delegate = self
			recorder.isMeteringEnabled = true
			
			// Prepare and start recording
			guard recorder.prepareToRecord() else {
				print("VoiceRecorder: prepareToRecord() returned false")
				throw RecorderError.failedToStart(NSError(domain: "VoiceRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare recorder"]))
			}
			
			print("VoiceRecorder: Prepared to record, starting...")
			
			guard recorder.record() else {
				print("VoiceRecorder: record() returned false")
				throw RecorderError.failedToStart(NSError(domain: "VoiceRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]))
			}
			
			audioRecorder = recorder
			isRecording = true
			
			// Start metering timer for amplitude visualization
			startMeteringTimer()
			
			print("VoiceRecorder: Recording started successfully to \(url.lastPathComponent)")
			
		} catch {
			print("VoiceRecorder: Failed to create recorder: \(error)")
			throw RecorderError.failedToStart(error)
		}
	}

	@MainActor
	func stopRecording() async throws -> URL {
		// Early return if not recording - prevents spam
		guard isRecording || audioRecorder != nil else {
			// Silent return to prevent log spam
			throw RecorderError.noAudioCaptured
		}
		
		print("VoiceRecorder: stopRecording called, isRecording=\(isRecording)")
		
		// Stop metering timer
		stopMeteringTimer()
		
		guard let recorder = audioRecorder else {
			print("VoiceRecorder: No recorder to stop")
			if let url = outputURL {
				outputURL = nil
				isRecording = false
				normalizedAmplitude = 0.0
				// Check if file exists and has content
				if FileManager.default.fileExists(atPath: url.path) {
					let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
					let size = (attrs?[.size] as? Int64) ?? 0
					if size > 1000 { // More than just header
						return url
					}
				}
				throw RecorderError.noAudioCaptured
			}
			throw RecorderError.failedToCreateFile
		}
		
		let duration = recorder.currentTime
		print("VoiceRecorder: Recording duration: \(duration)s")
		
		recorder.stop()
		audioRecorder = nil
		isRecording = false
		normalizedAmplitude = 0.0
		
		guard let url = outputURL else {
			throw RecorderError.failedToCreateFile
		}
		outputURL = nil
		
		// Validate we captured audio
		guard duration > 0.1 else { // At least 100ms
			print("VoiceRecorder: Recording too short (\(duration)s)")
			try? FileManager.default.removeItem(at: url)
			throw RecorderError.noAudioCaptured
		}
		
		// Verify file exists and has size
		let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
		let size = (attrs?[.size] as? Int64) ?? 0
		print("VoiceRecorder: Recorded file size: \(size) bytes")
		
		guard size > 1000 else { // More than just header
			try? FileManager.default.removeItem(at: url)
			throw RecorderError.noAudioCaptured
		}
		
		print("VoiceRecorder: Recording saved to \(url.lastPathComponent)")
		return url
	}
	
	// MARK: - Metering
	
	private func startMeteringTimer() {
		// Update metering on main thread at 30fps
		meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
			Task { @MainActor in
				self?.updateMetering()
			}
		}
	}
	
	private func stopMeteringTimer() {
		meteringTimer?.invalidate()
		meteringTimer = nil
	}
	
	@MainActor
	private func updateMetering() {
		guard let recorder = audioRecorder, recorder.isRecording else {
			normalizedAmplitude = 0.0
			return
		}
		
		recorder.updateMeters()
		
		// Get average power in decibels (range: -160 to 0)
		let avgPower = recorder.averagePower(forChannel: 0)
		
		// Convert decibels to linear scale (0-1)
		// -160 dB = silence, 0 dB = max
		// We'll use a range of -50 to 0 for more visible response
		let minDb: Float = -50.0
		let maxDb: Float = 0.0
		let clampedPower = max(minDb, min(maxDb, avgPower))
		let normalized = (clampedPower - minDb) / (maxDb - minDb)
		
		// Apply smoothing
		normalizedAmplitude = normalizedAmplitude * 0.6 + CGFloat(normalized) * 0.4
	}
	
	// MARK: - AVAudioRecorderDelegate
	
	nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		print("VoiceRecorder: audioRecorderDidFinishRecording, success=\(flag)")
		Task { @MainActor in
			self.isRecording = false
			self.normalizedAmplitude = 0.0
		}
	}
	
	nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
		print("VoiceRecorder: Encode error: \(error?.localizedDescription ?? "unknown")")
		Task { @MainActor in
			self.isRecording = false
			self.normalizedAmplitude = 0.0
		}
	}
}
