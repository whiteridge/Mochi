# Parakeet MLX ASR Integration Guide

This guide explains how to complete the Parakeet MLX ASR integration for voice transcription.

## Current Status

The audio capture and transcription service infrastructure is in place:
- ✅ `AudioCaptureService.swift` - Captures microphone input and calculates amplitude
- ✅ `TranscriptionService.swift` - Manages transcription state and buffers audio
- ⚠️ `ParakeetMLXModel` - Placeholder implementation needs actual MLX integration

## Setup Steps

### Option 1: Using PythonKit (Recommended for quick integration)

1. **Add PythonKit to your project:**
   - In Xcode, go to File → Add Package Dependencies
   - Add: `https://github.com/pvieito/PythonKit.git`
   - Or add to `Package.swift`:
   ```swift
   dependencies: [
       .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.0")
   ]
   ```

2. **Install Python dependencies:**
   ```bash
   pip3 install mlx mlx-lm
   # Install parakeet-mlx if available, or use the official Parakeet MLX repository
   ```

3. **Update `TranscriptionService.swift`:**
   - Import PythonKit
   - Implement the `ParakeetMLXModel.initialize()` method to load the Python model
   - Implement `transcribe()` to convert Swift Float array to numpy array and run inference

### Option 2: Using MLX Swift (If available)

If MLX Swift bindings become available, you can use them directly without Python bridge.

### Option 3: Local HTTP Server

Run Parakeet MLX as a local HTTP server and make HTTP requests from Swift.

## Implementation Notes

The `ParakeetMLXModel.transcribe()` method currently returns an empty string. You need to:

1. Convert `[Float]` audio buffer to the format expected by Parakeet (numpy array)
2. Ensure sample rate matches (currently 16kHz)
3. Run the model inference
4. Return the transcribed text

## Testing

Once integrated, test with:
- Start the app and press Option+Space
- Speak into the microphone
- Check console for transcription output
- The waveform should animate when audio is detected

