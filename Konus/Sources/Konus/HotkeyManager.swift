import AppKit

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var flagsMonitor: Any?
    private var globalFlagsMonitor: Any?

    var onToggle: (() -> Void)?
    var onDoubleTap: (() -> Void)?   // double-tap → Enter

    private var hotkeyType: HotkeyType = .rightCmd

    // Modifier-key tracking
    private var modifierDown = false
    private var otherKeyWhileModifier = false

    // Double-tap detection
    private var lastTapTime: Date?
    private let doubleTapInterval: TimeInterval = 0.35
    private var pendingTapWork: DispatchWorkItem?

    func start() {
        hotkeyType = Settings.shared.hotkeyType

        if hotkeyType.isModifierKey {
            startModifierMode()
        } else {
            startKeyMode()
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m); globalFlagsMonitor = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        pendingTapWork?.cancel()
        pendingTapWork = nil
    }

    /// Restart with new hotkey setting
    func restart() {
        stop()
        start()
    }

    // MARK: - Modifier key mode (Right Cmd, Left Cmd, Fn)

    private func startModifierMode() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.otherKeyWhileModifier = true
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.otherKeyWhileModifier = true
            return event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierFlags(event)
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierFlags(event)
            return event
        }
    }

    private func handleModifierFlags(_ event: NSEvent) {
        guard let targetKeyCode = hotkeyType.keyCode else { return }

        let isTargetDown: Bool
        switch hotkeyType {
        case .rightCmd, .leftCmd:
            isTargetDown = event.modifierFlags.contains(.command) && event.keyCode == targetKeyCode
        case .fn:
            isTargetDown = event.modifierFlags.contains(.function) && event.keyCode == targetKeyCode
        default:
            return
        }

        let isReleased: Bool
        switch hotkeyType {
        case .rightCmd, .leftCmd:
            isReleased = !event.modifierFlags.contains(.command) && modifierDown
        case .fn:
            isReleased = !event.modifierFlags.contains(.function) && modifierDown
        default:
            return
        }

        if isTargetDown && !modifierDown {
            modifierDown = true
            otherKeyWhileModifier = false
        } else if isReleased {
            modifierDown = false
            guard !otherKeyWhileModifier else { return }
            handleTap()
        }
    }

    // MARK: - Function key mode (F5)

    private func startKeyMode() {
        guard let vk = hotkeyType.virtualKey else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == vk {
                self?.handleTap()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == vk {
                self?.handleTap()
                return nil // consume
            }
            return event
        }
    }

    // MARK: - Tap / double-tap logic

    private func handleTap() {
        let now = Date()

        if let last = lastTapTime, now.timeIntervalSince(last) < doubleTapInterval {
            pendingTapWork?.cancel()
            pendingTapWork = nil
            lastTapTime = nil
            DispatchQueue.main.async { [weak self] in
                self?.onDoubleTap?()
            }
        } else {
            lastTapTime = now
            let work = DispatchWorkItem { [weak self] in
                self?.lastTapTime = nil
                self?.onToggle?()
            }
            pendingTapWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapInterval, execute: work)
        }
    }

    deinit {
        stop()
    }
}
