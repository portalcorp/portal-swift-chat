//
//  ChatView.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/3/24.
//

import MarkdownUI
import StoreKit
import SwiftUI

#if os(iOS)
    import PhotosUI
    import UniformTypeIdentifiers
    import UIKit
#endif

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Namespace var bottomID
    @State var showModelPicker = false
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showOnboarding: Bool

    @Environment(\.requestReview) private var requestReview

    @State var thinkingTime: TimeInterval?

    @State var generatingThreadID: UUID?
    @State var attachmentMenuConfig = AttachmentMenuConfig(symbolImage: "plus")
    @State var shouldRestorePromptFocus = false
    #if os(iOS)
        @State var imageAttachments: [ImageAttachment] = []
        @State var fileAttachments: [FileAttachment] = []
        @State var activeAttachmentSheet: AttachmentSheet?
    #endif

    @State private var showMissingModelAlert = false

    var isPromptEmpty: Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #if os(iOS)
            return trimmed && imageAttachments.isEmpty && fileAttachments.isEmpty
        #else
            return trimmed
        #endif
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

    #if os(iOS)
        var hasAttachmentPreviews: Bool {
            !imageAttachments.isEmpty || !fileAttachments.isEmpty
        }
    #endif

    var conversationTitle: String? {
        guard
            let currentThread,
            let firstMessage = currentThread.sortedMessages.first
        else { return nil }

        return firstMessage.content
    }

    var currentModelDisplayName: String {
        let rawName = appManager.currentModelName ?? "chat"
        if rawName.hasPrefix("mlx-community/") {
            return String(rawName.dropFirst("mlx-community/".count))
        }
        return rawName
    }

    var navigationPrimaryTitle: String {
        conversationTitle ?? currentModelDisplayName
    }

    var navigationSubtitle: String? {
        conversationTitle == nil ? nil : currentModelDisplayName
    }

    var isUsingDefaultNavigationTitle: Bool {
        conversationTitle == nil
    }

    func startNewChat() {
        currentThread = nil
        isPromptFocused = true
        appManager.playHaptic()
        requestReviewIfAppropriate()
    }

    private func requestReviewIfAppropriate() {
        if appManager.numberOfVisits - appManager.numberOfVisitsOfLastRequest >= 5 {
            requestReview()
            appManager.numberOfVisitsOfLastRequest = appManager.numberOfVisits
        }
    }

    var body: some View {
        withAttachmentMenu {
            chatNavigationContent
        }
        .alert("no models installed", isPresented: $showMissingModelAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("No models are installed. Please install one to start chatting.")
        }
    }

    private var chatNavigationContent: some View {
        NavigationStack {
            chatMainContent
        }
    }

    @ViewBuilder
    private var chatMainContent: some View {
        VStack(spacing: 0) {
            if let currentThread = currentThread {
                ConversationView(
                    thread: currentThread, generatingThreadID: generatingThreadID)
            } else {
                Spacer()
                Image(systemName: appManager.getMoonPhaseIcon())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.quaternary)
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .navigationTitle(navigationPrimaryTitle)
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showModelPicker) {
            NavigationStack {
                ModelsSettingsView()
                    .environment(llm)
                    #if os(visionOS)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(action: { showModelPicker.toggle() }) {
                                    Image(systemName: "xmark")
                                }
                            }
                        }
                    #endif
            }
            #if os(iOS)
                .presentationDragIndicator(.visible)
                .if(appManager.userInterfaceIdiom == .phone) { view in
                    view.presentationDetents([.fraction(0.4)])
                }
            #elseif os(macOS)
                .toolbar {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(action: { showModelPicker.toggle() }) {
                            Text("close")
                        }
                    }
                }
            #endif
        }
        .toolbar {
            #if os(iOS) || os(visionOS)
                ToolbarItem(placement: .principal) {
                    navigationTitleToolbarContent
                }
                if appManager.userInterfaceIdiom == .phone {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            appManager.playHaptic()
                            showChats.toggle()
                        }) {
                            Image(systemName: "list.bullet")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startNewChat) {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("N", modifiers: [.command])
                }
            #elseif os(macOS)
                ToolbarItem(placement: .principal) {
                    navigationTitleToolbarContent
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: startNewChat) {
                        Label("new", systemImage: "plus")
                    }
                    .keyboardShortcut("N", modifiers: [.command])
                }
            #endif
        }
    }

    private var navigationTitleToolbarContent: some View {
        Button {
            appManager.playHaptic()
            showModelPicker = true
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(navigationPrimaryTitle)
                        .font(.headline)
                        .foregroundStyle(
                            isUsingDefaultNavigationTitle ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isUsingDefaultNavigationTitle {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(270))
                            .font(.caption2)
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                }
                if let subtitle = navigationSubtitle, !subtitle.isEmpty {
                    HStack(spacing: 4) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(270))
                            .font(.caption2)
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func generate() {
        guard !appManager.installedModels.isEmpty, let activeModel = appManager.currentModelName, !activeModel.isEmpty else {
            showOnboarding = true
            showMissingModelAlert = true
            return
        }

        if !isPromptEmpty {
            if currentThread == nil {
                let newThread = Thread()
                currentThread = newThread
                modelContext.insert(newThread)
                try? modelContext.save()
            }

            if let currentThread = currentThread {
                generatingThreadID = currentThread.id
                Task {
                    let message = prompt
                    #if os(iOS)
                        let savedImageURLs = persistImageAttachments(imageAttachments)
                        imageAttachments.removeAll()
                        fileAttachments.removeAll()
                    #else
                        let savedImageURLs: [URL] = []
                    #endif
                    prompt = ""
                    appManager.playHaptic()
                    sendMessage(
                        Message(
                            role: .user, content: message, thread: currentThread,
                            imageAttachments: savedImageURLs))
                    isPromptFocused = true
                    let output = await llm.generate(
                        modelName: activeModel, thread: currentThread,
                        systemPrompt: appManager.systemPrompt)
                    sendMessage(
                        Message(
                            role: .assistant, content: output, thread: currentThread,
                            generatingTime: llm.thinkingTime))
                    generatingThreadID = nil
                }
            }
        }
    }

    private func sendMessage(_ message: Message) {
        appManager.playHaptic()
        modelContext.insert(message)
        try? modelContext.save()
    }

    #if os(iOS)
        private func persistImageAttachments(_ attachments: [ImageAttachment]) -> [URL] {
            guard !attachments.isEmpty else { return [] }

            let fileManager = FileManager.default
            guard
                let baseDirectory = fileManager.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first
            else { return [] }

            let attachmentsDirectory = baseDirectory.appendingPathComponent(
                "ChatAttachments", isDirectory: true)

            if !fileManager.fileExists(atPath: attachmentsDirectory.path) {
                do {
                    try fileManager.createDirectory(
                        at: attachmentsDirectory, withIntermediateDirectories: true)
                } catch {
                    print("Failed to create attachments directory: \(error.localizedDescription)")
                    return []
                }
            }

            return attachments.compactMap { attachment in
                let image = attachment.image

                if let jpegData = image.jpegData(compressionQuality: 0.9) {
                    let url = attachmentsDirectory.appendingPathComponent(
                        UUID().uuidString, conformingTo: .jpeg)
                    do {
                        try jpegData.write(to: url)
                        return url
                    } catch {
                        print("Failed to save JPEG attachment: \(error.localizedDescription)")
                    }
                } else if let pngData = image.pngData() {
                    let url = attachmentsDirectory.appendingPathComponent(
                        UUID().uuidString, conformingTo: .png)
                    do {
                        try pngData.write(to: url)
                        return url
                    } catch {
                        print("Failed to save PNG attachment: \(error.localizedDescription)")
                    }
                }

                return nil
            }
        }
    #else
        private func persistImageAttachments(_ attachments: [ImageAttachment]) -> [URL] { [] }
    #endif
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(
        currentThread: .constant(nil), isPromptFocused: $isPromptFocused,
        showChats: .constant(false), showOnboarding: .constant(false))
}
