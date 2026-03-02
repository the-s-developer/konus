import Foundation

/// Persisted settings via UserDefaults
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key: String {
        case whisperURL
        case language
        case initialPrompt
        case typingTimeout
        case hotkeyType      // "rightCmd", "leftCmd", "fn", "f5"
        case appLanguage      // "tr", "en"
    }

    // MARK: - Whisper

    var whisperURL: String {
        get { defaults.string(forKey: Key.whisperURL.rawValue) ?? "http://ground:8010/v1/audio/transcriptions" }
        set { defaults.set(newValue, forKey: Key.whisperURL.rawValue) }
    }

    var language: String {
        get { defaults.string(forKey: Key.language.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.language.rawValue) }
    }

    var initialPrompt: String {
        get { defaults.string(forKey: Key.initialPrompt.rawValue) ?? "Türkçe konuşma, teknik terimler İngilizce olabilir." }
        set { defaults.set(newValue, forKey: Key.initialPrompt.rawValue) }
    }

    var typingTimeout: Double {
        get {
            let v = defaults.double(forKey: Key.typingTimeout.rawValue)
            return v > 0 ? v : 0.7
        }
        set { defaults.set(newValue, forKey: Key.typingTimeout.rawValue) }
    }

    // MARK: - Hotkey

    var hotkeyType: HotkeyType {
        get {
            guard let raw = defaults.string(forKey: Key.hotkeyType.rawValue),
                  let type = HotkeyType(rawValue: raw) else { return .rightCmd }
            return type
        }
        set { defaults.set(newValue.rawValue, forKey: Key.hotkeyType.rawValue) }
    }

    // MARK: - App Language

    var appLanguage: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: Key.appLanguage.rawValue),
                  let lang = AppLanguage(rawValue: raw) else { return .turkish }
            return lang
        }
        set { defaults.set(newValue.rawValue, forKey: Key.appLanguage.rawValue) }
    }
}

// MARK: - Enums

enum HotkeyType: String, CaseIterable {
    case rightCmd = "rightCmd"
    case leftCmd  = "leftCmd"
    case fn       = "fn"
    case f5       = "f5"

    var displayName: String {
        let lang = Settings.shared.appLanguage
        switch self {
        case .rightCmd: return lang == .turkish ? "Sag Cmd (tek tik)" : "Right Cmd (single tap)"
        case .leftCmd:  return lang == .turkish ? "Sol Cmd (tek tik)" : "Left Cmd (single tap)"
        case .fn:       return lang == .turkish ? "Fn (tek tik)" : "Fn (single tap)"
        case .f5:       return "F5"
        }
    }

    /// The keyCode used in flagsChanged for modifier-based hotkeys
    var keyCode: UInt16? {
        switch self {
        case .rightCmd: return 54
        case .leftCmd:  return 55
        case .fn:       return 63
        case .f5:       return nil  // handled via keyDown, not flags
        }
    }

    var isModifierKey: Bool {
        return keyCode != nil
    }

    /// Virtual key code for non-modifier keys
    var virtualKey: UInt16? {
        switch self {
        case .f5: return 0x60
        default: return nil
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case turkish = "tr"
    case english = "en"

    var displayName: String {
        switch self {
        case .turkish: return "Turkce"
        case .english: return "English"
        }
    }
}

// MARK: - Localized strings

enum L10n {
    static var current: AppLanguage { Settings.shared.appLanguage }

    // Menu items
    static var start: String { current == .turkish ? "Baslat" : "Start" }
    static var stop: String { current == .turkish ? "Durdur" : "Stop" }
    static var settings: String { current == .turkish ? "Ayarlar..." : "Settings..." }
    static var quit: String { current == .turkish ? "Cikis" : "Quit" }

    // Status
    static var ready: String { current == .turkish ? "Hazir" : "Ready" }
    static var typing: String { current == .turkish ? "Yaziyor..." : "Typing..." }
    static var stopped: String { current == .turkish ? "Durduruldu" : "Stopped" }
    static var transcribing: String { current == .turkish ? "Cevriliyor..." : "Transcribing..." }
    static var speechDetected: String { current == .turkish ? "Konusma algilandi..." : "Speech detected..." }
    static var lastTranscript: String { current == .turkish ? "Son" : "Last" }
    static var status: String { current == .turkish ? "Durum" : "Status" }
    static func error(_ msg: String) -> String { current == .turkish ? "Hata: \(msg)" : "Error: \(msg)" }

    // Settings window
    static var settingsTitle: String { current == .turkish ? "Konus Ayarlari" : "Konus Settings" }
    static var hotkeyLabel: String { current == .turkish ? "Kisayol Tusu" : "Hotkey" }
    static var languageLabel: String { current == .turkish ? "Arayuz Dili" : "UI Language" }
    static var whisperURLLabel: String { "Whisper URL" }
    static var save: String { current == .turkish ? "Kaydet" : "Save" }
    static var restartNote: String {
        current == .turkish
            ? "Kisayol degisikligi icin uygulamayi yeniden baslatin."
            : "Restart app for hotkey changes to take effect."
    }
}
