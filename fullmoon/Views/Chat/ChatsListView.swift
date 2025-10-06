//
//  ChatsListView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftData
import SwiftUI

struct ChatsListView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Thread.timestamp, order: .reverse) var threads: [Thread]
    @State var search = ""
    @State var selection: Thread?

    var body: some View {
        NavigationStack {
            ZStack {
                List(selection: $selection) {
                    #if os(macOS)
                    Section {} // adds some space below the search bar on mac
                    #endif
                    ForEach(filteredThreads, id: \.id) { thread in
                        VStack(alignment: .leading) {
                            ZStack {
                                if let firstMessage = thread.sortedMessages.first {
                                    Text(firstMessage.content)
                                        .lineLimit(1)
                                } else {
                                    Text("untitled")
                                }
                            }
                            .foregroundStyle(.primary)
                            .font(.headline)

                            Text("\(thread.timestamp.formatted())")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        #if os(macOS)
                            .swipeActions {
                                Button("Delete") {
                                    deleteThread(thread)
                                }
                                .tint(.red)
                            }
                            .contextMenu {
                                Button {
                                    deleteThread(thread)
                                } label: {
                                    Text("delete")
                                }
                            }
                        #endif
                            .tag(thread)
                    }
                    .onDelete(perform: deleteThreads)
                }
                .onChange(of: selection) {
                    setCurrentThread(selection)
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #elseif os(macOS) || os(visionOS)
                .listStyle(.sidebar)
                #endif
                if filteredThreads.count == 0 {
                    ContentUnavailableView {
                        Label(threads.count == 0 ? "no chats yet" : "no results", systemImage: "message")
                    }
                }
            }
            .navigationTitle("chats")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "search")
            #elseif os(macOS)
                .searchable(text: $search, placement: .sidebar, prompt: "search")
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    if appManager.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView(currentThread: $currentThread)
                        } label: {
                            Image(systemName: "gear")
                        }
                        #if os(visionOS)
                            .buttonStyle(.bordered)
                        #endif
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            SettingsView(currentThread: $currentThread)
                        } label: {
                            Label("settings", systemImage: "gear")
                        }
                        .keyboardShortcut(",", modifiers: [.command])
                    }
                    #endif
                }
        }
        #if !os(visionOS)
        .tint(appManager.appTintColor.getColor())
        #endif
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }

    var filteredThreads: [Thread] {
        threads.filter { thread in
            search.isEmpty || thread.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(search)
            }
        }
    }

    private func deleteThreads(at offsets: IndexSet) {
        for offset in offsets {
            let thread = threads[offset]

            if let currentThread = currentThread {
                if currentThread.id == thread.id {
                    setCurrentThread(nil)
                }
            }

            // Adding a delay fixes a crash on iOS following a deletion
            let delay = appManager.userInterfaceIdiom == .phone ? 1.0 : 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                modelContext.delete(thread)
            }
        }
    }

    private func deleteThread(_ thread: Thread) {
        if let currentThread = currentThread {
            if currentThread.id == thread.id {
                setCurrentThread(nil)
            }
        }
        modelContext.delete(thread)
    }

    private func setCurrentThread(_ thread: Thread? = nil) {
        currentThread = thread
        isPromptFocused = true
        #if os(iOS)
        dismiss()
        #endif
        appManager.playHaptic()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsListView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
