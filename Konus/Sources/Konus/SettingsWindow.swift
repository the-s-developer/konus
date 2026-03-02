import AppKit

final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hotkeyPopup: NSPopUpButton!
    private var languagePopup: NSPopUpButton!
    private var whisperURLField: NSTextField!

    var onSettingsChanged: (() -> Void)?

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = L10n.settingsTitle
        w.center()
        w.delegate = self
        w.isReleasedWhenClosed = false

        let content = NSView(frame: w.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        w.contentView = content

        let margin: CGFloat = 20
        let labelWidth: CGFloat = 110
        let fieldX = margin + labelWidth + 10
        let fieldWidth: CGFloat = 260
        var y: CGFloat = 200

        // UI Language
        let langLabel = makeLabel(L10n.languageLabel, frame: NSRect(x: margin, y: y, width: labelWidth, height: 24))
        content.addSubview(langLabel)

        languagePopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 26))
        for lang in AppLanguage.allCases {
            languagePopup.addItem(withTitle: lang.displayName)
        }
        let currentLangIndex = AppLanguage.allCases.firstIndex(of: Settings.shared.appLanguage) ?? 0
        languagePopup.selectItem(at: currentLangIndex)
        content.addSubview(languagePopup)

        y -= 40

        // Hotkey
        let hotkeyLabel = makeLabel(L10n.hotkeyLabel, frame: NSRect(x: margin, y: y, width: labelWidth, height: 24))
        content.addSubview(hotkeyLabel)

        hotkeyPopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 26))
        for type in HotkeyType.allCases {
            hotkeyPopup.addItem(withTitle: type.displayName)
        }
        let currentIndex = HotkeyType.allCases.firstIndex(of: Settings.shared.hotkeyType) ?? 0
        hotkeyPopup.selectItem(at: currentIndex)
        content.addSubview(hotkeyPopup)

        y -= 40

        // Whisper URL
        let urlLabel = makeLabel(L10n.whisperURLLabel, frame: NSRect(x: margin, y: y, width: labelWidth, height: 24))
        content.addSubview(urlLabel)

        whisperURLField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 24))
        whisperURLField.stringValue = Settings.shared.whisperURL
        whisperURLField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        content.addSubview(whisperURLField)

        y -= 50

        // Save button
        let saveButton = NSButton(frame: NSRect(x: fieldX + fieldWidth - 90, y: y, width: 90, height: 32))
        saveButton.title = L10n.save
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveAction)
        saveButton.keyEquivalent = "\r"
        content.addSubview(saveButton)

        y -= 30

        // Restart note
        let note = makeLabel(L10n.restartNote, frame: NSRect(x: margin, y: y, width: 380, height: 20))
        note.textColor = .secondaryLabelColor
        note.font = NSFont.systemFont(ofSize: 11)
        content.addSubview(note)

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func saveAction() {
        let s = Settings.shared

        // Language
        let langIndex = languagePopup.indexOfSelectedItem
        if langIndex >= 0 && langIndex < AppLanguage.allCases.count {
            s.appLanguage = AppLanguage.allCases[langIndex]
        }

        // Hotkey
        let hotkeyIndex = hotkeyPopup.indexOfSelectedItem
        if hotkeyIndex >= 0 && hotkeyIndex < HotkeyType.allCases.count {
            s.hotkeyType = HotkeyType.allCases[hotkeyIndex]
        }

        // Whisper URL
        let url = whisperURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty {
            s.whisperURL = url
        }

        NSLog("[konus] Settings saved: hotkey=%@, lang=%@, url=%@",
              s.hotkeyType.rawValue, s.appLanguage.rawValue, s.whisperURL)

        onSettingsChanged?()
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // keep reference but allow closing
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }
}
