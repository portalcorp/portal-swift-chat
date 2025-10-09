//
//  Models.swift
//  portal
//
//  Created by Jordan Singer on 10/4/24.
//

import Foundation
import MLXLMCommon
import MLXVLM

extension ModelConfiguration {
    public enum ModelType {
        case regular, reasoning
    }

    public var modelType: ModelType {
        switch self {
        case .deepseek_r1_distill_qwen_1_5b_4bit: .reasoning
        case .deepseek_r1_distill_qwen_1_5b_8bit: .reasoning
        case .qwen_3_4b_4bit: .reasoning
        case .qwen_3_8b_4bit: .reasoning
        default: .regular
        }
    }

    public var isVisionModel: Bool {
        switch self {
        case .qwen_2_5_vl_3b_instruct_4bit, .qwen_2_vl_2b_instruct_4bit, .smol_vlm_instruct_4bit,
            .gemma3_4B_qat_4bit:
            true
        default: false
        }
    }
}

extension ModelConfiguration {
    public static let llama_3_2_1b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit"
    )

    public static let llama_3_2_3b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit"
    )

    public static let deepseek_r1_distill_qwen_1_5b_4bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"
    )

    public static let deepseek_r1_distill_qwen_1_5b_8bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit"
    )

    public static let qwen_3_4b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-4B-4bit"
    )

    public static let qwen_3_8b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-8B-4bit"
    )

//    public static let granite_4_0_micro_8bit = ModelConfiguration(
//        id: "mlx-community/granite-4.0-micro-8bit"
//    )

    public static let jan_v1_edge_bf16 = ModelConfiguration(
        id: "mlx-community/Jan-v1-edge-bf16"
    )

    public static let qwen_3_4b_instruct_8bit = ModelConfiguration(
        id: "mlx-community/Qwen3-4B-Instruct-2507-8bit"
    )

    public static let Qwen3_8B_4bit_DWQ_053125 = ModelConfiguration(
        id: "mlx-community/Qwen3-8B-4bit-DWQ-053125"
    )

    public static let Qwen3_1_7B_bf16 = ModelConfiguration(
        id: "mlx-community/Qwen3-1.7B-bf16"
    )

    public static let Jan_v1_4B_8bit = ModelConfiguration(
        id: "mlx-community/Jan-v1-4B-8bit"
    )

    public static let qwen_2_5_vl_3b_instruct_4bit = VLMRegistry.qwen2_5VL3BInstruct4Bit

    public static let qwen_2_vl_2b_instruct_4bit = VLMRegistry.qwen2VL2BInstruct4Bit

    public static let smol_vlm_instruct_4bit = VLMRegistry.smolvlminstruct4bit

    public static let gemma3_4B_qat_4bit = VLMRegistry.gemma3_4B_qat_4bit

    public static var availableModels: [ModelConfiguration] = [
        llama_3_2_1b_4bit,
        llama_3_2_3b_4bit,
        deepseek_r1_distill_qwen_1_5b_4bit,
        deepseek_r1_distill_qwen_1_5b_8bit,
        qwen_3_4b_4bit,
        qwen_3_8b_4bit,
        qwen_2_5_vl_3b_instruct_4bit,
        qwen_2_vl_2b_instruct_4bit,
        smol_vlm_instruct_4bit,
        gemma3_4B_qat_4bit,
//        granite_4_0_micro_8bit,
        jan_v1_edge_bf16,
        qwen_3_4b_instruct_8bit,
        Qwen3_8B_4bit_DWQ_053125,
        Qwen3_1_7B_bf16,
        Jan_v1_4B_8bit,
    ]

    public static var defaultModel: ModelConfiguration {
        llama_3_2_1b_4bit
    }

    public static func getModelByName(_ name: String) -> ModelConfiguration? {
        if let model = availableModels.first(where: { $0.name == name }) {
            return model
        } else {
            return nil
        }
    }

    func formatForTokenizer(_ message: String) -> String {
        if modelType == .reasoning {
            let pattern = "<think>.*?(</think>|$)"
            do {
                let regex = try NSRegularExpression(
                    pattern: pattern, options: [.dotMatchesLineSeparators])
                let range = NSRange(location: 0, length: message.utf16.count)
                let formattedMessage = regex.stringByReplacingMatches(
                    in: message, options: [], range: range, withTemplate: "")
                return " " + formattedMessage
            } catch {
                return " " + message
            }
        }
        return message
    }

    /// Returns the model's approximate size, in GB.
    public var modelSize: Decimal? {
        switch self {
        case .llama_3_2_1b_4bit: return 0.7
        case .llama_3_2_3b_4bit: return 1.8
        // case .deepseek_r1_distill_qwen_1_5b_4bit: return 1.0
        // case .deepseek_r1_distill_qwen_1_5b_8bit: return 1.9
        case .qwen_3_4b_4bit: return 2.3
        // case .qwen_3_8b_4bit: return 4.7
        case .qwen_2_5_vl_3b_instruct_4bit: return 3.09
        // case .qwen_2_vl_2b_instruct_4bit: return 1.26
        case .smol_vlm_instruct_4bit: return 1.46
        case .gemma3_4B_qat_4bit: return 3.03
//        case .granite_4_0_micro_8bit: return 3.63
        case .jan_v1_edge_bf16: return 3.46
        case .qwen_3_4b_instruct_8bit: return 4.29
        case .Qwen3_8B_4bit_DWQ_053125: return 4.7
        case .Qwen3_1_7B_bf16: return 3.46
        case .Jan_v1_4B_8bit: return 4.29
        default: return nil
        }
    }
}
