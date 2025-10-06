import SwiftUI
#if os(iOS)
import UIKit
#endif

extension ChatView {
    @ViewBuilder
    var bottomBar: some View {
        #if os(iOS)
        bottomBarIOS
        #else
        bottomBarDefault
        #endif
    }

    @ViewBuilder
    private var bottomControls: some View {
        HStack(alignment: .bottom, spacing: 12) {
            attachmentButton
            chatInput
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chatInput: some View {
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
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.25))
        }
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(platformBackgroundColor)
        )
        #endif
    }

    private var attachmentButton: some View {
        AttachmentMenuButton(config: $attachmentMenuConfig) {
            Group {
                Image(systemName: "paperclip")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
            }
            #if os(iOS) || os(visionOS)
            .frame(width: 48, height: 48)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.25))
            }
            #elseif os(macOS)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(platformBackgroundColor)
            }
            #endif
        } onTap: {
            appManager.playHaptic()
            isPromptFocused = false
        }
    }

    private var generateButton: some View {
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

    private var stopButton: some View {
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
}

#if os(iOS)
extension ChatView {
    private var bottomBarIOS: some View {
        VStack(spacing: 12) {
            if hasAttachmentPreviews {
                attachmentsPreview
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            bottomControls
        }
        .padding(.horizontal, 20)
        .padding(.top, hasAttachmentPreviews ? 12 : 16)
        .padding(.bottom, 20)
        .background(BottomBarBackground())
    }

    private var attachmentsPreview: some View {
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

    private struct BottomBarBackground: View {
        var body: some View {
            BlurView(style: .systemUltraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.75),
                            Color.black.opacity(0.45),
                            Color.black.opacity(0.2),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .blendMode(.plusDarker)
                )
                .mask(
                    LinearGradient(
                        colors: [
                            .white,
                            Color.white.opacity(0.55),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        }

        private struct BlurView: UIViewRepresentable {
            var style: UIBlurEffect.Style

            func makeUIView(context: Context) -> UIVisualEffectView {
                let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                return view
            }

            func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
                uiView.effect = UIBlurEffect(style: style)
            }
        }
    }

    func handlePickedImage(_ image: UIImage) {
        appManager.playHaptic()
        withAnimation(.spring(response: 0.25, dampingFraction: 1)) {
            imageAttachments.append(ImageAttachment(image: image))
        }
    }

    func removeImageAttachment(_ attachment: ImageAttachment) {
        withAnimation(.easeInOut(duration: 0.2)) {
            imageAttachments.removeAll { $0.id == attachment.id }
        }
    }

    func handlePickedFiles(_ urls: [URL]) {
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

    func removeFileAttachment(_ attachment: FileAttachment) {
        withAnimation(.easeInOut(duration: 0.2)) {
            fileAttachments.removeAll { $0.id == attachment.id }
        }
        let tempPath = FileManager.default.temporaryDirectory.path
        if attachment.url.path.hasPrefix(tempPath) {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }

    func presentCamera() {
        appManager.playHaptic()
        activeAttachmentSheet = .camera
    }

    func presentPhotoLibrary() {
        appManager.playHaptic()
        activeAttachmentSheet = .photos
    }

    func presentDocumentPicker() {
        appManager.playHaptic()
        activeAttachmentSheet = .files
    }

    func copyToTemporary(_ url: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "fullmoon-attachment-\(UUID().uuidString)-\(url.lastPathComponent)")

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
}
#endif

#if !os(iOS)
extension ChatView {
    private var bottomBarDefault: some View {
        bottomControls
            .padding()
    }
}
#endif

#if os(macOS)
extension ChatView {
    func handleShiftReturn() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            prompt.append("\n")
            isPromptFocused = true
        } else {
            generate()
        }
    }
}
#endif
