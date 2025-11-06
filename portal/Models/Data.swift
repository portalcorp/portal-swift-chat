//
//  Data.swift
//  portal
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import SwiftData
import MLXLMCommon
import Tachikoma
import TachikomaMCP

enum ChatModelSource: String, CaseIterable, Codable {
    case local
    case tachikoma
}

class AppManager: ObservableObject {
    @AppStorage("systemPrompt") var systemPrompt = "you are a helpful assistant"
    @AppStorage("appTintColor") var appTintColor: AppTintColor = .monochrome
    @AppStorage("appFontDesign") var appFontDesign: AppFontDesign = .standard
    @AppStorage("appFontSize") var appFontSize: AppFontSize = .medium
    @AppStorage("appFontWidth") var appFontWidth: AppFontWidth = .standard
    @AppStorage("currentModelName") var currentModelName: String?
    @AppStorage("currentModelSource") private var currentModelSourceRaw: String = ChatModelSource.local.rawValue
    @AppStorage("shouldPlayHaptics") var shouldPlayHaptics = true
    @AppStorage("numberOfVisits") var numberOfVisits = 0
    @AppStorage("numberOfVisitsOfLastRequest") var numberOfVisitsOfLastRequest = 0
    @AppStorage("tachikomaOpenAIAPIKey") var tachikomaOpenAIAPIKey = ""
    @AppStorage("tachikomaAnthropicAPIKey") var tachikomaAnthropicAPIKey = ""
    @AppStorage("tachikomaGoogleAPIKey") var tachikomaGoogleAPIKey = ""
    @AppStorage("tachikomaGrokAPIKey") var tachikomaGrokAPIKey = ""
    @AppStorage("tachikomaGroqAPIKey") var tachikomaGroqAPIKey = ""
    @AppStorage("tachikomaMistralAPIKey") var tachikomaMistralAPIKey = ""
    @AppStorage("tachikomaOllamaBaseURL") var tachikomaOllamaBaseURL = ""
    @AppStorage("tachikomaOpenAIBaseURL") var tachikomaOpenAIBaseURL = ""
    @AppStorage("tachikomaAnthropicBaseURL") var tachikomaAnthropicBaseURL = ""
    @AppStorage("tachikomaGoogleBaseURL") var tachikomaGoogleBaseURL = ""
    @AppStorage("tachikomaGrokBaseURL") var tachikomaGrokBaseURL = ""
    @AppStorage("tachikomaGroqBaseURL") var tachikomaGroqBaseURL = ""
    @AppStorage("tachikomaMistralBaseURL") var tachikomaMistralBaseURL = ""
    @AppStorage("tachikomaMCPEnabled") var tachikomaMCPEnabled = false
    @AppStorage("tachikomaMCPTransport") var tachikomaMCPTransport: String = "stdio"
    @AppStorage("tachikomaMCPCommand") var tachikomaMCPCommand: String = ""
    @AppStorage("tachikomaMCPArguments") var tachikomaMCPArguments: String = ""
    @AppStorage("tachikomaMCPEnvironment") var tachikomaMCPEnvironment: String = ""
    @AppStorage("tachikomaMCPHeaders") var tachikomaMCPHeaders: String = ""
    @AppStorage("tachikomaMCPTimeout") var tachikomaMCPTimeout: Double = 30
    @AppStorage("tachikomaMCPDescription") var tachikomaMCPDescription: String = ""
    
    var userInterfaceIdiom: LayoutType {
        #if os(visionOS)
        return .vision
        #elseif os(macOS)
        return .mac
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        return .unknown
        #endif
    }
    
    var availableMemory: Double {
        let ramInBytes = ProcessInfo.processInfo.physicalMemory
        let ramInGB = Double(ramInBytes) / (1024 * 1024 * 1024)
        return ramInGB
    }

    var currentModelSource: ChatModelSource {
        get { ChatModelSource(rawValue: currentModelSourceRaw) ?? .local }
        set { currentModelSourceRaw = newValue.rawValue }
    }

    var hasSelectedModel: Bool {
        guard let currentModelName else { return false }
        return !currentModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasLocalModelsInstalled: Bool {
        !installedModels.isEmpty
    }

    var hasUsableModelSelection: Bool {
        guard hasSelectedModel, let modelName = currentModelName else {
            return false
        }

        switch currentModelSource {
        case .local:
            return installedModels.contains(modelName)
        case .tachikoma:
            return TachikomaModelRegistry.model(for: modelName) != nil
        }
    }

    enum LayoutType {
        case mac, phone, pad, vision, unknown
    }
        
    private let installedModelsKey = "installedModels"
        
    @Published var installedModels: [String] = [] {
        didSet {
            saveInstalledModelsToUserDefaults()
        }
    }
    
    init() {
        loadInstalledModelsFromUserDefaults()
    }
    
    func incrementNumberOfVisits() {
        numberOfVisits += 1
        print("app visits: \(numberOfVisits)")
    }
    
    // Function to save the array to UserDefaults as JSON
    private func saveInstalledModelsToUserDefaults() {
        if let jsonData = try? JSONEncoder().encode(installedModels) {
            UserDefaults.standard.set(jsonData, forKey: installedModelsKey)
        }
    }
    
    // Function to load the array from UserDefaults
    private func loadInstalledModelsFromUserDefaults() {
        if let jsonData = UserDefaults.standard.data(forKey: installedModelsKey),
           let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            self.installedModels = decodedArray
        } else {
            self.installedModels = [] // Default to an empty array if there's no data
        }
    }
    
    func playHaptic() {
        if shouldPlayHaptics {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            #endif
        }
    }
    
    func addInstalledModel(_ model: String) {
        if !installedModels.contains(model) {
            installedModels.append(model)
        }
    }

    func removeInstalledModel(_ model: String) {
        removeModelFromDisk(model)
        installedModels.removeAll { $0 == model }
        if currentModelName == model, currentModelSource == .local {
            currentModelName = installedModels.first
        }
    }

    func modelDisplayName(_ modelName: String) -> String {
        if let remote = TachikomaModelRegistry.model(for: modelName) {
            return "\(remote.providerDisplayName) · \(remote.displayName)"
        }
        return modelName
            .replacingOccurrences(of: "mlx-community/", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
    }

    var remoteModelSections: [TachikomaModelSection] {
        TachikomaModelRegistry.sections
    }

    func remoteModel(for identifier: String) -> TachikomaRemoteModel? {
        TachikomaModelRegistry.model(for: identifier)
    }

    func apiKey(for provider: Provider) -> String? {
        switch provider {
        case .openai:
            return sanitized(tachikomaOpenAIAPIKey)
        case .anthropic:
            return sanitized(tachikomaAnthropicAPIKey)
        case .google:
            return sanitized(tachikomaGoogleAPIKey)
        case .grok:
            return sanitized(tachikomaGrokAPIKey)
        case .groq:
            return sanitized(tachikomaGroqAPIKey)
        case .mistral:
            return sanitized(tachikomaMistralAPIKey)
        case .ollama, .lmstudio:
            return nil
        case .custom:
            return nil
        }
    }

    func baseURL(for provider: Provider) -> String? {
        switch provider {
        case .openai:
            return sanitized(tachikomaOpenAIBaseURL)
        case .anthropic:
            return sanitized(tachikomaAnthropicBaseURL)
        case .google:
            return sanitized(tachikomaGoogleBaseURL)
        case .grok:
            return sanitized(tachikomaGrokBaseURL)
        case .groq:
            return sanitized(tachikomaGroqBaseURL)
        case .mistral:
            return sanitized(tachikomaMistralBaseURL)
        case .ollama:
            return sanitized(tachikomaOllamaBaseURL)
        case .lmstudio, .custom:
            return nil
        }
    }

    var mcpServerConfig: MCPServerConfig? {
        guard tachikomaMCPEnabled else { return nil }
        guard let command = sanitized(tachikomaMCPCommand) else { return nil }

        let args = parseArguments(tachikomaMCPArguments)
        let env = parseKeyValuePairs(tachikomaMCPEnvironment)
        let headers = parseKeyValuePairs(tachikomaMCPHeaders)
        let description = sanitized(tachikomaMCPDescription)

        return MCPServerConfig(
            transport: tachikomaMCPTransport,
            command: command,
            args: args,
            env: env,
            headers: headers.isEmpty ? nil : headers,
            enabled: tachikomaMCPEnabled,
            timeout: tachikomaMCPTimeout,
            autoReconnect: true,
            description: description
        )
    }
    
    func getMoonPhaseIcon() -> String {
        // Get current date
        let currentDate = Date()
        
        // Define a base date (known new moon date)
        let baseDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 6))!
        
        // Difference in days between the current date and the base date
        let daysSinceBaseDate = Calendar.current.dateComponents([.day], from: baseDate, to: currentDate).day!
        
        // Moon phase repeats approximately every 29.53 days
        let moonCycleLength = 29.53
        let daysIntoCycle = Double(daysSinceBaseDate).truncatingRemainder(dividingBy: moonCycleLength)
        
        // Determine the phase based on how far into the cycle we are
        switch daysIntoCycle {
        case 0..<1.8457:
            return "moonphase.new.moon" // New Moon
        case 1.8457..<5.536:
            return "moonphase.waxing.crescent" // Waxing Crescent
        case 5.536..<9.228:
            return "moonphase.first.quarter" // First Quarter
        case 9.228..<12.919:
            return "moonphase.waxing.gibbous" // Waxing Gibbous
        case 12.919..<16.610:
            return "moonphase.full.moon" // Full Moon
        case 16.610..<20.302:
            return "moonphase.waning.gibbous" // Waning Gibbous
        case 20.302..<23.993:
            return "moonphase.last.quarter" // Last Quarter
        case 23.993..<27.684:
            return "moonphase.waning.crescent" // Waning Crescent
        default:
            return "moonphase.new.moon" // New Moon (fallback)
        }
    }
}

private extension AppManager {
    func sanitized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func parseArguments(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0.isNewline || $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func parseKeyValuePairs(_ raw: String) -> [String: String] {
        raw
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else { return }
                let parts = trimmedLine.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return }
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    result[key] = value
                }
            }
    }

    func removeModelFromDisk(_ model: String) {
        guard let directory = modelDirectory(for: model) else { return }
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        } catch {
            print("Failed to remove model from disk: \(error.localizedDescription)")
        }
    }

    func modelDirectory(for model: String) -> URL? {
        if let configuration = ModelConfiguration.getModelByName(model) {
            return configuration.modelDirectory(hub: defaultHubApi)
        }

        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        return cachesDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(model, isDirectory: true)
    }
}

enum Role: String, Codable {
    case assistant
    case user
    case system
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var generatingTime: TimeInterval?
    var imageAttachments: [URL] = []
    
    @Relationship(inverse: \Thread.messages) var thread: Thread?
    
    init(
        role: Role,
        content: String,
        thread: Thread? = nil,
        generatingTime: TimeInterval? = nil,
        imageAttachments: [URL] = []
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thread = thread
        self.generatingTime = generatingTime
        self.imageAttachments = imageAttachments
    }
}

@Model
final class Thread {
    @Attribute(.unique) var id: UUID
    var title: String?
    var timestamp: Date
    var modelName: String?
    var modelSourceRaw: String?

    @Relationship var messages: [Message] = []

    var sortedMessages: [Message] {
        return messages.sorted { $0.timestamp < $1.timestamp }
    }

    init(modelName: String? = nil, modelSource: ChatModelSource? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.modelName = modelName
        self.modelSourceRaw = modelSource?.rawValue
    }

    var modelSource: ChatModelSource? {
        get {
            guard let modelSourceRaw else { return nil }
            return ChatModelSource(rawValue: modelSourceRaw)
        }
        set {
            modelSourceRaw = newValue?.rawValue
        }
    }
}

enum AppTintColor: String, CaseIterable {
    case monochrome, blue, brown, gray, green, indigo, mint, orange, pink, purple, red, teal, yellow
    
    func getColor() -> Color {
        switch self {
        case .monochrome:
            .primary
        case .blue:
            .blue
        case .red:
            .red
        case .green:
            .green
        case .yellow:
            .yellow
        case .brown:
            .brown
        case .gray:
            .gray
        case .indigo:
            .indigo
        case .mint:
            .mint
        case .orange:
            .orange
        case .pink:
            .pink
        case .purple:
            .purple
        case .teal:
            .teal
        }
    }
}

enum AppFontDesign: String, CaseIterable {
    case standard, monospaced, rounded, serif
    
    func getFontDesign() -> Font.Design {
        switch self {
        case .standard:
            .default
        case .monospaced:
            .monospaced
        case .rounded:
            .rounded
        case .serif:
            .serif
        }
    }
}

enum AppFontWidth: String, CaseIterable {
    case compressed, condensed, expanded, standard
    
    func getFontWidth() -> Font.Width {
        switch self {
        case .compressed:
            .compressed
        case .condensed:
            .condensed
        case .expanded:
            .expanded
        case .standard:
            .standard
        }
    }
}

enum AppFontSize: String, CaseIterable {
    case xsmall, small, medium, large, xlarge
    
    func getFontSize() -> DynamicTypeSize {
        switch self {
        case .xsmall:
            .xSmall
        case .small:
            .small
        case .medium:
            .medium
        case .large:
            .large
        case .xlarge:
            .xLarge
        }
    }
}
