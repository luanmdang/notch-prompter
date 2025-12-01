//
//  NotchPrompterApp.swift
//  Notch Prompter
//

import SwiftUI
import AppKit

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()   // no-op; we use our own PreferencesWindowController
        }
    }
}

// MARK: - AppDelegate: sets up menu bar app

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    private var teleprompterWindowController: TeleprompterWindowController!
    private var mouseMonitor: MouseActivationMonitor!
    private var hotkeyManager: HotkeyManager!
    private var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = TeleprompterController.shared

        // Teleprompter overlay window
        teleprompterWindowController = TeleprompterWindowController(controller: controller)

        // Preferences window
        preferencesWindowController = PreferencesWindowController(controller: controller)

        // Status item (menu bar)
        menuBarController = MenuBarController(
            controller: controller,
            preferencesWindowController: preferencesWindowController
        )
        menuBarController.setupStatusItem()

        // Mouse activation
        mouseMonitor = MouseActivationMonitor(controller: controller,
                                              windowController: teleprompterWindowController)
        mouseMonitor.start()

        // Global hotkeys
        hotkeyManager = HotkeyManager(controller: controller,
                                      windowController: teleprompterWindowController)
        hotkeyManager.registerDefaultHotkeys()

        controller.scriptStore.load()
    }
}
