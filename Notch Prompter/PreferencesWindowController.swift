//
//  PreferencesWindowController.swift
//  Notch Prompter
//

import AppKit
import SwiftUI

final class PreferencesWindowController {
    private var window: NSWindow?
    private unowned let controller: TeleprompterController

    init(controller: TeleprompterController) {
        self.controller = controller
    }

    func show() {
        if window == nil {
            let contentView = PreferencesView()
                .environmentObject(controller)

            let hostingView = NSHostingView(rootView: contentView)

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Notch Prompter Preferences"
            win.isReleasedWhenClosed = false
            win.center()
            win.contentView = hostingView

            self.window = win
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
