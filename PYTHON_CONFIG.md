# Configure Python Library for PythonKit

## Quick Fix

You need to set the `PYTHON_LIBRARY` environment variable so PythonKit can find your Python installation. The app auto-detects common Python versions (3.13 → 3.12 → 3.11). Use the version that already works on your machine.

### Option 1: Set in Xcode Scheme (Recommended)

1. In Xcode, click on the **caddyAI** scheme next to the play/stop buttons
2. Select **Edit Scheme...**
3. In the left sidebar, select **Run**
4. Go to the **Arguments** tab
5. Under **Environment Variables**, click the **+** button
6. Add:
   - **Name**: `PYTHON_LIBRARY`
   - Choose one of the following values:
     - Python 3.13 (Apple Silicon): `/opt/homebrew/opt/python@3.13/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib`
     - Python 3.13 (Intel): `/usr/local/opt/python@3.13/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib`
     - Python 3.13 (Python.org): `/Library/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib`
     - Python 3.12 (Apple Silicon): `/opt/homebrew/opt/python@3.12/Frameworks/Python.framework/Versions/3.12/lib/libpython3.12.dylib`
     - Python 3.11 (Apple Silicon): `/opt/homebrew/opt/python@3.11/Frameworks/Python.framework/Versions/3.11/lib/libpython3.11.dylib`
   - Optionally also set:
     - **Name**: `PYTHON_VERSION` → **Value**: `3.13` (or your version)
7. Click **Close**
8. Run the app again

### Option 2: Set in Code (Alternative)

Add this to `TranscriptionService.swift` before the `Python.import` calls:

```swift
// Set Python library path before any Python imports
setenv("PYTHON_LIBRARY", "/Library/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib", 1)
setenv("PYTHON_VERSION", "3.13", 1)
```

### Option 3: Set Globally in Terminal (For Testing)

```bash
export PYTHON_LIBRARY=/Library/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib
export PYTHON_VERSION=3.13

# Then run from terminal
open caddyAI.xcodeproj
```

## Verify Installation

After setting the environment variable, run this in Terminal:

```bash
# Check if required packages are installed for your active Python
python3 -c "import sys; import parakeet_mlx, numpy, huggingface_hub; print('OK for', sys.version)"

# If not installed:
python3.11 -m pip install --upgrade pip
python3.11 -m pip install parakeet-mlx numpy huggingface_hub
```

## Troubleshooting

If you still see errors:

1. **Check Python version**: Use the version that already works for you (3.13/3.12/3.11).

2. **Install a matching Python via Homebrew**:
   ```bash
   brew install python@3.13
   # Update PYTHON_LIBRARY to point to 3.13 (see above)
   ```

3. **Enable logging**:
   Add environment variable in Xcode scheme:
   - **Name**: `PYTHON_LOADER_LOGGING`
   - **Value**: `TRUE`
   
   This will show detailed loading information.

## Current Configuration Examples

- Python 3.13 (Python.org): `/Library/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib`
- Python 3.13 (Apple Silicon): `/opt/homebrew/opt/python@3.13/Frameworks/Python.framework/Versions/3.13/lib/libpython3.13.dylib`
- Python 3.12 (Apple Silicon): `/opt/homebrew/opt/python@3.12/Frameworks/Python.framework/Versions/3.12/lib/libpython3.12.dylib`
- Python 3.11 (Apple Silicon): `/opt/homebrew/opt/python@3.11/Frameworks/Python.framework/Versions/3.11/lib/libpython3.11.dylib`

