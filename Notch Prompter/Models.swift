//
//  Models.swift
//  Notch Prompter
//

import Foundation
import SwiftUI

// MARK: - Script model

struct Script: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var lastScrollOffset: Double
    var lastUpdated: Date

    init(id: UUID = UUID(),
         title: String,
         content: String,
         lastScrollOffset: Double = 0,
         lastUpdated: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.lastScrollOffset = lastScrollOffset
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Enums for settings

enum ActivationMode: String, CaseIterable, Codable, Identifiable {
    case mouseActivated
    case toggleMode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mouseActivated: return "Mouse-Activated (hover over notch)"
        case .toggleMode:     return "Toggle Mode (hotkeys)"
        }
    }
}

enum PerformanceMode: String, CaseIterable, Codable, Identifiable {
    case highSmoothness
    case balanced
    case batterySaver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highSmoothness: return "High Smoothness"
        case .balanced:       return "Balanced"
        case .batterySaver:   return "Battery Saver"
        }
    }

    /// Scroll timer interval (seconds)
    var timerInterval: TimeInterval {
        switch self {
        case .highSmoothness: return 1.0 / 60.0
        case .balanced:       return 1.0 / 30.0
        case .batterySaver:   return 1.0 / 15.0
        }
    }
}

enum TeleprompterTheme: String, CaseIterable, Codable, Identifiable {
    case retro
    case document
    case transparent // New: Transparent HUD look

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .retro:       return "Retro Teleprompter"
        case .document:    return "Document-like"
        case .transparent: return "Transparent HUD"
        }
    }
}

enum ScrollMode: String, CaseIterable, Codable, Identifiable {
    case continuous
    case lineByLine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .continuous: return "Continuous"
        case .lineByLine: return "Line-by-line"
        }
    }
}

enum HideSpeed: String, CaseIterable, Codable, Identifiable {
    case immediate
    case fast
    case slow

    var id: String { rawValue }

    var animationDuration: TimeInterval {
        switch self {
        case .immediate: return 0.0
        case .fast:      return 0.15
        case .slow:      return 0.35
        }
    }

    var displayName: String {
        switch self {
        case .immediate: return "Immediate"
        case .fast:      return "Fast"
        case .slow:      return "Slow"
        }
    }
}

// MARK: - Hotkeys

enum HotkeyChoice: String, CaseIterable, Codable, Identifiable {
    case none
    case optionCommand1
    case optionCommand2
    case optionCommand3
    case optionCommand4
    case optionCommand5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:             return "None"
        case .optionCommand1:   return "⌥⌘1"
        case .optionCommand2:   return "⌥⌘2"
        case .optionCommand3:   return "⌥⌘3"
        case .optionCommand4:   return "⌥⌘4"
        case .optionCommand5:   return "⌥⌘5"
        }
    }

    /// Character expected for the numeric key when pressed (ignoring modifiers)
    var keyCharacter: String? {
        switch self {
        case .none:             return nil
        case .optionCommand1:   return "1"
        case .optionCommand2:   return "2"
        case .optionCommand3:   return "3"
        case .optionCommand4:   return "4"
        case .optionCommand5:   return "5"
        }
    }
}

