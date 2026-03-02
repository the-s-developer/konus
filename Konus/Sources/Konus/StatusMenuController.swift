import AppKit

final class StatusMenuController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    private var toggleItem: NSMenuItem!
    private var statusTextItem: NSMenuItem!
    private var transcriptItem: NSMenuItem!

    let manager = KonusManager()
    private let hotkeyManager = HotkeyManager()

    func setup() {
        manager.delegate = self

        // Status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: "Konus")
            button.imagePosition = .imageLeading
        }

        // Menu
        menu = NSMenu()

        toggleItem = NSMenuItem(title: "Başlat (🎤)", action: #selector(toggleAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        statusTextItem = NSMenuItem(title: "Durum: Hazır", action: nil, keyEquivalent: "")
        statusTextItem.isEnabled = false
        menu.addItem(statusTextItem)

        transcriptItem = NSMenuItem(title: "Son: —", action: nil, keyEquivalent: "")
        transcriptItem.isEnabled = false
        menu.addItem(transcriptItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Çıkış", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Global hotkey
        hotkeyManager.onToggle = { [weak self] in
            self?.manager.toggle()
        }
        hotkeyManager.onDoubleTap = {
            NSLog("[konus] Double-tap → Enter")
            TextInserter.pressEnter()
        }
        hotkeyManager.start()

        // Check accessibility
        if !TextInserter.hasAccessibilityPermission {
            TextInserter.requestAccessibilityPermission()
        }
    }

    @objc private func toggleAction() {
        manager.toggle()
    }

    @objc private func quitAction() {
        manager.stop()
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }

    private func updateIcon(for mode: KonusMode) {
        guard let button = statusItem.button else { return }
        switch mode {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: "Konus - Kapalı")
        case .typing:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Konus - Yazıyor")
        }
    }
}

// MARK: - KonusManagerDelegate

extension StatusMenuController: KonusManagerDelegate {
    func konusManager(_ manager: KonusManager, didChangeMode mode: KonusMode) {
        updateIcon(for: mode)
        toggleItem.title = mode == .idle ? "Başlat (🎤)" : "Durdur (🎤)"
    }

    func konusManager(_ manager: KonusManager, didChangeStatus status: String) {
        statusTextItem.title = "Durum: \(status)"
    }

    func konusManager(_ manager: KonusManager, didUpdateLevel level: Float) {
        // Could animate the icon or show level
    }

    func konusManager(_ manager: KonusManager, didTranscribe text: String) {
        let short = text.count > 50 ? String(text.prefix(47)) + "..." : text
        transcriptItem.title = "Son: \(short)"
    }
}
