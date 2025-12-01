//
//  TeleprompterView.swift
//  Notch Prompter
//

import SwiftUI

struct TeleprompterView: View {
    @EnvironmentObject var controller: TeleprompterController

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
                controller.estimatedScriptLineCount = max(lines.count, 1)
                scrollToCurrentOffset(proxy: proxy, animated: false)
            }
            .onChange(of: controller.scrollOffset) { _ in
                scrollToCurrentOffset(proxy: proxy, animated: true)
            }
            .onChange(of: controller.currentScript?.id) { _ in
                controller.estimatedScriptLineCount = max(lines.count, 1)
                scrollToCurrentOffset(proxy: proxy, animated: false)
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
}

