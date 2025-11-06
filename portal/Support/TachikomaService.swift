//
//  TachikomaService.swift
//  portal
//
//  Created by ChatGPT on 2/22/25.
//

import Foundation
import OSLog
import Tachikoma
import TachikomaMCP

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@Observable
@MainActor
final class TachikomaService {
    private let logger = Logger(subsystem: "chat.portal", category: "tachikoma")
    private let configuration: TachikomaConfiguration

    private var mcpClient: MCPClient?
    private var cachedMCPSignature: String?
    private var cachedTools: [AgentTool] = []

    var running = false
    var output = ""
    var lastError: String?
    var lastMCPSyncError: String?

    init() {
        configuration = TachikomaConfiguration(loadFromEnvironment: false)
        configuration.setVerbose(false)
        TachikomaConfiguration.default = configuration
    }

    deinit {
        Task {
            await disconnectMCP()
        }
    }

    func reset() async {
        output = ""
        lastError = nil
        lastMCPSyncError = nil
        running = false
        await disconnectMCP()
    }

    func generate(
        modelIdentifier: String,
        thread: Thread,
        systemPrompt: String,
        appManager: AppManager
    ) async -> String {
        guard !running else {
            return "Failed: Tachikoma request already in progress."
        }

        guard let languageModel = TachikomaModelRegistry.languageModel(for: modelIdentifier) else {
            return "Failed: Unknown remote model \(modelIdentifier)."
        }

        running = true
        output = ""
        lastError = nil

        defer { running = false }

        syncConfiguration(appManager: appManager)

        let tools = await ensureMCPTools(config: appManager.mcpServerConfig)

        if let lastMCPSyncError {
            logger.error("MCP sync error: \(lastMCPSyncError, privacy: .public)")
        }

        let messages = buildMessages(thread: thread, systemPrompt: systemPrompt)
        let settings = GenerationSettings(temperature: 0.6)
        let maxSteps = tools.isEmpty ? 1 : 4

        do {
            if tools.isEmpty {
                return try await streamResponse(
                    model: languageModel,
                    messages: messages,
                    settings: settings
                )
            } else {
                // Fall back to single-shot generation when tools are involved
                let result = try await Tachikoma.generateText(
                    model: languageModel,
                    messages: messages,
                    tools: tools,
                    settings: settings,
                    maxSteps: maxSteps,
                    configuration: configuration
                )
                output = result.text
                return result.text
            }
        } catch {
            lastError = error.localizedDescription
            logger.error("Tachikoma generate failed: \(error.localizedDescription, privacy: .public)")
            return "Failed: \(error.localizedDescription)"
        }
    }

    private func syncConfiguration(appManager: AppManager) {
        for provider in Provider.standardProviders {
            if let apiKey = appManager.apiKey(for: provider) {
                configuration.setAPIKey(apiKey, for: provider)
            } else {
                configuration.removeAPIKey(for: provider)
            }

            if let baseURL = appManager.baseURL(for: provider) {
                configuration.setBaseURL(baseURL, for: provider)
            } else {
                configuration.removeBaseURL(for: provider)
            }
        }
    }

    private func streamResponse(
        model: LanguageModel,
        messages: [ModelMessage],
        settings: GenerationSettings
    ) async throws -> String {
        let streamResult = try await Tachikoma.streamText(
            model: model,
            messages: messages,
            settings: settings,
            configuration: configuration
        )

        var aggregated = ""

        do {
            for try await delta in streamResult.stream {
                switch delta.type {
                case .textDelta:
                    if let text = delta.content {
                        aggregated += text
                        output = aggregated
                    }
                case .reasoning:
                    // Surface reasoning channel as part of the stream for visibility
                    if let text = delta.content, delta.channel == .thinking {
                        aggregated += text
                        output = aggregated
                    }
                case .done:
                    if let usage = delta.usage {
                        logger.debug("Streaming completed with output tokens: \(usage.outputTokens)")
                    }
                default:
                    continue
                }
                await Task.yield()
            }
        } catch {
            throw error
        }

        return aggregated
    }

    private func ensureMCPTools(config: MCPServerConfig?) async -> [AgentTool] {
        guard let config else {
            await disconnectMCP()
            return []
        }

        let signature = signature(for: config)
        if cachedMCPSignature != signature {
            await disconnectMCP()
            let client = MCPClient(name: "portal-mcp", config: config)
            do {
                try await client.connect()
                let availableTools = await client.tools
                cachedTools = availableTools.map {
                    MCPToolAdapter.toAgentTool(from: $0, client: client)
                }
                mcpClient = client
                cachedMCPSignature = signature
                lastMCPSyncError = nil
            } catch {
                lastMCPSyncError = error.localizedDescription
                cachedMCPSignature = nil
                cachedTools = []
            }
        }

        return cachedTools
    }

    private func disconnectMCP() async {
        if let mcpClient {
            await mcpClient.disconnect()
        }
        mcpClient = nil
        cachedTools = []
        cachedMCPSignature = nil
    }

    private func buildMessages(thread: Thread, systemPrompt: String) -> [ModelMessage] {
        var messages: [ModelMessage] = []
        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            messages.append(.system(trimmedSystem))
        }

        for message in thread.sortedMessages {
            switch message.role {
            case .system:
                messages.append(.system(message.content))
            case .user:
                let imageParts = buildImageParts(from: message.imageAttachments)
                if imageParts.isEmpty {
                    messages.append(.user(message.content))
                } else {
                    var parts: [ModelMessage.ContentPart] = [.text(message.content)]
                    parts.append(contentsOf: imageParts)
                    messages.append(ModelMessage(role: .user, content: parts))
                }
            case .assistant:
                messages.append(.assistant(message.content))
            }
        }

        return messages
    }

    private func buildImageParts(from urls: [URL]) -> [ModelMessage.ContentPart] {
        urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            let encoded = data.base64EncodedString()
            let mimeType: String
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg":
                mimeType = "image/jpeg"
            case "gif":
                mimeType = "image/gif"
            default:
                mimeType = "image/png"
            }
            return .image(.init(data: encoded, mimeType: mimeType))
        }
    }

    private func signature(for config: MCPServerConfig) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(config), let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(config.command)|\(config.transport)|\(UUID().uuidString)"
    }
}
