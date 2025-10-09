# portal iOS
![portal iOS](https://portal.app/images/app.png)

[portal](https://portal.app) is an iOS app to chat with local large language models that’s optimized for Apple silicon and works on iPhone, iPad, and Mac. your chat history is saved locally, you can customize the appearance of the app, and vision-capable models accept image inputs alongside text.

## supported models

## text

- [x] [Llama 3.2 1B (4-bit)](https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit)
- [x] [Llama 3.2 3B (4-bit)](https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit)
- [x] [DeepSeek R1 Distill Qwen 1.5B (4-bit)](https://huggingface.co/mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit)
- [x] [DeepSeek R1 Distill Qwen 1.5B (8-bit)](https://huggingface.co/mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit)

### text + reasoning
- [x] [Qwen 3 4B (4-bit)](https://huggingface.co/mlx-community/Qwen3-4B-4bit)
- [x] [Qwen 3 8B (4-bit)](https://huggingface.co/mlx-community/Qwen3-8B-4bit)
- [x] [Qwen 3 4B Instruct (8-bit)](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-8bit)
- [x] [Qwen 3 8B DWQ (4-bit)](https://huggingface.co/mlx-community/Qwen3-8B-4bit-DWQ-053125)
- [x] [Qwen 3 1.7B (bf16)](https://huggingface.co/mlx-community/Qwen3-1.7B-bf16)
- [x] [Jan v1 edge (bf16)](https://huggingface.co/mlx-community/Jan-v1-edge-bf16)
- [x] [Jan v1 4B (8-bit)](https://huggingface.co/mlx-community/Jan-v1-4B-8bit)

### vision (text + images)
- [x] [Qwen 2.5 VL 3B Instruct (4-bit)](https://huggingface.co/mlx-community/Qwen2.5-VL-3B-Instruct-4bit)
- [x] [Qwen 2 VL 2B Instruct (4-bit)](https://huggingface.co/mlx-community/Qwen2-VL-2B-Instruct-4bit)
- [x] [smolVLM Instruct (4-bit)](https://huggingface.co/mlx-community/SmolVLM-Instruct-4bit)
- [x] Gemma 3 4B QAT (4-bit)

## credits

portal is made possible by [MLX Swift](https://github.com/ml-explore/mlx-swift) from Apple. [MLX](https://github.com/ml-explore/mlx) is an array framework for machine learning research on Apple silicon.
