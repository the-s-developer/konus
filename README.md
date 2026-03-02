# Konus

macOS menu bar dictation app powered by Whisper. A fast, native alternative to Apple Dictation that uses your own Whisper server for speech-to-text.

## Features

- **Menu bar app** — lives in the status bar, no dock icon
- **Right Cmd toggle** — single tap to start/stop dictation, double tap for Enter
- **Whisper STT** — uses faster-whisper-large-v3 for high quality transcription
- **Streaming** — real-time transcription as you speak
- **Multi-language** — auto-detects language, works with mixed Turkish/English
- **Universal paste** — types into any focused app via CGEvent (Cmd+V)
- **Voice commands** — say "gönder" for Enter, "bitir" to stop

## Requirements

- macOS 14+ (Sonoma)
- Swift 5.9+
- A running Whisper server (see below)
- Accessibility permission (for keyboard simulation)

## Quick Start

### 1. Start the Whisper Server

You need a machine with an NVIDIA GPU:

```bash
cd whisper
docker compose up -d
```

This runs `faster-whisper-server` with `Systran/faster-whisper-large-v3` on port 8010.

### 2. Build & Run

```bash
cd Konus
swift build -c release
```

### 3. Package as .app

```bash
mkdir -p Konus.app/Contents/MacOS Konus.app/Contents/Resources
cp .build/release/Konus Konus.app/Contents/MacOS/
cp Info.plist Konus.app/Contents/  # see below
cp -R Konus.app /Applications/
```

### 4. Grant Permissions

- **Microphone** — prompted on first launch
- **Accessibility** — System Settings → Privacy & Security → Accessibility → add Konus

### 5. Use

- **Right ⌘ (single tap)** — start/stop dictation
- **Right ⌘ (double tap)** — press Enter
- **Menu bar icon** — click for status, start/stop, quit

## Configuration

Default settings in `KonusManager.swift`:

| Setting | Default | Description |
|---------|---------|-------------|
| `whisperURL` | `http://ground:8010/v1/audio/transcriptions` | Whisper API endpoint |
| `language` | `""` (auto) | Language code, empty for auto-detect |
| `typingTimeout` | `0.7s` | Silence duration before sending audio |
| `submitWord` | `gönder` | Voice command to press Enter |
| `stopWord` | `bitir` | Voice command to stop dictation |

## Architecture

```
┌─────────────────────────┐
│  StatusMenuController   │  ← Menu bar UI
│  HotkeyManager          │  ← Right Cmd detection
├─────────────────────────┤
│  KonusManager            │  ← State machine (idle/typing)
├─────────────────────────┤
│  AudioEngine            │  ← AVAudioEngine + VAD
│  WhisperClient          │  ← HTTP + SSE streaming
│  TextInserter           │  ← CGEvent Cmd+V / Enter
│  WakeWordMatcher        │  ← Fuzzy matching (Levenshtein)
└─────────────────────────┘
```

## Author

Created by **Ahmet Can**

## License

MIT
