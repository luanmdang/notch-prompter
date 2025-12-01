//
//  ScriptStore.swift
//  Notch Prompter
//

import Foundation
import Combine

final class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []
    @Published var selectedScriptID: UUID? {
        didSet { persistSelectedScriptID() }
    }

    private let manifestFilename = "scripts.json"
    private let selectedScriptKey = "SelectedScriptID"

    private var manifestURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("NotchPrompter", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir.appendingPathComponent(manifestFilename)
    }

    // MARK: - Load / Save

    func load() {
        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([Script].self, from: data)
            DispatchQueue.main.async {
                self.scripts = loaded
                self.selectedScriptID = self.loadSelectedScriptID()
            }
        } catch {
            // Seed with example script if none
            DispatchQueue.main.async {
                self.scripts = [
                    Script(title: "Welcome to Notch Prompter",
                           content: """
                           This is Notch Prompter.

                           Hover near the notch or use hotkeys to show and scroll this script.

                           You can edit scripts and settings from the menu bar icon.

                           END
                           """)
                ]
                self.selectedScriptID = self.scripts.first?.id
                self.save()
            }
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(scripts)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            print("ScriptStore save error: \(error)")
        }
    }

    // MARK: - CRUD

    func createScript(title: String = "New Script") -> Script {
        let script = Script(title: title, content: "")
        scripts.append(script)
        save()
        return script
    }

    func deleteScript(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        if selectedScriptID == script.id {
            selectedScriptID = scripts.first?.id
        }
        save()
    }

    func duplicateScript(_ script: Script) {
        var copy = script
        copy.id = UUID()
        copy.title += " Copy"
        copy.lastUpdated = Date()
        scripts.append(copy)
        save()
    }

    func updateScript(_ script: Script) {
        if let idx = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[idx] = script
            save()
        }
    }

    func script(with id: UUID?) -> Script? {
        guard let id else { return nil }
        return scripts.first(where: { $0.id == id })
    }

    // MARK: - Selected script persistence

    private func persistSelectedScriptID() {
        if let id = selectedScriptID {
            UserDefaults.standard.set(id.uuidString, forKey: selectedScriptKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedScriptKey)
        }
    }

    private func loadSelectedScriptID() -> UUID? {
        guard let s = UserDefaults.standard.string(forKey: selectedScriptKey) else { return scripts.first?.id }
        return UUID(uuidString: s) ?? scripts.first?.id
    }
}
