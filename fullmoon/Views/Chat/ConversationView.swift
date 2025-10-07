//
//  ConversationView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension TimeInterval {
    var formatted: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

struct MessageView: View {
    @Environment(LLMEvaluator.self) var llm
    @State private var collapsed = true
    let message: Message

    var isThinking: Bool {
        !message.content.contains("</think>")
    }

    func processThinkingContent(_ content: String) -> (String?, String?) {
        guard let startRange = content.range(of: "<think>") else {
            // No <think> tag, return entire content as the second part
            return (nil, content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let endRange = content.range(of: "</think>") else {
            // No </think> tag, return content after <think> without the tag
            let thinking = String(content[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking, nil)
        }

        let thinking = String(content[startRange.upperBound ..< endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let afterThink = String(content[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return (thinking, afterThink.isEmpty ? nil : afterThink)
    }

    var time: String {
        if isThinking, llm.running, let elapsedTime = llm.elapsedTime {
            if isThinking {
                return "(\(elapsedTime.formatted))"
            }
            if let thinkingTime = llm.thinkingTime {
                return thinkingTime.formatted
            }
        } else if let generatingTime = message.generatingTime {
            return "\(generatingTime.formatted)"
        }

        return "0s"
    }

    var thinkingLabel: some View {
        HStack {
            Button {
                collapsed.toggle()
            } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 12))
                    .fontWeight(.medium)
            }

            Text("\(isThinking ? "thinking..." : "thought for") \(time)")
                .italic()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            if message.role == .assistant {
                let (thinking, afterThink) = processThinkingContent(message.content)
                VStack(alignment: .leading, spacing: 16) {
                    if let thinking {
                        VStack(alignment: .leading, spacing: 12) {
                            thinkingLabel
                            if !collapsed {
                                if !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    HStack(spacing: 12) {
                                        Capsule()
                                            .frame(width: 2)
                                            .padding(.vertical, 1)
                                            .foregroundStyle(.fill)
                                        Markdown(thinking)
                                            .textSelection(.enabled)
                                            .markdownTextStyle {
                                                ForegroundColor(.secondary)
                                            }
                                    }
                                    .padding(.leading, 5)
                                }
                            }
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            collapsed.toggle()
                            if isThinking {
                                llm.collapsed = collapsed
                            }
                        }
                    }

                    if let afterThink {
                        Markdown(afterThink)
                            .textSelection(.enabled)
                    }
                }
                .padding(.trailing, 48)
            } else if message.role == .user {
                VStack(alignment: .trailing, spacing: 12) {
                    if !message.imageAttachments.isEmpty {
                        attachmentsGallery(for: message.imageAttachments)
                    }

                    messageBubble(message.content, leadingPadding: 0)
                }
                .padding(.leading, 48)
            } else {
                messageBubble(message.content)
            }

            if message.role == .assistant { Spacer() }
        }
        .onAppear {
            if llm.running {
                collapsed = false
            }
        }
        .onChange(of: llm.elapsedTime) {
            if isThinking {
                llm.thinkingTime = llm.elapsedTime
            }
        }
        .onChange(of: isThinking) {
            if llm.running {
                llm.isThinking = isThinking
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ text: String, leadingPadding: CGFloat = 48) -> some View {
        Markdown(text)
            .textSelection(.enabled)
        #if os(iOS) || os(visionOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        #else
            .padding(.horizontal, 16 * 2 / 3)
            .padding(.vertical, 8)
        #endif
            .background(platformBackgroundColor)
        #if os(iOS) || os(visionOS)
            .mask(RoundedRectangle(cornerRadius: 24))
        #elseif os(macOS)
            .mask(RoundedRectangle(cornerRadius: 16))
        #endif
            .padding(.leading, leadingPadding)
    }

    @ViewBuilder
    private func attachmentsGallery(for urls: [URL]) -> some View {
        if urls.count <= 2 {
            attachmentsRow(for: urls)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                attachmentsRow(for: urls)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func attachmentsRow(for urls: [URL]) -> some View {
        HStack(spacing: 12) {
            ForEach(urls, id: \.self) { url in
                attachmentTile(for: url)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 4)
    }

    private func attachmentTile(for url: URL) -> some View {
        Group {
            if let localImage = loadLocalImage(at: url) {
                localImage
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    case .failure:
                        placeholderTile
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .frame(width: 88, height: 88)
    }

    private var placeholderTile: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
            }
    }

    private func loadLocalImage(at url: URL) -> Image? {
        guard url.isFileURL, let resolvedURL = resolveAttachmentURL(from: url) else { return nil }

        #if canImport(UIKit)
        if
            let data = try? Data(contentsOf: resolvedURL, options: [.mappedIfSafe]),
            let uiImage = UIImage(data: data)
        {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if
            let data = try? Data(contentsOf: resolvedURL, options: [.mappedIfSafe]),
            let nsImage = NSImage(data: data)
        {
            return Image(nsImage: nsImage)
        }
        #endif

        #if DEBUG
        print("Failed to decode chat attachment: \(resolvedURL.path(percentEncoded: false))")
        #endif
        return nil
    }

    private func resolveAttachmentURL(from originalURL: URL) -> URL? {
        let fileManager = FileManager.default
        let path = originalURL.path(percentEncoded: false)

        if fileManager.fileExists(atPath: path) {
            return originalURL
        }

        guard let attachmentsDirectory else { return nil }
        let fallbackURL = attachmentsDirectory.appendingPathComponent(originalURL.lastPathComponent)
        if fileManager.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }

        #if DEBUG
        print("Chat attachment missing from expected paths: \(originalURL.absoluteString)")
        #endif
        return nil
    }

    private var attachmentsDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ChatAttachments", isDirectory: true)
    }

    let platformBackgroundColor: Color = {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()
}

struct ConversationView: View {
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager
    let thread: Thread
    let generatingThreadID: UUID?

    @State private var scrollID: String?
    @State private var scrollInterrupted = false

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(thread.sortedMessages) { message in
                        MessageView(message: message)
                            .padding()
                            .id(message.id.uuidString)
                    }

                    if llm.running && !llm.output.isEmpty && thread.id == generatingThreadID {
                        VStack {
                            MessageView(message: Message(role: .assistant, content: llm.output + " 🌕"))
                        }
                        .padding()
                        .id("output")
                        .onAppear {
                            print("output appeared")
                            scrollInterrupted = false // reset interruption when a new output begins
                        }
                    }

                    Rectangle()
                        .fill(.clear)
                        .frame(height: 1)
                        .id("bottom")
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollID, anchor: .bottom)
            .onChange(of: llm.output) { _, _ in
                // auto scroll to bottom
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }

                if !llm.isThinking {
                    appManager.playHaptic()
                }
            }
            .onChange(of: scrollID) { _, _ in
                // interrupt auto scroll to bottom if user scrolls away
                if llm.running {
                    scrollInterrupted = true
                }
            }
        }
        .defaultScrollAnchor(.bottom)
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
    }
}

#Preview {
    ConversationView(thread: Thread(), generatingThreadID: nil)
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}
