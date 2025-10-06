import SwiftUI

extension ChatView {
    var attachmentMenuView: some View {
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
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
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
                        Button(action: startNewChat) {
                            Image(systemName: "plus")
                        }
                        .keyboardShortcut("N", modifiers: [.command])
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: startNewChat) {
                            Label("new", systemImage: "plus")
                        }
                        .keyboardShortcut("N", modifiers: [.command])
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
        .animation(.smooth(duration: 0.25, extraBounce: 0), value: hasAttachmentPreviews)
    #endif
    }
}
