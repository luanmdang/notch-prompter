//
//  HotkeyManager.swift
//  Notch Prompter
//

import AppKit
import Carbon

final class HotkeyManager {
    private let controller: TeleprompterController
    private let windowController: TeleprompterWindowController

    private var hotKeyRefs: [EventHotKeyRef?] = []

    init(controller: TeleprompterController,
         windowController: TeleprompterWindowController) {
        self.controller = controller
        self.windowController = windowController
        installEventHandler()
    }

    func registerDefaultHotkeys() {
        // Example combos (⌥⌘1...5)
        // 1: Show/Hide & Auto-Play
        registerHotKey(id: 1, keyCode: 18, modifiers: cmdOpt) // 1
        // 2: Show/Hide Only
        registerHotKey(id: 2, keyCode: 19, modifiers: cmdOpt) // 2
        // 3: Play/Pause
        registerHotKey(id: 3, keyCode: 20, modifiers: cmdOpt) // 3
        // 4: Speed Up
        registerHotKey(id: 4, keyCode: 21, modifiers: cmdOpt) // 4
        // 5: Speed Down
        registerHotKey(id: 5, keyCode: 23, modifiers: cmdOpt) // 5
    }

    // MARK: - Carbon glue

    private let cmdOpt: UInt32 = UInt32(cmdKey | optionKey)

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, eventRef, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKey(event: eventRef)
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)
    }

    private func registerHotKey(id: Int, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers,
                                         EventHotKeyID(signature: OSType(0x4E50544B), // 'NPTK'
                                                       id: UInt32(id)),
                                         GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
        } else {
            print("Failed to register hotkey \(id)")
        }
    }

    private func handleHotKey(event: EventRef?) {
        guard let event else { return }
        var hotKeyID = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject),
                          EventParamType(typeEventHotKeyID),
                          nil, MemoryLayout<EventHotKeyID>.size,
                          nil, &hotKeyID)
        let id = Int(hotKeyID.id)

        switch id {
        case 1:
            controller.toggleTeleprompter(autoPlay: true)
        case 2:
            controller.toggleTeleprompter(autoPlay: false)
        case 3:
            controller.togglePlay()
        case 4:
            controller.scrollFaster()
        case 5:
            controller.scrollSlower()
        default:
            break
        }
    }
}
