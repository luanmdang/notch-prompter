//
//  MouseActivationMonitor.swift
//  Notch Prompter
//

import AppKit

final class MouseActivationMonitor {
    private let controller: TeleprompterController
    private let windowController: TeleprompterWindowController

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hoverTimer: Timer?
    private var hideTimer: Timer?
    private var isInsideActivationZone: Bool = false

    init(controller: TeleprompterController,
         windowController: TeleprompterWindowController) {
        self.controller = controller
        self.windowController = windowController
    }

    func start() {
        // Global monitor fires when app is NOT active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event: event)
        }

        // Local monitor fires when app IS active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event: event)
            return event
        }
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        hoverTimer?.invalidate()
        hideTimer?.invalidate()
    }

    private func handleMouseMoved(event: NSEvent) {
        guard controller.activationMode == .mouseActivated else { return }

        let mousePoint = NSEvent.mouseLocation

        // Find the screen that contains the mouse
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mousePoint, $0.frame, false) }) else {
            return
        }

        // Compute a notch-only activation zone. If no notch is detected, do not activate unless forced.
        guard let zone = notchActivationZone(for: screen) else {
            if isInsideActivationZone {
                isInsideActivationZone = false
                cancelHoverTimer()
                scheduleHide()
            }
            return
        }

        if zone.contains(mousePoint) {
            if !isInsideActivationZone {
                isInsideActivationZone = true
                startHoverTimer()
                cancelHideTimer()
            }
        } else {
            if isInsideActivationZone {
                isInsideActivationZone = false
                cancelHoverTimer()
                scheduleHide()
            }
        }
    }

    // MARK: - Notch geometry

    // Returns a rect matching the notch: height = menu bar height (+ extra); width = notch width * multiplier; centered at top.
    // If there is no notch (or we can't determine it), returns nil unless treatAsNotched is enabled.
    private func notchActivationZone(for screen: NSScreen) -> NSRect? {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // Derive an effective menu bar height that survives auto-hide or odd reports.
        let systemMenuBarHeight = NSStatusBar.system.thickness
        let visibleDelta = max(0, screenFrame.height - visibleFrame.height)
        var effectiveMenuBarHeight = max(systemMenuBarHeight, visibleDelta)

        // If still zero (e.g. auto-hidden menu bar), use a reasonable fallback so hover still works.
        if effectiveMenuBarHeight <= 0 {
            effectiveMenuBarHeight = 40 // typical notched MBP menu bar height ballpark
        }

        // Prefer exact computation by inferring the "safe" width from a temporary window
        // that asks AppKit for its contentLayoutRect (which can avoid the camera housing region).
        var notchWidth: CGFloat?

        if #available(macOS 12.0, *) {
            if let safeFrame = safeContentFrameAvoidingNotch(on: screen) {
                // If safe area width is smaller than full width, the difference corresponds to the notch width
                let widthDiff = max(0, screenFrame.width - safeFrame.width)
                if widthDiff > 2 {
                    notchWidth = widthDiff
                }
            }
        }

        // Fallback heuristic (older SDKs or if we couldn't infer a notch).
        if notchWidth == nil {
            // Consider a notch if the menu bar is tall (typical on notched MBP),
            // or if the user explicitly wants to treat the display as notched.
            if effectiveMenuBarHeight > 30 || controller.treatAsNotched {
                let ratio: CGFloat = 4.7
                let estimated = effectiveMenuBarHeight * ratio
                let clamped = min(max(estimated, 140), 260)
                notchWidth = clamped
            } else {
                return nil
            }
        }

        guard var width = notchWidth, width > 0 else { return nil }

        // Apply user multiplier
        width = max(40, width * CGFloat(controller.activationZoneWidthMultiplier))

        var height = effectiveMenuBarHeight + CGFloat(controller.activationZoneExtraHeight)
        height = max(height, 24) // ensure at least some hover thickness

        let x = screenFrame.midX - width / 2.0
        let y = screenFrame.maxY - height

        return NSRect(x: x, y: y, width: width, height: height)
    }

    // Create a temporary window on the target screen, ask AppKit for the contentLayoutRect,
    // then tear it down. This can reflect a safe area that avoids the notch in some configurations.
    @available(macOS 12.0, *)
    private func safeContentFrameAvoidingNotch(on screen: NSScreen) -> NSRect? {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.alphaValue = 0.0
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        // We don't need to make it visible to query the layout rect.
        let layoutRect = window.contentLayoutRect
        window.orderOut(nil)
        return layoutRect
    }

    // MARK: - Timers

    private func startHoverTimer() {
        hoverTimer?.invalidate()
        let delay = max(0, controller.autoScrollDelay)
        hoverTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.controller.showTeleprompter(autoPlay: true)
        }
        if let hoverTimer {
            RunLoop.main.add(hoverTimer, forMode: .common)
        }
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        let delay: TimeInterval
        switch controller.hideSpeed {
        case .immediate: delay = 0.0
        case .fast:      delay = 0.2
        case .slow:      delay = 0.5
        }

        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.controller.hideTeleprompter()
        }
        if let hideTimer {
            RunLoop.main.add(hideTimer, forMode: .common)
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
}

