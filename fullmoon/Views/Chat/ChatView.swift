//
//  ChatView.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/3/24.
//

import MarkdownUI
import SwiftUI
#if os(iOS)
import PhotosUI
import UniformTypeIdentifiers
import UIKit
#endif

#if os(iOS)
private struct ImageAttachment: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
}

private struct FileAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let displayName: String
}

private struct AudioAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let duration: TimeInterval
    let waveform: [CGFloat]
}

private enum AttachmentSheet: Identifiable {
    case camera
    case photos
    case files

    var id: String {
        switch self {
        case .camera: "camera"
        case .photos: "photos"
        case .files: "files"
        }
    }
}
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
    @Binding var showSettings: Bool
    
    @State var thinkingTime: TimeInterval?
    
    @State private var generatingThreadID: UUID?
    @State private var attachmentMenuConfig = AttachmentMenuConfig(symbolImage: "plus")
#if os(iOS)
    @State private var imageAttachments: [ImageAttachment] = []
    @State private var fileAttachments: [FileAttachment] = []
    @State private var audioAttachment: AudioAttachment?
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlaybackController = AudioPlaybackController()
    @State private var activeAttachmentSheet: AttachmentSheet?
    @State private var isAudioRecorderVisible = false
    @State private var audioRecordingError: String?
#endif

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        !imageAttachments.isEmpty || audioAttachment != nil || !fileAttachments.isEmpty
    }
#endif

    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField("message", text: $prompt, axis: .vertical)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
            #if os(iOS) || os(visionOS)
                .padding(.horizontal, 16)
            #elseif os(macOS)
                .padding(.horizontal, 12)
                .onSubmit {
                    handleShiftReturn()
                }
                .submitLabel(.send)
            #endif
                .padding(.vertical, 8)
            #if os(iOS) || os(visionOS)
                .frame(minHeight: 48)
            #elseif os(macOS)
                .frame(minHeight: 32)
            #endif
            #if os(iOS)
            .onSubmit {
                isPromptFocused = true
                generate()
            }
            #endif

            if llm.running {
                stopButton
            } else {
                generateButton
            }
        }
        #if os(iOS) || os(visionOS)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(platformBackgroundColor)
        )
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(platformBackgroundColor)
        )
        #endif
    }

#if os(iOS)
    var attachmentsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !imageAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(imageAttachments) { attachment in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: attachment.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                                Button {
                                    removeImageAttachment(attachment)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Circle().fill(.black.opacity(0.6)))
                                        .shadow(radius: 2)
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let audioAttachment {
                AudioAttachmentPreview(
                    attachment: audioAttachment,
                    playbackController: audioPlaybackController,
                    onRemove: removeAudioAttachment
                )
            }

            if !fileAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(fileAttachments) { attachment in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.blue.opacity(0.1))
                                )

                            Text(attachment.displayName)
                                .font(.callout)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                removeFileAttachment(attachment)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(platformBackgroundColor)
                        )
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    var audioRecordingInput: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                cancelAudioRecording()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(Color.secondary.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                AudioWaveformView(levels: audioRecorder.levels, animate: audioRecorder.isRecording, tint: .accentColor)
                    .frame(height: 46)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor.opacity(0.06))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(formatDuration(audioRecorder.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                audioRecorder.togglePause()
            } label: {
                Image(systemName: audioRecorder.isRecording ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(audioRecorder.isRecording ? Color.accentColor : Color.accentColor.opacity(0.85))
                    )
            }

            Button {
                completeAudioRecording()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(Color.accentColor)
                    )
            }
            .disabled(audioRecorder.duration < 0.5)
            .opacity(audioRecorder.duration < 0.5 ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }
#endif
    var attachmentButton: some View {
        AttachmentMenuButton(config: $attachmentMenuConfig) {
            Group {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
            }
            #if os(iOS) || os(visionOS)
            .frame(width: 48, height: 48)
            #elseif os(macOS)
            .frame(width: 32, height: 32)
            #endif
            .background {
                Circle()
                    .fill(platformBackgroundColor)
            }
        } onTap: {
            appManager.playHaptic()
            isPromptFocused = false
        }
#if os(iOS)
        .opacity(isAudioRecorderVisible ? 0.4 : 1)
        .allowsHitTesting(!isAudioRecorderVisible)
#endif
    }

    var generateButton: some View {
        Button {
            generate()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
            #if os(iOS) || os(visionOS)
                .frame(width: 24, height: 24)
            #else
                .frame(width: 16, height: 16)
            #endif
        }
        .disabled(isPromptEmpty)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        #else
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    var stopButton: some View {
        Button {
            llm.stop()
        } label: {
            Image(systemName: "stop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
            #if os(iOS) || os(visionOS)
                .frame(width: 24, height: 24)
            #else
                .frame(width: 16, height: 16)
            #endif
        }
        .disabled(llm.cancelled)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        #else
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }

        return "chat"
    }

    var body: some View {
        AttachmentMenuView(config: $attachmentMenuConfig) {
            NavigationStack {
                VStack(spacing: 0) {
                    if let currentThread = currentThread {
                        ConversationView(thread: currentThread, generatingThreadID: generatingThreadID)
                    } else {
                        Spacer()
                        Image(systemName: appManager.getMoonPhaseIcon())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundStyle(.quaternary)
                        Spacer()
                    }

#if os(iOS)
                    if hasAttachmentPreviews {
                        attachmentsPreview
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
#endif

                    HStack(alignment: .bottom) {
                        attachmentButton
#if os(iOS)
                        if isAudioRecorderVisible {
                            audioRecordingInput
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            chatInput
                        }
#else
                        chatInput
#endif
                    }
                    .padding()
                }
                .navigationTitle(chatTitle)
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
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.toggle()
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.toggle()
                        }) {
                            Label("settings", systemImage: "gear")
                        }
                    }
                    #endif
                }
        }
        } actions: {
#if os(iOS)
            AttachmentMenuAction(symbolImage: "camera.fill", text: "Camera") {
                attachmentMenuConfig.showMenu = false
                presentCamera()
            }

            AttachmentMenuAction(symbolImage: "photo.on.rectangle.fill", text: "Photos") {
                attachmentMenuConfig.showMenu = false
                presentPhotoLibrary()
            }

            AttachmentMenuAction(symbolImage: "waveform", text: "Audio") {
                attachmentMenuConfig.showMenu = false
                beginAudioRecording()
            }

            AttachmentMenuAction(symbolImage: "doc", text: "Files") {
                attachmentMenuConfig.showMenu = false
                presentDocumentPicker()
            }
#endif
            AttachmentMenuAction(symbolImage: "chevron.up", text: "Choose Model") {
                appManager.playHaptic()
                attachmentMenuConfig.showMenu = false
                showModelPicker = true
            }
        }
#if os(iOS)
        .sheet(item: $activeAttachmentSheet) { sheet in
            switch sheet {
            case .camera:
                CameraPicker { image in
                    handlePickedImage(image)
                }
                .ignoresSafeArea()

            case .photos:
                PhotoLibraryPicker(selectionLimit: 1) { image in
                    handlePickedImage(image)
                }
                .ignoresSafeArea()

            case .files:
                DocumentPicker { urls in
                    handlePickedFiles(urls)
                }
                .ignoresSafeArea()
            }
        }
        .alert("Audio Recording", isPresented: Binding(
            get: { audioRecordingError != nil },
            set: { if !$0 { audioRecordingError = nil } }
        )) {
            Button("OK", role: .cancel) {
                audioRecordingError = nil
            }
        } message: {
            Text(audioRecordingError ?? "")
        }
        .onChange(of: audioAttachment) { newValue in
            if let newValue {
                audioPlaybackController.load(url: newValue.url)
            } else {
                audioPlaybackController.stop()
            }
        }
        .animation(.smooth(duration: 0.25, extraBounce: 0), value: hasAttachmentPreviews)
        .animation(.spring(duration: 0.3), value: isAudioRecorderVisible)
#endif
    }

    private func generate() {
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
                    prompt = ""
                    appManager.playHaptic()
                    sendMessage(Message(role: .user, content: message, thread: currentThread))
                    isPromptFocused = true
                    if let modelName = appManager.currentModelName {
                        let output = await llm.generate(modelName: modelName, thread: currentThread, systemPrompt: appManager.systemPrompt)
                        sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                        generatingThreadID = nil
                    }
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
    private func handlePickedImage(_ image: UIImage) {
        appManager.playHaptic()
        withAnimation(.spring(response: 0.25, dampingFraction: 1)) {
            imageAttachments.append(ImageAttachment(image: image))
        }
    }

    private func removeImageAttachment(_ attachment: ImageAttachment) {
        withAnimation(.easeInOut(duration: 0.2)) {
            imageAttachments.removeAll { $0.id == attachment.id }
        }
    }

    private func handlePickedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        appManager.playHaptic()

        for url in urls {
            let copiedURL: URL?

            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                copiedURL = try? copyToTemporary(url)
            } else {
                copiedURL = try? copyToTemporary(url)
            }

            let finalURL = copiedURL ?? url
            withAnimation(.spring(response: 0.25, dampingFraction: 1)) {
                fileAttachments.append(FileAttachment(url: finalURL, displayName: finalURL.lastPathComponent))
            }
        }
    }

    private func removeFileAttachment(_ attachment: FileAttachment) {
        withAnimation(.easeInOut(duration: 0.2)) {
            fileAttachments.removeAll { $0.id == attachment.id }
        }
        let tempPath = FileManager.default.temporaryDirectory.path
        if attachment.url.path.hasPrefix(tempPath) {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }

    private func removeAudioAttachment() {
        withAnimation(.easeInOut(duration: 0.2)) {
            audioAttachment = nil
        }
        audioPlaybackController.stop()
    }

    private func presentCamera() {
        appManager.playHaptic()
        activeAttachmentSheet = .camera
    }

    private func presentPhotoLibrary() {
        appManager.playHaptic()
        activeAttachmentSheet = .photos
    }

    private func presentDocumentPicker() {
        appManager.playHaptic()
        activeAttachmentSheet = .files
    }

    private func beginAudioRecording() {
        guard !isAudioRecorderVisible else { return }
        appManager.playHaptic()
        isPromptFocused = false
        if audioAttachment != nil {
            removeAudioAttachment()
        }

        audioRecorder.resetState()

        Task {
            do {
                try await audioRecorder.startRecording()
                await MainActor.run {
                    withAnimation(.spring(duration: 0.3)) {
                        isAudioRecorderVisible = true
                    }
                }
            } catch {
                await MainActor.run {
                    audioRecordingError = "We couldn't start recording. Please check microphone permissions in Settings."
                    isAudioRecorderVisible = false
                }
            }
        }
    }

    private func completeAudioRecording() {
        guard let url = audioRecorder.stopRecording() else {
            audioRecordingError = "Recording failed, please try again."
            return
        }

        let waveform = audioRecorder.levels
        let duration = audioRecorder.duration
        audioRecorder.resetState()

        withAnimation(.spring(duration: 0.3)) {
            isAudioRecorderVisible = false
            audioAttachment = AudioAttachment(url: url, duration: duration, waveform: waveform)
        }
    }

    private func cancelAudioRecording() {
        audioRecorder.cancelRecording()
        withAnimation(.easeInOut(duration: 0.2)) {
            isAudioRecorderVisible = false
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration.isFinite else { return "0:00" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "0:00"
    }

    private func copyToTemporary(_ url: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "fullmoon-attachment-\(UUID().uuidString)-\(url.lastPathComponent)")

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
#endif

#if os(macOS)
    private func handleShiftReturn() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            prompt.append("\n")
            isPromptFocused = true
        } else {
            generate()
        }
    }
    #endif
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false))
}

#if os(iOS)
private struct AudioAttachmentPreview: View {
    let attachment: AudioAttachment
    @ObservedObject var playbackController: AudioPlaybackController
    var onRemove: () -> Void

    private var progress: Double {
        guard attachment.duration > 0 else { return 0 }
        return min(max(playbackController.currentTime / attachment.duration, 0), 1)
    }

    private var elapsedLabel: String {
        timeString(playbackController.currentTime)
    }

    private var totalLabel: String {
        timeString(attachment.duration)
    }

    private var normalizedLevels: [CGFloat] {
        attachment.waveform.isEmpty ? Array(repeating: 0.2, count: 30) : attachment.waveform
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    playbackController.togglePlay()
                } label: {
                    Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(Color.accentColor)
                        )
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 6, y: 3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(elapsedLabel)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(totalLabel)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    playbackController.stop()
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(Color.red.opacity(0.9))
                        )
                }
            }

            ZStack(alignment: .leading) {
                AudioWaveformView(levels: normalizedLevels, animate: false, tint: Color.secondary.opacity(0.5))

                AudioWaveformView(levels: normalizedLevels, animate: false, tint: .accentColor)
                    .mask {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(width: max(geometry.size.width * progress, 0))
                            }
                        }
                    }
            }
            .frame(height: 56)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                    )
            )

            Slider(value: Binding(
                get: { progress },
                set: { newValue in
                    playbackController.seek(to: newValue * attachment.duration)
                }
            ), in: 0...1)
            .tint(.accentColor)

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
    }

    private func timeString(_ duration: TimeInterval) -> String {
        guard duration.isFinite else { return "0:00" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "0:00" 
    }
}
#endif
