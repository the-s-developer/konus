import Foundation

enum KonusMode: String {
    case idle
    case typing
}

protocol KonusManagerDelegate: AnyObject {
    func konusManager(_ manager: KonusManager, didChangeMode mode: KonusMode)
    func konusManager(_ manager: KonusManager, didChangeStatus status: String)
    func konusManager(_ manager: KonusManager, didUpdateLevel level: Float)
    func konusManager(_ manager: KonusManager, didTranscribe text: String)
}

final class KonusManager {
    weak var delegate: KonusManagerDelegate?

    private(set) var mode: KonusMode = .idle

    // Settings
    var whisperURL = "http://ground:8010/v1/audio/transcriptions"
    var language = ""  // auto-detect
    var hotwords = "gönder, bitir"
    var initialPrompt = "Türkçe konuşma, teknik terimler İngilizce olabilir."
    var submitWord = "gönder"
    var stopWord = "bitir"
    var typingTimeout: Double = 0.7

    private let audioEngine = AudioEngine()
    private lazy var whisperClient: WhisperClient = {
        WhisperClient(baseURL: whisperURL, language: language, hotwords: hotwords, initialPrompt: initialPrompt)
    }()

    init() {
        audioEngine.delegate = self
    }

    // MARK: - Public

    func toggle() {
        if mode == .idle {
            start()
        } else {
            stop()
        }
    }

    func start() {
        mode = .typing
        audioEngine.setSilenceTimeout(typingTimeout)
        audioEngine.start()
        delegate?.konusManager(self, didChangeMode: .typing)
        delegate?.konusManager(self, didChangeStatus: "Yazıyor...")
        NSLog("[konus] Started typing mode")
    }

    func stop() {
        audioEngine.stop()
        mode = .idle
        delegate?.konusManager(self, didChangeMode: .idle)
        delegate?.konusManager(self, didChangeStatus: "Durduruldu")
        NSLog("[konus] Stopped")
    }

    // MARK: - Audio processing

    private func handleTypingAudio(_ wavData: Data) {
        delegate?.konusManager(self, didChangeStatus: "Çevriliyor...")
        NSLog("[konus] Transcribing %d bytes...", wavData.count)

        Task {
            do {
                let text = try await whisperClient.transcribeStreaming(wavData) { partial in
                    DispatchQueue.main.async {
                        self.delegate?.konusManager(self, didTranscribe: partial)
                    }
                }
                await MainActor.run {
                    if let text, !text.isEmpty {
                        NSLog("[konus] Transcribed: %@", text)
                        self.processTypingText(text)
                    } else {
                        NSLog("[konus] Empty transcription")
                        self.restoreStatus()
                    }
                }
            } catch {
                await MainActor.run {
                    NSLog("[konus] Whisper error: %@", error.localizedDescription)
                    self.restoreStatus()
                }
            }
        }
    }

    private func processTypingText(_ text: String) {
        let stripped = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:"))
            .lowercased()

        let words = stripped.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // "bitir" → stop
        let hasStop = words.contains { WakeWordMatcher.levenshtein($0, stopWord.lowercased()) <= 1 }
        // "gönder" → Enter
        let hasSubmit = words.contains { WakeWordMatcher.levenshtein($0, submitWord.lowercased()) <= 1 }

        if hasStop {
            let before = removeCommand(text, command: stopWord)
            if !before.isEmpty {
                TextInserter.insert(before)
            }
            stop()
            return
        }

        if hasSubmit {
            let before = removeCommand(text, command: submitWord)
            if !before.isEmpty {
                TextInserter.insert(before)
                usleep(100_000)
            }
            TextInserter.pressEnter()
            restoreStatus()
            return
        }

        // Normal text — paste it
        TextInserter.insert(text)
        restoreStatus()
    }

    private func removeCommand(_ text: String, command: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { word in
            let clean = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:")).lowercased()
            return WakeWordMatcher.levenshtein(clean, command.lowercased()) > 1
        }
        return filtered.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func restoreStatus() {
        switch mode {
        case .idle:
            delegate?.konusManager(self, didChangeStatus: "Hazır")
        case .typing:
            delegate?.konusManager(self, didChangeStatus: "Yazıyor...")
        }
    }
}

// MARK: - AudioEngineDelegate

extension KonusManager: AudioEngineDelegate {
    func audioEngine(_ engine: AudioEngine, didDetectLevel rms: Float) {
        delegate?.konusManager(self, didUpdateLevel: rms)
    }

    func audioEngineDidStartSpeech(_ engine: AudioEngine) {
        delegate?.konusManager(self, didChangeStatus: "Konuşma algılandı...")
    }

    func audioEngine(_ engine: AudioEngine, didEndSpeechWith wavData: Data) {
        if mode == .typing {
            handleTypingAudio(wavData)
        }
    }

    func audioEngine(_ engine: AudioEngine, didEncounterError message: String) {
        NSLog("[konus] Audio error: %@", message)
        delegate?.konusManager(self, didChangeStatus: "Hata: \(message)")
    }
}
