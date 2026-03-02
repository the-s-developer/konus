import AppKit

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var flagsMonitor: Any?
    private var globalFlagsMonitor: Any?

    var onToggle: (() -> Void)?
    var onDoubleTap: (() -> Void)?   // double-tap → Enter

    private var rightCmdDown = false
    private var otherKeyWhileCmd = false

    // Double-tap detection
    private var lastTapTime: Date?
    private let doubleTapInterval: TimeInterval = 0.35
    private var pendingTapWork: DispatchWorkItem?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.otherKeyWhileCmd = true
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.otherKeyWhileCmd = true
            return event
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m); globalFlagsMonitor = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
    }

    private func handleFlags(_ event: NSEvent) {
        let rightCmd = event.modifierFlags.contains(.command) && event.keyCode == 54

        if rightCmd && !rightCmdDown {
            rightCmdDown = true
            otherKeyWhileCmd = false
        } else if !event.modifierFlags.contains(.command) && rightCmdDown {
            rightCmdDown = false
            guard !otherKeyWhileCmd else { return }

            let now = Date()

            if let last = lastTapTime, now.timeIntervalSince(last) < doubleTapInterval {
                // Double-tap — cancel pending single tap, fire Enter
                pendingTapWork?.cancel()
                pendingTapWork = nil
                lastTapTime = nil
                DispatchQueue.main.async { [weak self] in
                    self?.onDoubleTap?()
                }
            } else {
                // First tap — wait a bit to see if second comes
                lastTapTime = now
                let work = DispatchWorkItem { [weak self] in
                    self?.lastTapTime = nil
                    self?.onToggle?()
                }
                pendingTapWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapInterval, execute: work)
            }
        }
    }

    deinit {
        stop()
    }
}
