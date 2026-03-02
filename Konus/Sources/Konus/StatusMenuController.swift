import AppKit

final class StatusMenuController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    private var toggleItem: NSMenuItem!
    private var statusTextItem: NSMenuItem!
    private var transcriptItem: NSMenuItem!

    let manager = KonusManager()
    private let hotkeyManager = HotkeyManager()
    private let settingsWindow = SettingsWindow()

    func setup() {
        manager.delegate = self

        // Status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = makeIcon(active: false)
        }

        buildMenu()

        // Global hotkey
        hotkeyManager.onToggle = { [weak self] in
            self?.manager.toggle()
        }
        hotkeyManager.onDoubleTap = { [weak self] in
            NSLog("[konus] Double-tap → Enter + Stop")
            TextInserter.pressEnter()
            self?.manager.stop()
        }
        hotkeyManager.start()

        // Settings changed callback
        settingsWindow.onSettingsChanged = { [weak self] in
            self?.handleSettingsChanged()
        }

        // Check accessibility
        if !TextInserter.hasAccessibilityPermission {
            TextInserter.requestAccessibilityPermission()
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        toggleItem = NSMenuItem(title: L10n.start, action: #selector(toggleAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        statusTextItem = NSMenuItem(title: "\(L10n.status): \(L10n.ready)", action: nil, keyEquivalent: "")
        statusTextItem.isEnabled = false
        menu.addItem(statusTextItem)

        transcriptItem = NSMenuItem(title: "\(L10n.lastTranscript): —", action: nil, keyEquivalent: "")
        transcriptItem.isEnabled = false
        menu.addItem(transcriptItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L10n.settings, action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func handleSettingsChanged() {
        hotkeyManager.restart()
        buildMenu()
        updateIcon(for: manager.mode)
        NSLog("[konus] Settings applied")
    }

    @objc private func toggleAction() {
        manager.toggle()
    }

    @objc private func settingsAction() {
        settingsWindow.show()
    }

    @objc private func quitAction() {
        manager.stop()
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }

    private func updateIcon(for mode: KonusMode) {
        guard let button = statusItem.button else { return }
        button.image = makeIcon(active: mode == .typing)
    }

    private func makeIcon(active: Bool) -> NSImage? {
        if active {
            let img = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Konus - Active")
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            return img?.withSymbolConfiguration(config)
        } else {
            let img = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Konus")
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            return img?.withSymbolConfiguration(config)
        }
    }
}

// MARK: - KonusManagerDelegate

extension StatusMenuController: KonusManagerDelegate {
    func konusManager(_ manager: KonusManager, didChangeMode mode: KonusMode) {
        updateIcon(for: mode)
        toggleItem.title = mode == .idle ? L10n.start : L10n.stop
    }

    func konusManager(_ manager: KonusManager, didChangeStatus status: String) {
        statusTextItem.title = "\(L10n.status): \(status)"
    }

    func konusManager(_ manager: KonusManager, didUpdateLevel level: Float) {
        // Could animate the icon or show level
    }

    func konusManager(_ manager: KonusManager, didTranscribe text: String) {
        let short = text.count > 50 ? String(text.prefix(47)) + "..." : text
        transcriptItem.title = "\(L10n.lastTranscript): \(short)"
    }
}
