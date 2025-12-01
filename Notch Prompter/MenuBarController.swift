//
//  MenuBarController.swift
//  Notch Prompter
//

import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let controller: TeleprompterController
    private let preferencesWindowController: PreferencesWindowController
    private var statusItem: NSStatusItem!

    // Slider + label references so we can update them when the menu opens
    private weak var topPaddingSlider: NSSlider?
    private weak var topPaddingLabel: NSTextField?

    init(controller: TeleprompterController, preferencesWindowController: PreferencesWindowController) {
        self.controller = controller
        self.preferencesWindowController = preferencesWindowController
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.justify.left", accessibilityDescription: "Notch Prompter")
        }

        let menu = NSMenu()
        menu.delegate = self

        // Teleprompter toggles
        menu.addItem(NSMenuItem(title: "Toggle Teleprompter (Auto-Play)", action: #selector(toggleTeleprompterAuto), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Teleprompter (No Auto-Play)", action: #selector(toggleTeleprompterNoAuto), keyEquivalent: ""))
        menu.addItem(.separator())

        // Script submenu
        let scriptMenuItem = NSMenuItem(title: "Current Script", action: nil, keyEquivalent: "")
        let scriptsMenu = NSMenu(title: "Scripts")
        scriptMenuItem.submenu = scriptsMenu
        menu.addItem(scriptMenuItem)
        rebuildScriptsSubmenu(scriptsMenu)

        // Text Position submenu with slider
        let positionMenuItem = NSMenuItem(title: "Text Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu(title: "Text Position")
        positionMenuItem.submenu = positionMenu
        buildTextPositionSubmenu(positionMenu)
        menu.addItem(positionMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch Prompter", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    private func rebuildScriptsSubmenu(_ menu: NSMenu) {
        menu.removeAllItems()
        for script in controller.scriptStore.scripts {
            let item = NSMenuItem(title: script.title, action: #selector(selectScript(_:)), keyEquivalent: "")
            item.representedObject = script.id
            if script.id == controller.scriptStore.selectedScriptID {
                item.state = .on
            }
            item.target = self
            menu.addItem(item)
        }
    }

    // MARK: - Text Position submenu (slider)

    private func buildTextPositionSubmenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // Title (disabled)
        let header = NSMenuItem()
        header.title = "Where the first line starts"
        header.isEnabled = false
        menu.addItem(header)

        // Slider + value label + Reset button as a custom view
        let controlItem = NSMenuItem()
        controlItem.view = makeTopPaddingControlView()
        menu.addItem(controlItem)
    }

    private func makeTopPaddingControlView() -> NSView {
        // Container view sized to look good in a submenu
        let width: CGFloat = 280
        let height: CGFloat = 64
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        // Vertical stack
        let vStack = NSStackView()
        vStack.orientation = .vertical
        vStack.alignment = .leading
        vStack.spacing = 6
        vStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            vStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        // Top row: value label + Reset button
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.distribution = .fill
        topRow.spacing = 8

        let valueLabel = NSTextField(labelWithString: "Top Padding: \(Int(round(controller.contentTopPadding))) pt")
        valueLabel.font = NSFont.systemFont(ofSize: 12)
        valueLabel.textColor = .secondaryLabelColor

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetTopPadding))
        resetButton.bezelStyle = .rounded

        // Use a spacer to push Reset to the trailing edge
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        topRow.addArrangedSubview(valueLabel)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(resetButton)

        // Slider row
        let slider = NSSlider(value: controller.contentTopPadding, minValue: 0, maxValue: 300, target: self, action: #selector(topPaddingSliderChanged(_:)))
        slider.isContinuous = true

        vStack.addArrangedSubview(topRow)
        vStack.addArrangedSubview(slider)

        // Keep references so we can update when menu opens or value changes
        self.topPaddingLabel = valueLabel
        self.topPaddingSlider = slider

        return container
    }

    // MARK: - Actions

    @objc private func toggleTeleprompterAuto() {
        controller.toggleTeleprompter(autoPlay: true)
    }

    @objc private func toggleTeleprompterNoAuto() {
        controller.toggleTeleprompter(autoPlay: false)
    }

    @objc private func selectScript(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        controller.scriptStore.selectedScriptID = id
        if let script = controller.currentScript {
            controller.applyScript(script)
        }
    }

    @objc private func topPaddingSliderChanged(_ sender: NSSlider) {
        controller.contentTopPadding = sender.doubleValue
        updateTopPaddingLabel()
    }

    @objc private func resetTopPadding() {
        controller.contentTopPadding = 40
        topPaddingSlider?.doubleValue = controller.contentTopPadding
        updateTopPaddingLabel()
    }

    @objc private func openPreferences() {
        preferencesWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func updateTopPaddingLabel() {
        let value = Int(round(controller.contentTopPadding))
        topPaddingLabel?.stringValue = "Top Padding: \(value) pt"
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Ensure the slider and label reflect the current value each time the menu opens
        if let slider = topPaddingSlider {
            slider.doubleValue = controller.contentTopPadding
        }
        updateTopPaddingLabel()
    }
}
