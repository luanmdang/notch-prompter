//
//  PreferencesView.swift
//  Notch Prompter
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var controller: TeleprompterController

    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem { Text("General") }

            DisplayPreferencesView()
                .tabItem { Text("Display & Theme") }

            BehaviorPreferencesView()
                .tabItem { Text("Behavior") }

            ScriptsPreferencesView()
                .tabItem { Text("Scripts") }
        }
        .frame(width: 640, height: 460)
    }
}

// MARK: - General

struct GeneralPreferencesView: View {
    @EnvironmentObject var controller: TeleprompterController

    var body: some View {
        Form {
            Picker("Activation Mode", selection: $controller.activationMode) {
                ForEach(ActivationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Picker("Performance Mode", selection: $controller.performanceMode) {
                ForEach(PerformanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Toggle("Launch at login (placeholder)", isOn: .constant(false))
                .help("Wire this up with SMLoginItem in a future iteration.")

            Text("Global hotkeys are preset as ⌥⌘1–5. A more advanced hotkey recorder UI can be added later.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Display & Theme

struct DisplayPreferencesView: View {
    @EnvironmentObject var controller: TeleprompterController

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Teleprompter Panel Size")
                    .font(.headline)
                HStack {
                    Text("Width")
                    Slider(value: $controller.panelWidthFraction, in: 0.2...0.8)
                    Text(String(format: "%.0f%%", controller.panelWidthFraction * 100))
                        .frame(width: 50, alignment: .trailing)
                }
                HStack {
                    Text("Height")
                    Slider(value: $controller.panelHeight, in: 120...400)
                    Text("\(Int(controller.panelHeight)) px")
                        .frame(width: 70, alignment: .trailing)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.headline)
                Picker("Theme", selection: $controller.theme) {
                    ForEach(TeleprompterTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Font size")
                    Slider(value: $controller.fontSize, in: 14...40)
                    Text("\(Int(controller.fontSize)) pt")
                        .frame(width: 60, alignment: .trailing)
                }

                HStack {
                    Text("Line spacing")
                    Slider(value: $controller.lineSpacing, in: 0...16)
                    Text(String(format: "%.0f", controller.lineSpacing))
                        .frame(width: 40, alignment: .trailing)
                }

                Toggle("Reading line", isOn: $controller.readingLineEnabled)
                Toggle("Mirror mode (flip text horizontally)", isOn: $controller.mirrorMode)
            }
        }
        .padding()
    }
}

// MARK: - Behavior

struct BehaviorPreferencesView: View {
    @EnvironmentObject var controller: TeleprompterController

    var body: some View {
        Form {
            Section("Scrolling") {
                Picker("Scroll mode", selection: $controller.scrollMode) {
                    ForEach(ScrollMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                HStack {
                    Text("Default scroll speed")
                    Slider(value: $controller.scrollSpeed, in: 0.1...2.0)
                    Text(String(format: "%.2f", controller.scrollSpeed))
                        .frame(width: 60, alignment: .trailing)
                }
            }

            Section("Mouse-Activated Mode") {
                HStack {
                    Text("Auto-scroll delay after hover")
                    Slider(value: $controller.autoScrollDelay, in: 0.0...1.0)
                    Text(String(format: "%.2fs", controller.autoScrollDelay))
                        .frame(width: 60, alignment: .trailing)
                }

                Picker("Hide speed", selection: $controller.hideSpeed) {
                    ForEach(HideSpeed.allCases) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Activation Area").font(.headline)

                    HStack {
                        Text("Width")
                        Slider(value: $controller.activationZoneWidthMultiplier, in: 0.5...2.0)
                        Text(String(format: "%.0f%%", controller.activationZoneWidthMultiplier * 100))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .help("Scales the notch width used for hover activation.")

                    HStack {
                        Text("Extra height")
                        Slider(value: $controller.activationZoneExtraHeight, in: 0.0...40.0)
                        Text("\(Int(controller.activationZoneExtraHeight)) px")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .help("Adds vertical thickness to the activation zone to make hover easier.")

                    Toggle("Treat any screen as notched", isOn: $controller.treatAsNotched)
                        .help("If enabled, a default activation zone is used even when no notch is detected.")
                }
            }

            Section("Manual Auto-Scroll") {
                Button {
                    controller.play()
                } label: {
                    Label("Start Auto-Scroll Now", systemImage: "play.fill")
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .help("Use ⌥⌘S to manually start auto-scroll while Preferences is focused.")
            }

            Section("Toggle Mode") {
                Toggle("Pause scrolling when hidden", isOn: $controller.pauseWhenHiddenInToggleMode)
                Toggle("Reset to top when hidden", isOn: $controller.resetToTopWhenHiddenInToggleMode)
            }
        }
        .padding()
    }
}

// MARK: - Scripts (library + editor)

struct ScriptsPreferencesView: View {
    @EnvironmentObject var controller: TeleprompterController
    @State private var selection: Script.ID?

    var body: some View {
        HStack(spacing: 0) {
            scriptList
                .frame(width: 220)
            Divider()
            scriptEditor
        }
        .onAppear {
            // Initialize selection from persisted store; if none, pick first available.
            selection = controller.scriptStore.selectedScriptID
                ?? controller.scriptStore.scripts.first?.id
        }
    }

    private var scriptList: some View {
        VStack {
            HStack {
                Text("Scripts")
                    .font(.headline)
                Spacer()
                Button {
                    let newScript = controller.scriptStore.createScript()
                    selection = newScript.id
                    controller.scriptStore.selectedScriptID = newScript.id
                    controller.currentScript = newScript
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Button {
                    deleteSelectedScript()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selection == nil)
                .buttonStyle(.plain)
                .help("Delete selected script")
            }
            .padding([.top, .horizontal])

            List(selection: $selection) {
                ForEach(controller.scriptStore.scripts) { script in
                    VStack(alignment: .leading) {
                        Text(script.title)
                            .fontWeight(.medium)
                        Text(script.lastUpdated, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(script.id)
                }
                .onDelete { indexSet in
                    indexSet.compactMap { controller.scriptStore.scripts[$0] }.forEach { script in
                        controller.scriptStore.deleteScript(script)
                    }
                    // After deletion from swipe/keyboard, reconcile selection.
                    reconcileSelectionAfterDeletion()
                }
            }
            .onChange(of: selection) { _, newValue in
                guard let id = newValue, let script = controller.scriptStore.script(with: id) else { return }
                controller.scriptStore.selectedScriptID = id
                // Apply to teleprompter so it shows the selected script.
                controller.currentScript = script
            }

            HStack {
                Button {
                    useSelectedScriptInTeleprompter()
                } label: {
                    Label("Use Selected", systemImage: "text.viewfinder")
                }
                .disabled(selection == nil)
                Spacer()
            }
            .padding([.horizontal, .bottom])
        }
    }

    private var scriptEditor: some View {
        VStack(alignment: .leading) {
            if let scriptID = selection,
               var script = controller.scriptStore.script(with: scriptID) {
                HStack {
                    TextField("Title", text: Binding(
                        get: { script.title },
                        set: { newVal in
                            script.title = newVal
                            script.lastUpdated = Date()
                            controller.scriptStore.updateScript(script)
                        }
                    ))
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)

                    Spacer()

                    Button("Duplicate") {
                        controller.scriptStore.duplicateScript(script)
                    }
                }
                .padding([.top, .horizontal])

                TextEditor(text: Binding(
                    get: { script.content },
                    set: { newVal in
                        script.content = newVal
                        script.lastUpdated = Date()
                        controller.scriptStore.updateScript(script)
                        controller.applyScript(script)
                    }
                ))
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .padding()
            } else {
                VStack {
                    Text("No script selected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func deleteSelectedScript() {
        guard let id = selection,
              let script = controller.scriptStore.script(with: id) else { return }
        controller.scriptStore.deleteScript(script)
        reconcileSelectionAfterDeletion()
    }

    private func reconcileSelectionAfterDeletion() {
        if let first = controller.scriptStore.scripts.first {
            selection = first.id
            controller.scriptStore.selectedScriptID = first.id
            controller.currentScript = first
        } else {
            // No scripts remain; clear local selection and leave store as-is.
            selection = nil
        }
    }

    private func useSelectedScriptInTeleprompter() {
        guard let id = selection,
              let script = controller.scriptStore.script(with: id) else { return }
        controller.scriptStore.selectedScriptID = id
        controller.currentScript = script
    }
}
