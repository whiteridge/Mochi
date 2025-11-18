# Gemini AI Integration

Quick setup guide for integrating Google Gemini 2.0 Flash into your voice assistant.

---

## Setup (3 Steps)

### 1. Add Package in Xcode

1. Open project → Select target → **Package Dependencies** tab
2. Click **"+"** button
3. Enter URL: `https://github.com/google/generative-ai-swift`
4. Select **Branch: main** → Add Package

### 2. Get API Key

Visit **[aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)**

- Sign in with Google
- Click **"Create API Key"**
- Copy your key (starts with `AIzaSy...`)

**Free Tier:** 10 requests/min, 2M tokens/min

### 3. Configure API Key

**Option A: Environment Variable (Recommended)**

In Xcode:
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. Add: `GEMINI_API_KEY` = `your-key-here`

**Option B: Hardcode in GeminiService.swift**

Uncomment line ~63:
```swift
return "AIzaSy..."  // Paste your key
```

⚠️ Don't commit hardcoded keys to Git!

---

## What's Integrated

### Files Created/Modified

- **`caddyAI/GeminiService.swift`** - NEW: Handles all Gemini API calls
- **`caddyAI/VoiceChatBubble.swift`** - UPDATED: Uses GeminiService
- **`caddyAI/LLMService.swift`** - OLD: Can be deleted

### Features

✅ Uses Gemini 2.0 Flash (experimental, fast)  
✅ Maintains conversation history  
✅ Custom "Caddy" persona  
✅ Error handling  
✅ Singleton pattern (`GeminiService.shared`)

---

## Customization

### Change Model

Edit `GeminiService.swift` line 60:
```swift
name: "gemini-2.0-flash-exp"  // or gemini-1.5-pro
```

**Available:**
- `gemini-2.0-flash-exp` - Latest (default)
- `gemini-1.5-flash` - Stable
- `gemini-1.5-pro` - More capable

### Change Personality

Edit `GeminiService.swift` line 25:
```swift
private let systemInstruction = """
Your custom instructions here...
"""
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Cannot find GeminiService" | Add package (Step 1) |
| "Configure API Key" error | Set `GEMINI_API_KEY` (Step 3) |
| Build fails | Clean: Cmd+Shift+K |
| 404 model error | Update to latest SDK |

### Reset Packages

If issues persist:
1. File → Packages → Reset Package Caches
2. Clean Build Folder (Cmd+Shift+K)
3. Restart Xcode

---

## Resources

- **API Keys:** https://aistudio.google.com/app/apikey
- **Documentation:** https://ai.google.dev/tutorials/swift_quickstart
- **Pricing:** https://ai.google.dev/pricing

---

**That's it! Run your app and test it out.** 🚀
