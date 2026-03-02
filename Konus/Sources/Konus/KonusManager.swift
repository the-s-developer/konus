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

    private let audioEngine = AudioEngine()
    private lazy var whisperClient: WhisperClient = {
        let s = Settings.shared
        return WhisperClient(baseURL: s.whisperURL, language: s.language,
                             initialPrompt: s.initialPrompt)
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
        audioEngine.setSilenceTimeout(Settings.shared.typingTimeout)
        audioEngine.start()
        delegate?.konusManager(self, didChangeMode: .typing)
        delegate?.konusManager(self, didChangeStatus: L10n.typing)
        NSLog("[konus] Started typing mode")
    }

    func stop() {
        audioEngine.stop()
        mode = .idle
        delegate?.konusManager(self, didChangeMode: .idle)
        delegate?.konusManager(self, didChangeStatus: L10n.stopped)
        NSLog("[konus] Stopped")
    }

    // MARK: - Audio processing

    private func handleTypingAudio(_ wavData: Data) {
        delegate?.konusManager(self, didChangeStatus: L10n.transcribing)
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
                        TextInserter.insert(text)
                        self.restoreStatus()
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

    private func restoreStatus() {
        switch mode {
        case .idle:
            delegate?.konusManager(self, didChangeStatus: L10n.ready)
        case .typing:
            delegate?.konusManager(self, didChangeStatus: L10n.typing)
        }
    }
}

// MARK: - AudioEngineDelegate

extension KonusManager: AudioEngineDelegate {
    func audioEngine(_ engine: AudioEngine, didDetectLevel rms: Float) {
        delegate?.konusManager(self, didUpdateLevel: rms)
    }

    func audioEngineDidStartSpeech(_ engine: AudioEngine) {
        delegate?.konusManager(self, didChangeStatus: L10n.speechDetected)
    }

    func audioEngine(_ engine: AudioEngine, didEndSpeechWith wavData: Data) {
        if mode == .typing {
            handleTypingAudio(wavData)
        }
    }

    func audioEngine(_ engine: AudioEngine, didEncounterError message: String) {
        NSLog("[konus] Audio error: %@", message)
        delegate?.konusManager(self, didChangeStatus: L10n.error(message))
    }
}
