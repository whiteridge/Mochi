import AVFoundation
import Combine

final class AudioCaptureService: NSObject, ObservableObject {
	@Published var normalizedAmplitude: CGFloat = 0.0
	@Published var hasMicPermission: Bool = false
	
	private var audioEngine: AVAudioEngine?
	private var inputNode: AVAudioInputNode?
	private var converter: AVAudioConverter?
	private var isCapturing = false
	private var pendingStartRequest = false
	private var targetFormat: AVAudioFormat?
	
	// Parakeet requires 16kHz mono audio
	private let targetSampleRate: Double = 16000.0
	private let targetChannels: AVAudioChannelCount = 1
	
	override init() {
		super.init()
		requestMicrophonePermission()
	}
	
	private func requestMicrophonePermission() {
		AVAudioApplication.requestRecordPermission { granted in
			DispatchQueue.main.async {
				if !granted {
					print("Microphone permission denied")
					self.hasMicPermission = false
					self.pendingStartRequest = false
				} else {
					self.hasMicPermission = true
					if self.pendingStartRequest {
						self.pendingStartRequest = false
						self.startCapture()
					}
				}
			}
		}
	}
	
	func startCapture() {
		guard !isCapturing else { return }
		
		// Ensure microphone permission is granted before starting
		if !hasMicPermission {
			pendingStartRequest = true
			requestMicrophonePermission()
			print("Awaiting microphone permission before starting capture...")
			return
		}
		
		audioEngine = AVAudioEngine()
		guard let audioEngine = audioEngine else { return }
		
		inputNode = audioEngine.inputNode
		guard let inputNode = inputNode else { return }
		let hardwareFormat = inputNode.inputFormat(forBus: 0)
		
		// Create target format: 16kHz mono
		guard let targetFormat = AVAudioFormat(
			commonFormat: .pcmFormatFloat32,
			sampleRate: targetSampleRate,
			channels: targetChannels,
			interleaved: false
		) else {
			print("Failed to create target audio format")
			return
		}
		self.targetFormat = targetFormat
		self.converter = nil
		
		// Install tap to capture audio
		let bufferSize: AVAudioFrameCount = 4096
		inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, _ in
			self?.processAudioBuffer(buffer)
		}
		
		do {
			try audioEngine.start()
			isCapturing = true
		} catch {
			print("Failed to start audio engine: \(error)")
		}
	}
	
	func stopCapture() {
		guard isCapturing else { return }
		
		inputNode?.removeTap(onBus: 0)
		audioEngine?.stop()
		audioEngine?.reset()
		audioEngine = nil
		inputNode = nil
		isCapturing = false
		
		DispatchQueue.main.async {
			self.normalizedAmplitude = 0.0
		}
	}
	
	private var audioBufferCallback: (([Float]) -> Void)?
	
	func setAudioBufferCallback(_ callback: @escaping ([Float]) -> Void) {
		audioBufferCallback = callback
	}
	
	private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
		guard let channelData = buffer.floatChannelData else { return }
		
		// Calculate amplitude from original buffer for visualization
		let channelDataValue = channelData.pointee
		let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
			.map { channelDataValue[$0] }
		
		// Calculate RMS (Root Mean Square) for amplitude
		let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
		
		// Normalize to 0-1 range and apply some smoothing
		let normalized = min(1.0, max(0.0, rms * 10.0))
		
		DispatchQueue.main.async {
			// Smooth the amplitude changes
			self.normalizedAmplitude = self.normalizedAmplitude * 0.7 + CGFloat(normalized) * 0.3
		}
		
		// Convert to target format (16kHz mono)
		guard let targetFormat else { return }
		
		if converter == nil || converter?.inputFormat.sampleRate != buffer.format.sampleRate || converter?.inputFormat.channelCount != buffer.format.channelCount {
			converter = AVAudioConverter(from: buffer.format, to: targetFormat)
		}
		
		guard let converter else { return }
		
		let inputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate)
		guard let convertedBuffer = AVAudioPCMBuffer(
			pcmFormat: converter.outputFormat,
			frameCapacity: max(inputFrameCapacity, 1)
		) else { return }
		
		var error: NSError?
		let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
			outStatus.pointee = .haveData
			return buffer
		}
		
		if status == .haveData, let convertedChannelData = convertedBuffer.floatChannelData {
			let convertedData = convertedChannelData.pointee
			let convertedArray = stride(from: 0, to: Int(convertedBuffer.frameLength), by: convertedBuffer.stride)
				.map { convertedData[$0] }
			
			// Send converted audio data to transcription service
			audioBufferCallback?(convertedArray)
		} else if let error {
			print("Audio conversion error: \(error)")
		}
	}
}

