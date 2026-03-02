# Konus

macOS menu bar dictation app powered by Whisper. A fast, native alternative to Apple Dictation that uses your own Whisper server for speech-to-text.

## Features

- **Menu bar app** — lives in the status bar, no dock icon
- **Configurable hotkey** — Right Cmd, Left Cmd, Fn, or F5 (changeable in Settings)
- **Double-tap** — double-tap hotkey to press Enter
- **Whisper STT** — uses faster-whisper-large-v3 for high quality transcription
- **Streaming** — real-time transcription as you speak
- **Multi-language** — auto-detects language, works with mixed Turkish/English
- **Universal paste** — types into any focused app via CGEvent (Cmd+V)
- **Bilingual UI** — Turkish and English interface
- **Settings window** — configure hotkey, Whisper URL, and UI language

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
cp Info.plist Konus.app/Contents/
cp -R Konus.app /Applications/
```

### 4. Grant Permissions

- **Microphone** — prompted on first launch
- **Accessibility** — System Settings → Privacy & Security → Accessibility → add Konus

### 5. Use

- **Hotkey (single tap)** — start/stop dictation (default: Right Cmd)
- **Hotkey (double tap)** — press Enter
- **Menu bar icon** — click for status, start/stop, settings, quit

## Configuration

Settings are accessible from the menu bar → Settings (⌘,). All settings persist via UserDefaults.

| Setting | Default | Description |
|---------|---------|-------------|
| Hotkey | Right Cmd | Toggle key: Right Cmd, Left Cmd, Fn, or F5 |
| UI Language | Turkish | Interface language: Turkish or English |
| Whisper URL | `http://ground:8010/v1/audio/transcriptions` | Whisper API endpoint |

## Architecture

```
┌─────────────────────────┐
│  StatusMenuController   │  ← Menu bar UI
│  HotkeyManager          │  ← Configurable hotkey detection
│  SettingsWindow         │  ← Settings UI (NSWindow)
├─────────────────────────┤
│  KonusManager           │  ← State machine (idle/typing)
│  Settings               │  ← UserDefaults persistence
├─────────────────────────┤
│  AudioEngine            │  ← AVAudioEngine + VAD
│  WhisperClient          │  ← HTTP + SSE streaming
│  TextInserter           │  ← CGEvent Cmd+V / Enter
└─────────────────────────┘
```

## Author

Created by **Ahmet Can**

## License

MIT
