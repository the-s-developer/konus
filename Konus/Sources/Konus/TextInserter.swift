import AppKit
import ApplicationServices

final class TextInserter {

    /// Paste text into the currently focused app via clipboard + Cmd+V
    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        if !AXIsProcessTrusted() {
            NSLog("[konus] ⚠️ Accessibility permission not granted! Text: \(text.prefix(40))")
            requestAccessibilityPermission()
            return
        }

        NSLog("[konus] Inserting text: \(text.prefix(60))")

        // Write to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Delay for clipboard
        usleep(80_000) // 80ms

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            NSLog("[konus] ⚠️ Failed to create CGEvent for Cmd+V")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        usleep(10_000) // 10ms between down and up
        keyUp.post(tap: .cghidEventTap)

        NSLog("[konus] ✓ Cmd+V posted")
    }

    /// Press Enter key
    static func pressEnter() {
        if !AXIsProcessTrusted() {
            NSLog("[konus] ⚠️ Accessibility permission not granted for Enter!")
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        else { return }

        keyDown.post(tap: .cghidEventTap)
        usleep(10_000)
        keyUp.post(tap: .cghidEventTap)

        NSLog("[konus] ✓ Enter posted")
    }

    /// Check if Accessibility permission is granted
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (shows system dialog)
    static func requestAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
