//
//  LLMEvaluator.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import MLXVLM
import SwiftUI

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
}

@Observable
@MainActor
class LLMEvaluator {
    var running = false
    var cancelled = false
    var output = ""
    var modelInfo = ""
    var stat = ""
    var progress = 0.0
    var thinkingTime: TimeInterval?
    var collapsed: Bool = false
    var isThinking: Bool = false

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

    var modelConfiguration = ModelConfiguration.defaultModel

    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0 // reset progress
        loadState = .idle
        modelConfiguration = model
        _ = try? await load(modelName: model.name)
    }

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 8192

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load(modelName: String) async throws -> ModelContainer {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }

        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer: ModelContainer
            if model.isVisionModel {
                modelContainer = try await VLMModelFactory.shared.loadContainer(configuration: model) {
                    [modelConfiguration] progress in
                    Task { @MainActor in
                        self.modelInfo =
                            "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                        self.progress = progress.fractionCompleted
                    }
                }
            } else {
                modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: model) {
                    [modelConfiguration] progress in
                    Task { @MainActor in
                        self.modelInfo =
                            "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                        self.progress = progress.fractionCompleted
                    }
                }
            }
            modelInfo =
                "Loaded \(modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case let .loaded(modelContainer):
            return modelContainer
        }
    }

    func stop() {
        isThinking = false
        cancelled = true
    }

    func generate(modelName: String, thread: Thread, systemPrompt: String) async -> String {
        guard !running else { return "" }

        running = true
        cancelled = false
        output = ""
        startTime = Date()

        do {
            let modelContainer = try await load(modelName: modelName)

            let configuration = await modelContainer.configuration

            if configuration.modelType == .reasoning {
                isThinking = true
            }

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let chatHistory = buildChatHistory(
                thread: thread, systemPrompt: systemPrompt,
                configuration: configuration)
            let userInput = UserInput(
                chat: chatHistory,
                processing: .init(resize: .init(width: 1024, height: 1024)))

            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: userInput)
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in

                    var cancelled = false
                    Task { @MainActor in
                        cancelled = self.cancelled
                    }

                    // update the output -- this will make the view show the text as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }

                    if tokens.count >= maxTokens || cancelled {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != output {
                output = result.output
            }
            stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"

        } catch {
            output = "Failed: \(error)"
        }

        running = false
        return output
    }

    func unloadModel() {
        running = false
        cancelled = false
        isThinking = false
        output = ""
        modelInfo = ""
        stat = ""
        progress = 0.0
        thinkingTime = nil
        startTime = nil
        loadState = .idle
    }

    private func buildChatHistory(
        thread: Thread,
        systemPrompt: String,
        configuration: ModelConfiguration
    ) -> [Chat.Message] {
        var chat: [Chat.Message] = [
            Chat.Message(role: .system, content: systemPrompt)
        ]

        for message in thread.sortedMessages {
            let role: Chat.Message.Role =
                switch message.role {
                case .assistant:
                    .assistant
                case .user:
                    .user
                case .system:
                    .system
                }

            let formattedContent = configuration.formatForTokenizer(message.content)
            let images = message.imageAttachments.map { UserInput.Image.url($0) }

            chat.append(
                Chat.Message(
                    role: role,
                    content: formattedContent,
                    images: images,
                    videos: []))
        }

        return chat
    }
}
