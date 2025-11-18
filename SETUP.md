# CaddyAI Setup Guide

## Prerequisites

1. **Python 3.13 / 3.12 / 3.11** installed on your Mac (use the version that already works)
2. **Xcode** with Swift Package Manager support

## Installation Steps

### 1. Add PythonKit Dependency

In Xcode:
1. Go to **File → Add Package Dependencies...**
2. Enter: `https://github.com/pvieito/PythonKit.git`
3. Click **Add Package**
4. Select **PythonKit** and click **Add Package**

Or add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.0")
]
```

### 2. Install Python Dependencies

Open Terminal and run:

```bash
# Optionally install a matching Python (e.g., 3.13)
brew install python@3.13

# Use your active Python interpreter
python3 -m pip install --upgrade pip
python3 -m pip install parakeet-mlx numpy huggingface_hub
```

Or if you prefer using `uv` (recommended by Parakeet MLX):

```bash
uv add parakeet-mlx numpy
```

### 3. Verify Installation

Test that Parakeet MLX is installed:

```bash
python3 -c "import sys, parakeet_mlx; print('Parakeet MLX installed for', sys.version)"
```

### 4. Build and Run

1. Open the project in Xcode
2. Select your Mac as the target
3. Build and run (⌘R)

## Usage

1. **Activate the panel**: Press **Option+Space** (or the hotkey you configured)
2. **Speak**: The waveform will animate when it detects your voice
3. **Transcription**: The transcribed text will appear in the Xcode console
4. **Deactivate**: Click elsewhere or press the hotkey again

## Troubleshooting

### "PythonKit not available" error
- Make sure PythonKit package is added to your project
- Check that Python 3 is installed: `python3 --version`

### "Failed to load Parakeet model" error
- Ensure you’re using a Python that works on your machine (3.13/3.12/3.11)
- Verify parakeet-mlx is installed: `python3 -m pip list | grep parakeet`
- Try reinstalling: `python3 -m pip install --upgrade parakeet-mlx numpy huggingface_hub`
- Set `PYTHON_LIBRARY` in the Xcode scheme to the matching libpython3.x.dylib (see `PYTHON_CONFIG.md`)

### Microphone not working
- Check System Preferences → Security & Privacy → Microphone
- Grant microphone access to your app
- Restart the app after granting permissions

### Model loading is slow
- First-time model loading downloads the model from Hugging Face (~1-2GB)
- Subsequent launches will be faster as the model is cached
- Model cache location: `~/.cache/huggingface/`

## Model Information

- **Model**: `mlx-community/parakeet-tdt-0.6b-v3`
- **Sample Rate**: 16kHz (automatically converted from your microphone)
- **Streaming**: Real-time transcription with context window of 256 frames

## Next Steps

- The transcription currently appears in the console. You can enhance the UI to display it in the panel.
- Adjust the hotkey in `HotkeyManager.swift` if needed.
- Customize the model by changing the model name in `TranscriptionService.swift`.

