//
//  TeleprompterView.swift
//  Notch Prompter
//

import SwiftUI

struct TeleprompterView: View {
    @EnvironmentObject var controller: TeleprompterController
    @State private var autoScrollTask: Task<Void, Never>?
    @State private var contentReady: Bool = false

    // We derive lines from script content
    private var lines: [String] {
        (controller.currentScript?.content ?? "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
    }

    var body: some View {
        ZStack {
            // Transparent theme: clear to let the effect view show.
            // Others: pure black to blend with the notch.
            (controller.theme == .transparent ? Color.clear : Color.black)
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    teleprompterContent(in: geo)
                    if controller.readingLineEnabled {
                        readingLine(in: geo)
                    }
                }
            }
        }
        .onTapGesture {
            controller.togglePlay()
        }
        .onAppear {
            // If the panel is already visible when this view appears, schedule auto-scroll once content is ready.
            scheduleAutoScrollIfNeeded()
        }
        .onDisappear {
            cancelAutoScrollTask()
            contentReady = false
        }
        .onChange(of: controller.isVisible) {
            scheduleAutoScrollIfNeeded()
        }
        .onChange(of: controller.autoScrollDelay) {
            // If user adjusts the delay while the panel is visible, reschedule with the new value.
            scheduleAutoScrollIfNeeded()
        }
        .onChange(of: controller.currentScript?.id) {
            // New script loaded; mark content as not ready until the ScrollView appears.
            contentReady = false
        }
    }

    private func teleprompterContent(in geo: GeometryProxy) -> some View {
        let useRetro = controller.theme == .retro

        let font = useRetro
            ? Font.system(size: controller.fontSize, weight: .regular, design: .monospaced)
            : Font.system(size: controller.fontSize, weight: .regular, design: .default)

        // White for Document and Transparent themes; retro green otherwise
        let textColor: Color = useRetro
            ? Color(red: 0.8, green: 1.0, blue: 0.8)
            : Color.white

        let backgroundColor: Color = controller.theme == .transparent ? .clear : .black

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: controller.lineSpacing) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Text(line.isEmpty ? " " : line)
                            .font(font)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaleEffect(x: controller.mirrorMode ? -1 : 1, y: 1)
                            .id(idx)
                    }
                    if controller.endOfScriptReached {
                        Text("— END —")
                            .font(font.weight(.semibold))
                            .foregroundColor(textColor.opacity(0.7))
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, controller.contentTopPadding)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
            }
            .background(backgroundColor)
            .onAppear {
                // Content is now ready; update line count and scroll to the saved offset.
                controller.estimatedScriptLineCount = max(lines.count, 1)
                contentReady = true
                scrollToCurrentOffset(proxy: proxy, animated: false)
                // Now that content is ready, (re)schedule auto-scroll if needed.
                scheduleAutoScrollIfNeeded()
            }
            .onChange(of: controller.scrollOffset) {
                scrollToCurrentOffset(proxy: proxy, animated: true)
            }
            .onChange(of: controller.currentScript?.id) {
                controller.estimatedScriptLineCount = max(lines.count, 1)
                contentReady = true
                scrollToCurrentOffset(proxy: proxy, animated: false)
                scheduleAutoScrollIfNeeded()
            }
        }
    }

    private func readingLine(in geo: GeometryProxy) -> some View {
        let y = geo.size.height * 0.4
        return Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(height: 1)
            .position(x: geo.size.width / 2.0, y: y)
    }

    private func scrollToCurrentOffset(proxy: ScrollViewProxy, animated: Bool) {
        let maxIndex = max(lines.count - 1, 0)
        let target = min(max(Int(round(controller.scrollOffset)), 0), maxIndex)
        if animated {
            withAnimation(.linear(duration: controller.performanceMode.timerInterval)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    // MARK: - Auto-scroll scheduling

    private func scheduleAutoScrollIfNeeded() {
        // Only auto-scroll when the panel is visible and content is ready.
        guard controller.isVisible, contentReady else {
            cancelAutoScrollTask()
            return
        }

        // Cancel any pending task before scheduling a new one.
        cancelAutoScrollTask()

        let delay = controller.autoScrollDelay
        autoScrollTask = Task {
            // Sleep for the configured delay (in seconds).
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            // Bail if cancelled during the wait.
            if Task.isCancelled { return }

            await MainActor.run {
                // Re-check conditions before starting.
                guard controller.isVisible,
                      contentReady,
                      !controller.isPlaying,
                      !controller.endOfScriptReached
                else { return }

                // Ensure we don't get stuck due to stale endOfScript flag.
                controller.endOfScriptReached = false
                controller.play()
            }
        }
    }

    private func cancelAutoScrollTask() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
    }
}

