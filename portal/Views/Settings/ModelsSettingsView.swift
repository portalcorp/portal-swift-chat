//
//  ModelsSettingsView.swift
//  portal
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import MLXLMCommon

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboardingInstallModelView = false
    @State private var modelPendingDeletion: String?
    @State private var showDeleteModelAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("installed")) {
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
                            Image(systemName: appManager.currentModelName == modelName ? "checkmark.circle.fill" : "circle")
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
            
            Button {
                showOnboardingInstallModelView.toggle()
            } label: {
                Label("install a model", systemImage: "arrow.down.circle.dotted")
            }
            #if os(macOS)
            .buttonStyle(.borderless)
            #endif
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
            appManager.currentModelName = modelName
            appManager.playHaptic()
            await llm.switchModel(model)
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
