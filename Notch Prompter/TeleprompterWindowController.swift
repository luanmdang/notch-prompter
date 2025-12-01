//
//  TeleprompterWindowController.swift
//  Notch Prompter
//

import AppKit
import SwiftUI
import Combine
import QuartzCore

final class TeleprompterWindowController {
    private let controller: TeleprompterController
    private var window: NSPanel?

    init(controller: TeleprompterController) {
        self.controller = controller

        controller.$isVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                guard let self else { return }
                if visible {
                    self.show(animated: true)
                } else {
                    self.hide(animated: true)
                }
            }
            .store(in: &cancellables)

        // Rebuild the window when the theme changes so the background switches between black and transparent HUD.
        controller.$theme
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildWindowForTheme()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

    func show(animated: Bool) {
        if window == nil {
            createWindowForCurrentTheme()
        }
        guard let window else { return }

        positionWindow()
        let finalFrame = window.frame

        window.orderFront(nil)
        NSApp.activate(ignoringOtherApps: false)

        guard animated else {
            window.alphaValue = 1.0
            return
        }

        // Expand from the notch area
        let notchWidth = computeNotchWidth(on: NSScreen.main) ?? min(finalFrame.width, 180)
        let initialWidth = min(max(100, notchWidth), finalFrame.width)
        let initialHeight: CGFloat = 12

        let topY = finalFrame.maxY
        let initialX = finalFrame.midX - initialWidth / 2.0
        let initialY = topY - initialHeight
        let initialFrame = NSRect(x: initialX, y: initialY, width: initialWidth, height: initialHeight)

        window.alphaValue = 0
        window.setFrame(initialFrame, display: false)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
            window.animator().setFrame(finalFrame, display: true)
        }
    }

    func hide(animated: Bool) {
        guard let window else { return }

        let duration = controller.hideSpeed.animationDuration
        guard animated, duration > 0 else {
            window.orderOut(nil)
            return
        }

        let startFrame = window.frame
        let notchWidth = computeNotchWidth(on: NSScreen.main) ?? min(startFrame.width, 180)
        let finalWidth = min(max(100, notchWidth), startFrame.width)
        let finalHeight: CGFloat = 12

        let topY = startFrame.maxY
        let finalX = startFrame.midX - finalWidth / 2.0
        let finalY = topY - finalHeight
        let endFrame = NSRect(x: finalX, y: finalY, width: finalWidth, height: finalHeight)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
            window.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            window.orderOut(nil)
        })
    }

    func reposition() {
        positionWindow()
    }

    // MARK: - Private

    private var cancellables: Set<AnyCancellable> = []

    private func createWindowForCurrentTheme() {
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 220),
                            styleMask: style,
                            backing: .buffered,
                            defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false

        switch controller.theme {
        case .transparent:
            // Vibrant/blurred HUD look
            panel.hasShadow = true
            panel.appearance = NSAppearance(named: .vibrantDark)

            let contentRoot = NSView(frame: panel.contentView?.bounds ?? .zero)
            contentRoot.autoresizingMask = [.width, .height]
            panel.contentView = contentRoot

            let effectView = NSVisualEffectView(frame: contentRoot.bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.material = .hudWindow
            effectView.state = .active
            // Sample what's behind the window, not within it
            effectView.blendingMode = .behindWindow
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = 12
            effectView.layer?.masksToBounds = true
            contentRoot.addSubview(effectView)

            let contentView = TeleprompterView()
                .environmentObject(controller)
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = effectView.bounds
            hostingView.autoresizingMask = [.width, .height]
            effectView.addSubview(hostingView)

        case .retro, .document:
            // Pitch-black panel that blends with the notch
            panel.hasShadow = false

            let contentRoot = NSView(frame: panel.contentView?.bounds ?? .zero)
            contentRoot.autoresizingMask = [.width, .height]
            contentRoot.wantsLayer = true
            contentRoot.layer?.backgroundColor = NSColor.black.cgColor
            contentRoot.layer?.cornerRadius = 12
            contentRoot.layer?.masksToBounds = true
            panel.contentView = contentRoot

            let contentView = TeleprompterView()
                .environmentObject(controller)
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = contentRoot.bounds
            hostingView.autoresizingMask = [.width, .height]
            contentRoot.addSubview(hostingView)
        }

        self.window = panel
    }

    private func rebuildWindowForTheme() {
        guard let oldWindow = self.window else { return }
        let wasVisible = oldWindow.isVisible
        let frame = oldWindow.frame

        oldWindow.orderOut(nil)
        self.window = nil
        createWindowForCurrentTheme()
        guard let newWindow = self.window else { return }
        newWindow.setFrame(frame, display: true)
        if wasVisible {
            newWindow.alphaValue = 1.0
            newWindow.orderFront(nil)
        }
    }

    private func positionWindow() {
        guard let window else { return }
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // Menu bar height (the part macOS hides from visibleFrame)
        let menuBarHeight = screenFrame.height - visibleFrame.height

        let width  = visibleFrame.width * CGFloat(controller.panelWidthFraction)
        let height = CGFloat(controller.panelHeight)

        let x = visibleFrame.midX - width / 2.0

        // Overlap the menu bar/notch region a bit
        let overlapFraction: CGFloat = 0.7
        let overlapAmount = max(0, menuBarHeight) * overlapFraction

        let y = visibleFrame.maxY - height + overlapAmount
        let frame = NSRect(x: x, y: y, width: width, height: height)
        window.setFrame(frame, display: true)
    }

    // Estimate notch width for animation purposes
    private func computeNotchWidth(on screen: NSScreen?) -> CGFloat? {
        guard let screen else { return nil }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let systemMenuBarHeight = NSStatusBar.system.thickness
        let visibleDelta = max(0, screenFrame.height - visibleFrame.height)
        var effectiveMenuBarHeight = max(systemMenuBarHeight, visibleDelta)
        if effectiveMenuBarHeight <= 0 { effectiveMenuBarHeight = 40 }

        var notchWidth: CGFloat?

        if #available(macOS 12.0, *) {
            if let safe = safeContentFrameAvoidingNotch(on: screen) {
                let diff = max(0, screenFrame.width - safe.width)
                if diff > 2 { notchWidth = diff }
            }
        }

        if notchWidth == nil {
            if effectiveMenuBarHeight > 30 || controller.treatAsNotched {
                let ratio: CGFloat = 4.7
                let estimated = effectiveMenuBarHeight * ratio
                notchWidth = min(max(estimated, 140), 260)
            }
        }

        return notchWidth
    }

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
        let layoutRect = window.contentLayoutRect
        window.orderOut(nil)
        return layoutRect
    }
}

