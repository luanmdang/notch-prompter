//
//  TeleprompterController.swift
//  Notch Prompter
//

import Foundation
import Combine
import AppKit

final class TeleprompterController: ObservableObject {
    static let shared = TeleprompterController()

    // MARK: - Published state

    @Published var scriptStore = ScriptStore()

    @Published var activationMode: ActivationMode = .mouseActivated {
        didSet { UserDefaults.standard.set(activationMode.rawValue, forKey: "activationMode") }
    }

    @Published var performanceMode: PerformanceMode = .balanced {
        didSet { UserDefaults.standard.set(performanceMode.rawValue, forKey: "performanceMode"); restartTimer() }
    }

    @Published var theme: TeleprompterTheme = .retro {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    @Published var scrollMode: ScrollMode = .continuous {
        didSet { UserDefaults.standard.set(scrollMode.rawValue, forKey: "scrollMode") }
    }

    @Published var hideSpeed: HideSpeed = .fast {
        didSet { UserDefaults.standard.set(hideSpeed.rawValue, forKey: "hideSpeed") }
    }

    @Published var panelWidthFraction: Double = 0.4 {
        didSet { UserDefaults.standard.set(panelWidthFraction, forKey: "panelWidthFraction") }
    }

    @Published var panelHeight: Double = 220 {
        didSet { UserDefaults.standard.set(panelHeight, forKey: "panelHeight") }
    }

    @Published var fontSize: Double = 22 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }

    @Published var lineSpacing: Double = 4 {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: "lineSpacing") }
    }

    @Published var textColor: NSColor = NSColor(calibratedRed: 0.8, green: 1.0, blue: 0.8, alpha: 1.0) // retro default

    @Published var readingLineEnabled: Bool = false {
        didSet { UserDefaults.standard.set(readingLineEnabled, forKey: "readingLineEnabled") }
    }

    @Published var mirrorMode: Bool = false {
        didSet { UserDefaults.standard.set(mirrorMode, forKey: "mirrorMode") }
    }

    @Published var autoScrollDelay: TimeInterval = 0.3 {
        didSet { UserDefaults.standard.set(autoScrollDelay, forKey: "autoScrollDelay") }
    }

    // Activation area customization
    @Published var activationZoneWidthMultiplier: Double = 1.0 {
        didSet { UserDefaults.standard.set(activationZoneWidthMultiplier, forKey: "activationZoneWidthMultiplier") }
    }

    @Published var activationZoneExtraHeight: Double = 6.0 {
        didSet { UserDefaults.standard.set(activationZoneExtraHeight, forKey: "activationZoneExtraHeight") }
    }

    @Published var treatAsNotched: Bool = false {
        didSet { UserDefaults.standard.set(treatAsNotched, forKey: "treatAsNotched") }
    }

    // Teleprompter content layout
    @Published var contentTopPadding: Double = 40 {
        didSet { UserDefaults.standard.set(contentTopPadding, forKey: "contentTopPadding") }
    }

    @Published var isVisible: Bool = false
    @Published var isPlaying: Bool = false
    @Published var scrollOffset: Double = 0.0     // "line units"
    @Published var scrollSpeed: Double = 0.4      // lines per second
    @Published var endOfScriptReached: Bool = false

    // Used to estimate end of script
    @Published var estimatedScriptLineCount: Int = 0

    // Behavior for toggle mode
    @Published var pauseWhenHiddenInToggleMode: Bool = true {
        didSet { UserDefaults.standard.set(pauseWhenHiddenInToggleMode, forKey: "pauseWhenHiddenInToggleMode") }
    }

    @Published var resetToTopWhenHiddenInToggleMode: Bool = false {
        didSet { UserDefaults.standard.set(resetToTopWhenHiddenInToggleMode, forKey: "resetToTopWhenHiddenInToggleMode") }
    }

    // MARK: - Private

    private var timer: Timer?
    private var lastTick: Date?

    private init() {
        loadPersistedSettings()
        restartTimer()
    }

    // MARK: - Script helpers

    var currentScript: Script? {
        get { scriptStore.script(with: scriptStore.selectedScriptID) }
        set {
            if let new = newValue {
                scriptStore.selectedScriptID = new.id
                scriptStore.updateScript(new)
                applyScript(new)
            }
        }
    }

    func applyScript(_ script: Script) {
        scrollOffset = script.lastScrollOffset
        endOfScriptReached = false
        estimatedScriptLineCount = max(script.content.split(whereSeparator: \.isNewline).count, 1)
    }

    func updateCurrentScriptScrollOffset() {
        guard var script = currentScript else { return }
        script.lastScrollOffset = scrollOffset
        script.lastUpdated = Date()
        scriptStore.updateScript(script)
    }

    // MARK: - Public actions (for UI / hotkeys / mouse)

    func showTeleprompter(autoPlay: Bool) {
        guard !isVisible else {
            if autoPlay { play() }
            return
        }
        isVisible = true
        if autoPlay { play() }
    }

    func hideTeleprompter(fromToggleMode: Bool = false) {
        guard isVisible else { return }
        isVisible = false

        if activationMode == .toggleMode && fromToggleMode {
            if pauseWhenHiddenInToggleMode { pause() }
            if resetToTopWhenHiddenInToggleMode {
                resetScroll()
            } else {
                updateCurrentScriptScrollOffset()
            }
        } else {
            pause()
            updateCurrentScriptScrollOffset()
        }
    }

    func toggleTeleprompter(autoPlay: Bool) {
        if isVisible {
            hideTeleprompter(fromToggleMode: true)
        } else {
            showTeleprompter(autoPlay: autoPlay)
        }
    }

    func play() {
        guard !endOfScriptReached else { return }
        isPlaying = true
        lastTick = Date()
    }

    func pause() {
        isPlaying = false
        lastTick = nil
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func scrollFaster() {
        scrollSpeed *= 1.25
        UserDefaults.standard.set(scrollSpeed, forKey: "scrollSpeed")
    }

    func scrollSlower() {
        scrollSpeed *= 0.8
        UserDefaults.standard.set(scrollSpeed, forKey: "scrollSpeed")
    }

    func resetScroll() {
        scrollOffset = 0
        endOfScriptReached = false
    }

    func markEndOfScriptReached() {
        endOfScriptReached = true
        pause()
    }

    // MARK: - Timer / scroll engine

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: performanceMode.timerInterval,
                                     repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard isPlaying, isVisible else { return }
        let now = Date()
        let dt = lastTick.map { now.timeIntervalSince($0) } ?? performanceMode.timerInterval
        lastTick = now

        guard dt > 0 else { return }

        switch scrollMode {
        case .continuous:
            scrollOffset += scrollSpeed * dt
        case .lineByLine:
            // Move in discrete steps every ~0.4s
            let threshold: TimeInterval = 0.4
            if dt >= threshold {
                scrollOffset += scrollSpeed.sign == .minus ? -1 : 1
            } else {
                // accumulate small steps as continuous
                scrollOffset += scrollSpeed * dt
            }
        }

        // Clamp scroll offset based on estimated script lines
        let visibleApprox = 8.0
        let maxOffset = max(0.0, Double(estimatedScriptLineCount) - visibleApprox)
        if scrollOffset >= maxOffset {
            scrollOffset = maxOffset
            markEndOfScriptReached()
        } else if scrollOffset < 0 {
            scrollOffset = 0
        }
    }

    // MARK: - Persistence

    private func loadPersistedSettings() {
        let d = UserDefaults.standard

        if let s = d.string(forKey: "activationMode"), let v = ActivationMode(rawValue: s) {
            activationMode = v
        }
        if let s = d.string(forKey: "performanceMode"), let v = PerformanceMode(rawValue: s) {
            performanceMode = v
        }
        if let s = d.string(forKey: "theme"), let v = TeleprompterTheme(rawValue: s) {
            theme = v
        }
        if let s = d.string(forKey: "scrollMode"), let v = ScrollMode(rawValue: s) {
            scrollMode = v
        }
        if let s = d.string(forKey: "hideSpeed"), let v = HideSpeed(rawValue: s) {
            hideSpeed = v
        }

        panelWidthFraction = d.double(forKey: "panelWidthFraction").nonZeroOr(0.4)
        panelHeight       = d.double(forKey: "panelHeight").nonZeroOr(220)
        fontSize          = d.double(forKey: "fontSize").nonZeroOr(22)
        lineSpacing       = d.double(forKey: "lineSpacing").nonZeroOr(4)
        readingLineEnabled = d.bool(forKey: "readingLineEnabled")
        mirrorMode         = d.bool(forKey: "mirrorMode")
        autoScrollDelay    = d.object(forKey: "autoScrollDelay").flatMap { $0 as? Double } ?? 0.3
        pauseWhenHiddenInToggleMode = d.object(forKey: "pauseWhenHiddenInToggleMode") as? Bool ?? true
        resetToTopWhenHiddenInToggleMode = d.object(forKey: "resetToTopWhenHiddenInToggleMode") as? Bool ?? false
        scrollSpeed = d.object(forKey: "scrollSpeed").flatMap { $0 as? Double } ?? 0.4

        activationZoneWidthMultiplier = d.object(forKey: "activationZoneWidthMultiplier").flatMap { $0 as? Double } ?? 1.0
        activationZoneExtraHeight     = d.object(forKey: "activationZoneExtraHeight").flatMap { $0 as? Double } ?? 6.0
        treatAsNotched                = d.object(forKey: "treatAsNotched").flatMap { $0 as? Bool } ?? false

        contentTopPadding             = d.object(forKey: "contentTopPadding").flatMap { $0 as? Double } ?? 40
    }
}

// MARK: - Small helper

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}

