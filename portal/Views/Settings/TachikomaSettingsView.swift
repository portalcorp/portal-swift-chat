//
//  TachikomaSettingsView.swift
//  portal
//
//  Created by ChatGPT on 2/22/25.
//

import SwiftUI

struct TachikomaSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(TachikomaService.self) var tachikoma

    var body: some View {
        Form {
            apiKeySection
            baseURLSection
            mcpSection
        }
        .navigationTitle("remote config")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var apiKeySection: some View {
        Section(
            header: Text("api keys"),
            footer: Text("Keys are stored securely in UserDefaults. Leave blank to rely on environment variables.")
        ) {
            secureFieldRow(
                title: "OpenAI",
                systemImage: "o.circle",
                keyPath: \.tachikomaOpenAIAPIKey,
                placeholder: "sk-..."
            )
            secureFieldRow(
                title: "Anthropic",
                systemImage: "a.circle",
                keyPath: \.tachikomaAnthropicAPIKey,
                placeholder: "sk-ant-..."
            )
            secureFieldRow(
                title: "Google Gemini",
                systemImage: "g.circle",
                keyPath: \.tachikomaGoogleAPIKey,
                placeholder: "AIza..."
            )
            secureFieldRow(
                title: "Grok (xAI)",
                systemImage: "x.circle",
                keyPath: \.tachikomaGrokAPIKey,
                placeholder: "x-ai-..."
            )
            secureFieldRow(
                title: "Groq",
                systemImage: "speedometer",
                keyPath: \.tachikomaGroqAPIKey,
                placeholder: "gsk_..."
            )
            secureFieldRow(
                title: "Mistral",
                systemImage: "m.circle",
                keyPath: \.tachikomaMistralAPIKey,
                placeholder: "mistral-..."
            )
        }
    }

    private var baseURLSection: some View {
        Section(
            header: Text("custom base urls"),
            footer: Text("Override provider endpoints when using proxies or self-hosted gateways. Leave blank to use the provider defaults.")
        ) {
            textFieldRow(
                "OpenAI Base URL",
                systemImage: "network",
                keyPath: \.tachikomaOpenAIBaseURL,
                placeholder: "https://api.openai.com/v1"
            )
            textFieldRow(
                "Anthropic Base URL",
                systemImage: "network",
                keyPath: \.tachikomaAnthropicBaseURL,
                placeholder: "https://api.anthropic.com"
            )
            textFieldRow(
                "Google Base URL",
                systemImage: "network",
                keyPath: \.tachikomaGoogleBaseURL,
                placeholder: "https://generativelanguage.googleapis.com/v1beta"
            )
            textFieldRow(
                "Grok Base URL",
                systemImage: "network",
                keyPath: \.tachikomaGrokBaseURL,
                placeholder: "https://api.x.ai/v1"
            )
            textFieldRow(
                "Groq Base URL",
                systemImage: "network",
                keyPath: \.tachikomaGroqBaseURL,
                placeholder: "https://api.groq.com/openai/v1"
            )
            textFieldRow(
                "Mistral Base URL",
                systemImage: "network",
                keyPath: \.tachikomaMistralBaseURL,
                placeholder: "https://api.mistral.ai/v1"
            )
            textFieldRow(
                "Ollama Base URL",
                systemImage: "server.rack",
                keyPath: \.tachikomaOllamaBaseURL,
                placeholder: "http://localhost:11434"
            )
        }
    }

    private var mcpSection: some View {
        Section(
            header: Text("model context protocol (mcp)"),
            footer: Text("Provide KEY=VALUE pairs per line for environment variables and headers. Arguments accept whitespace or newline separated values.")
        ) {
            Toggle("Enable MCP client", isOn: binding(for: \.tachikomaMCPEnabled))
            Picker("Transport", selection: binding(for: \.tachikomaMCPTransport)) {
                Text("stdio").tag("stdio")
                Text("http").tag("http")
                Text("sse").tag("sse")
            }
            .pickerStyle(.segmented)
            .disabled(!appManager.tachikomaMCPEnabled)

            textFieldRow(
                "Command / URL",
                systemImage: "terminal",
                keyPath: \.tachikomaMCPCommand,
                placeholder: "/usr/local/bin/my-mcp-server"
            )
            .disabled(!appManager.tachikomaMCPEnabled)

            textFieldRow(
                "Arguments",
                systemImage: "list.bullet",
                keyPath: \.tachikomaMCPArguments,
                placeholder: "--port 8080"
            )
            .disabled(!appManager.tachikomaMCPEnabled)

            textEditorRow(
                title: "Environment",
                systemImage: "leaf",
                keyPath: \.tachikomaMCPEnvironment,
                placeholder: "API_TOKEN=..."
            )
            .disabled(!appManager.tachikomaMCPEnabled)

            textEditorRow(
                title: "HTTP Headers",
                systemImage: "envelope",
                keyPath: \.tachikomaMCPHeaders,
                placeholder: "Authorization=Bearer …"
            )
            .disabled(!appManager.tachikomaMCPEnabled || appManager.tachikomaMCPTransport == "stdio")

            Stepper(
                value: binding(for: \.tachikomaMCPTimeout),
                in: 5...120,
                step: 5
            ) {
                Text("Timeout: \(Int(appManager.tachikomaMCPTimeout)) s")
            }
            .disabled(!appManager.tachikomaMCPEnabled)

            if appManager.tachikomaMCPEnabled {
                Button("Reset MCP connection") {
                    Task { await tachikoma.reset() }
                }
            }
        }
    }

    private func secureFieldRow(
        title: String,
        systemImage: String,
        keyPath: ReferenceWritableKeyPath<AppManager, String>,
        placeholder: String
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            SecureField(placeholder, text: binding(for: keyPath))
                .textContentType(.password)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func textFieldRow(
        _ title: String,
        systemImage: String,
        keyPath: ReferenceWritableKeyPath<AppManager, String>,
        placeholder: String
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            TextField(placeholder, text: binding(for: keyPath))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        }
    }

    private func textEditorRow(
        title: String,
        systemImage: String,
        keyPath: ReferenceWritableKeyPath<AppManager, String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
            ZStack(alignment: .topLeading) {
                if appManager[keyPath: keyPath].isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                TextEditor(text: binding(for: keyPath))
                    .frame(minHeight: 80)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func binding<Value>(for keyPath: ReferenceWritableKeyPath<AppManager, Value>) -> Binding<Value> {
        Binding(
            get: { appManager[keyPath: keyPath] },
            set: { appManager[keyPath: keyPath] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        TachikomaSettingsView()
            .environmentObject(AppManager())
            .environment(TachikomaService())
    }
}
