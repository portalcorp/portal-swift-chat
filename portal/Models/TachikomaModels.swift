//
//  TachikomaModels.swift
//  portal
//
//  Created by ChatGPT on 2/22/25.
//

import Foundation
import Tachikoma

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct TachikomaRemoteModel: Identifiable, Hashable {
    let id: String
    let provider: Provider
    let model: LanguageModel
    let displayName: String
    let summary: String

    var providerDisplayName: String {
        provider.displayName
    }

    static func make(
        provider: Provider,
        openAI: LanguageModel.OpenAI? = nil,
        anthropic: LanguageModel.Anthropic? = nil,
        google: LanguageModel.Google? = nil,
        mistral: LanguageModel.Mistral? = nil,
        grok: LanguageModel.Grok? = nil,
        groq: LanguageModel.Groq? = nil,
        ollama: LanguageModel.Ollama? = nil,
        lmstudio: LanguageModel.LMStudio? = nil,
        displayName: String,
        summary: String
    ) -> TachikomaRemoteModel {
        let model: LanguageModel

        switch provider {
        case .openai:
            precondition(openAI != nil, "LanguageModel.OpenAI variant required")
            model = .openai(openAI!)
        case .anthropic:
            precondition(anthropic != nil, "LanguageModel.Anthropic variant required")
            model = .anthropic(anthropic!)
        case .google:
            precondition(google != nil, "LanguageModel.Google variant required")
            model = .google(google!)
        case .mistral:
            precondition(mistral != nil, "LanguageModel.Mistral variant required")
            model = .mistral(mistral!)
        case .grok:
            precondition(grok != nil, "LanguageModel.Grok variant required")
            model = .grok(grok!)
        case .groq:
            precondition(groq != nil, "LanguageModel.Groq variant required")
            model = .groq(groq!)
        case .ollama:
            precondition(ollama != nil, "LanguageModel.Ollama variant required")
            model = .ollama(ollama!)
        case .lmstudio:
            precondition(lmstudio != nil, "LanguageModel.LMStudio variant required")
            model = .lmstudio(lmstudio!)
        case .custom:
            preconditionFailure("Custom providers are not handled in TachikomaModelRegistry")
        }

        let identifier = "\(provider.identifier):\(model.modelId)"

        return TachikomaRemoteModel(
            id: identifier,
            provider: provider,
            model: model,
            displayName: displayName,
            summary: summary
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TachikomaRemoteModel, rhs: TachikomaRemoteModel) -> Bool {
        lhs.id == rhs.id
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct TachikomaModelSection: Identifiable {
    let provider: Provider
    let models: [TachikomaRemoteModel]

    var id: String { provider.identifier }

    var title: String {
        provider.displayName.lowercased()
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
enum TachikomaModelRegistry {
    static let models: [TachikomaRemoteModel] = {
        var catalog: [TachikomaRemoteModel] = []

        // OpenAI
        catalog.append(
            .make(
                provider: .openai,
                openAI: .gpt4o,
                displayName: "GPT-4o",
                summary: "OpenAI flagship multimodal model"
            )
        )
        catalog.append(
            .make(
                provider: .openai,
                openAI: .o3Mini,
                displayName: "o3-mini",
                summary: "Reasoning model tuned for fast thinking"
            )
        )
        catalog.append(
            .make(
                provider: .openai,
                openAI: .o4Mini,
                displayName: "o4-mini",
                summary: "Efficient GPT-4-class model with tool support"
            )
        )
        catalog.append(
            .make(
                provider: .openai,
                openAI: .gpt41,
                displayName: "GPT-4.1",
                summary: "Extended context general-purpose assistant"
            )
        )
        catalog.append(
            .make(
                provider: .openai,
                openAI: .gpt41Mini,
                displayName: "GPT-4.1 Mini",
                summary: "Cost-optimized GPT-4.1 family variant"
            )
        )

        // Anthropic
        catalog.append(
            .make(
                provider: .anthropic,
                anthropic: .opus4,
                displayName: "Claude 4 Opus",
                summary: "Claude flagship reasoning model"
            )
        )
        catalog.append(
            .make(
                provider: .anthropic,
                anthropic: .sonnet4,
                displayName: "Claude 4 Sonnet",
                summary: "Balanced Claude model with tool use"
            )
        )
        catalog.append(
            .make(
                provider: .anthropic,
                anthropic: .haiku35,
                displayName: "Claude 3.5 Haiku",
                summary: "Fast Claude model for lightweight workloads"
            )
        )

        // Google
        catalog.append(
            .make(
                provider: .google,
                google: .gemini2Flash,
                displayName: "Gemini 2.0 Flash",
                summary: "Fast multimodal model with long context"
            )
        )
        catalog.append(
            .make(
                provider: .google,
                google: .gemini15Pro,
                displayName: "Gemini 1.5 Pro",
                summary: "High-quality multimodal Gemini"
            )
        )

        // Grok (xAI)
        catalog.append(
            .make(
                provider: .grok,
                grok: .grok4,
                displayName: "Grok 4",
                summary: "xAI Grok with strong reasoning and tools"
            )
        )

        // Groq
        catalog.append(
            .make(
                provider: .groq,
                groq: .llama3170b,
                displayName: "Llama 3.1 70B (Groq)",
                summary: "Groq-hosted low-latency Llama 3.1"
            )
        )

        // Mistral
        catalog.append(
            .make(
                provider: .mistral,
                mistral: .large2,
                displayName: "Mistral Large 2",
                summary: "Mistral flagship text + tool model"
            )
        )

        // Ollama (local REST API)
        catalog.append(
            .make(
                provider: .ollama,
                ollama: .llama33,
                displayName: "Ollama · Llama 3.3",
                summary: "Use local Ollama Llama 3.3 via REST"
            )
        )
        catalog.append(
            .make(
                provider: .ollama,
                ollama: .codellama,
                displayName: "Ollama · Code Llama",
                summary: "Local Code Llama for coding tasks"
            )
        )

        return catalog
    }()

    static let modelsByIdentifier: [String: TachikomaRemoteModel] = {
        Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
    }()

    static var sections: [TachikomaModelSection] {
        let grouped = Dictionary(grouping: models) { $0.provider }
        return grouped
            .map { provider, models in
                TachikomaModelSection(
                    provider: provider,
                    models: models.sorted { $0.displayName < $1.displayName }
                )
            }
            .sorted { $0.provider.displayName < $1.provider.displayName }
    }

    static func model(for identifier: String) -> TachikomaRemoteModel? {
        modelsByIdentifier[identifier]
    }

    static func languageModel(for identifier: String) -> LanguageModel? {
        modelsByIdentifier[identifier]?.model
    }

    static func provider(for identifier: String) -> Provider? {
        modelsByIdentifier[identifier]?.provider
    }
}
