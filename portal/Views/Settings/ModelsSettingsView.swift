//
//  ModelsSettingsView.swift
//  portal
//
//  Created by Jordan Singer on 10/5/24.
//

import MLXLMCommon
import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @Environment(TachikomaService.self) var tachikoma
    @State var showOnboardingInstallModelView = false
    @State private var modelPendingDeletion: String?
    @State private var showDeleteModelAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("installed")) {
                if appManager.installedModels.isEmpty {
                    Text("No downloaded models yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appManager.installedModels, id: \.self) { modelName in
                        Button {
                            Task {
                                await switchModel(modelName)
                            }
                        } label: {
                            Label {
                                Text(appManager.modelDisplayName(modelName))
                                    .tint(.primary)
                            } icon: {
                                Image(
                                    systemName: appManager.currentModelSource == .local &&
                                        appManager.currentModelName == modelName
                                        ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                        #if os(iOS) || os(visionOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                scheduleModelDeletion(modelName)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                        #endif
                        .contextMenu {
                            Button(role: .destructive) {
                                scheduleModelDeletion(modelName)
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        #if os(macOS)
                        .buttonStyle(.borderless)
                        #endif
                    }
                }
            }

            ForEach(appManager.remoteModelSections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.models) { remoteModel in
                        remoteModelButton(remoteModel)
                    }
                }
            }

            Section {
                Button {
                    showOnboardingInstallModelView.toggle()
                } label: {
                    Label("install a local model", systemImage: "arrow.down.circle.dotted")
                }
                #if os(macOS)
                .buttonStyle(.borderless)
                #endif
            }

            Section {
                NavigationLink(destination: TachikomaSettingsView()) {
                    Label("remote configuration", systemImage: "slider.horizontal.3")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("models")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showOnboardingInstallModelView) {
            NavigationStack {
                OnboardingInstallModelView(showOnboarding: $showOnboardingInstallModelView)
                    .environment(llm)
                    .toolbar {
                        #if os(iOS) || os(visionOS)
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Image(systemName: "xmark")
                            }
                        }
                        #elseif os(macOS)
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Text("close")
                            }
                        }
                        #endif
                    }
            }
        }
        .alert("remove model?", isPresented: $showDeleteModelAlert) {
            Button("delete", role: .destructive) {
                if let model = modelPendingDeletion {
                    deleteModel(model)
                }
                modelPendingDeletion = nil
            }
            Button("cancel", role: .cancel) {
                modelPendingDeletion = nil
            }
        } message: {
            if let model = modelPendingDeletion {
                Text("This removes \(appManager.modelDisplayName(model)) from this device.")
            } else {
                Text("This removes the selected model from this device.")
            }
        }
    }

    private func switchModel(_ modelName: String) async {
        if let model = ModelConfiguration.availableModels.first(where: {
            $0.name == modelName
        }) {
            appManager.currentModelSource = .local
            appManager.currentModelName = modelName
            appManager.playHaptic()
            await tachikoma.reset()
            await llm.switchModel(model)
        }
    }

    @ViewBuilder
    private func remoteModelButton(_ model: TachikomaRemoteModel) -> some View {
        let isSelected =
            appManager.currentModelSource == .tachikoma &&
            appManager.currentModelName == model.id
        let missingKey = model.provider.requiresAPIKey && appManager.apiKey(for: model.provider) == nil

        Button {
            selectRemoteModel(model)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(model.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if missingKey {
                        Text("Add \(model.provider.displayName) API key in settings.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
            }
        }
        #if os(macOS)
        .buttonStyle(.borderless)
        #endif
    }

    private func selectRemoteModel(_ model: TachikomaRemoteModel) {
        appManager.currentModelSource = .tachikoma
        appManager.currentModelName = model.id
        appManager.playHaptic()
        Task {
            await tachikoma.reset()
        }
    }

    private func scheduleModelDeletion(_ modelName: String) {
        modelPendingDeletion = modelName
        showDeleteModelAlert = true
    }

    private func deleteModel(_ modelName: String) {
        let wasCurrentModel = appManager.currentModelName == modelName
        withAnimation {
            appManager.removeInstalledModel(modelName)
        }

        if wasCurrentModel {
            if let nextModel = appManager.currentModelName {
                Task {
                    await switchModel(nextModel)
                }
            } else {
                llm.unloadModel()
            }
        }

        if appManager.installedModels.isEmpty {
            showOnboardingInstallModelView = true
        }
    }
}

#Preview {
    ModelsSettingsView()
}
