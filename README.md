# tarifin - AI-Powered Voice-Based Recipe Assistant

**tarifin** is a full-stack LLM-powered recipe assistant that enables users to request recipes via voice and receive personalized, culturally diverse, and health-conscious suggestions in real time — both as text and speech.

The system includes a fine-tuned Nous Hermes 2 - Mistral 7B, a Flask streaming API backend, and a Flutter mobile client supporting voice input/output (STT/TTS).

---

## 💻 Development Environment

| Component        | Specification                       |
|------------------|--------------------------------------|
| OS               | Windows 11 Pro                       |
| Linux Subsystem  | WSL2 (Ubuntu 22.04 LTS)              |
| Python Env       | `venv`-based isolated environment    |
| CUDA Version     | 11.8                                 |
| PyTorch          | 2.2+ with CUDA support               |
| Transformers     | HuggingFace Transformers             |
| TRL              | `trl` (for SFTTrainer)               |

### 🔧 Hardware

| Component | Detail                            |
|-----------|------------------------------------|
| GPU       | NVIDIA RTX 4060 (Laptop) – 8 GB VRAM |
| CPU       | Intel Core i5-12500H (12-Core Hybrid) |
| RAM       | 16 GB DDR4 RAM                      |

---

## 📁 Dataset Overview

- **Path:** `/model_files/data/all_data.jsonl`
- **Size:** 4,800 Alpaca-style training samples
- **Each Sample Contains:**
  - `instruction`: The user’s natural language request
  - `input`: Optional context
  - `output`: A detailed, minimum 1000-word recipe
  - `metadata`: Nutritional info, allergens, cuisine type, etc.

### 📌 Sample Format
```json
{
  "instruction": "Suggest a low-calorie Turkish dinner for a diabetic patient",
  "input": "",
  "output": "To prepare a balanced Turkish meal for someone managing diabetes...",
  "metadata": {
    "calories": "430 kcal",
    "diet": "diabetic-friendly",
    "cuisine": "Turkish",
    "allergens": "nut-free"
  }
}
```

---

## 🧪 Fine-Tuning Process

### ✅ Model Details

- **Base Model:** Nous Hermes 2 - Mistral 7B
- **Quantization:** 4-bit NF4 (via `bitsandbytes`)
- **Fine-tuning:** LoRA (via `peft`) + `SFTTrainer`

### 🛠️ Training Pipeline (see `/model_files/train.py`)

1. Load and quantize model using NF4
2. Apply LoRA (PEFT) for efficient training
3. Filter and format dataset (`prompt + metadata + output`)
4. Tokenize with `max_length = 1024`
5. Fine-tune using `SFTTrainer` for 2 epochs

---

## 🧩 3-Stage Curriculum Fine-Tuning Strategy

To enhance learning dynamics, training was split into 3 progressive phases based on output length:

### 🥇 Phase 1: Short Outputs (< 2000 words)
- **Goal:** Teach the model task format and cultural variability
- **Result:** Learned the question-answer pattern effectively

### 🥈 Phase 2: Medium Outputs (2000–3000 words)
- **Goal:** Improve fluency and semantic consistency
- **Result:** Better contextual flow and structural awareness

### 🥇 Phase 3: Long Outputs (≥ 3000 words)
- **Goal:** Handle complex, multi-step recipe generation
- **Filter Applied:** `len(output) >= 3000`
- **Result:** Stable performance across lengthy, dense outputs

---

## ⚙️ Training Configuration

```python
TrainingArguments(
    output_dir="./output_longest",
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,
    num_train_epochs=2,
    learning_rate=2e-4,
    fp16=True,
    save_strategy="steps",
    save_steps=100,
    save_total_limit=2,
    logging_steps=10
)
```

- **Effective batch size:** 4
- **Checkpointing:** every 100 steps, only 2 retained
- **Precision:** Mixed (fp16) for optimized memory usage

---

## Training Flow Summary

```
AutoTokenizer + AutoModel (Nous Hermes 2 - Mistral 7B)
↓
4-bit quantization (NF4) + LoRA (PEFT)
↓
Dataset loaded → long outputs filtered (≥ 3000 words)
↓
Prompt + Metadata → `text` field merged
↓
Tokenizer applied (max length 1024)
↓
Trained with SFTTrainer (2 epochs)
↓
Saved to ./output_longest
```

---

## 🔁 Checkpoint-Based Continual Training

- Training resumed over 3 stages using progressive dataset splits.
- Each phase loaded the previous checkpoint via `output_dir`.
- Model was re-saved after each phase using `.save_model()`.

---

## 🧪 Post-Training Evaluation & Deployment

### 1️⃣ Gradio-Based UI Testing

> File: `/model_files/gradio_exe.py`

```bash
python model_files/gradio_exe.py
```

- Token-wise streaming via `TextIteratorStreamer`
- Threaded generation with dynamic Markdown preview
- Real-time evaluation for developer convenience

---

### 2️⃣ Flask Streaming API Integration

> File: `/model_files/app.py`

```bash
cd model_files
python app.py
```

#### 🔗 Endpoint: `POST /generate`

**Request:**
```json
{ "text": "Suggest a quick and healthy gluten-free Turkish lunch option" }
```

**Response:**
- Content-Type: `text/plain`
- Token-wise streamed output using `yield`

#### ⏳ Inference Flow:
1. Receive JSON request
2. Use tokenizer + streamer in a separate thread
3. `generate()` streams output line-by-line via Flask

> ✅ The API runs at `http://localhost:5000/generate`

---

## 📱 Flutter Mobile App: Voice Recipe Assistant

After Flask API deployment, a lightweight Android app was developed using Flutter to provide seamless voice-based interaction.

### 🎯 Workflow Summary

1. User **speaks** a recipe request
2. Speech is converted to text via `speech_to_text`
3. Text is **POSTed** to the Flask API
4. Response is **streamed back**
5. It is both **rendered** on screen and **spoken aloud** via `flutter_tts`

---

### 📦 Flutter Dependencies

| Package            | Functionality                            |
|--------------------|-------------------------------------------|
| `speech_to_text`   | Converts voice to text                    |
| `http`             | Sends requests to backend API             |
| `flutter_tts`      | Text-to-speech playback of results        |
| `flutter_markdown` | Rich text rendering for model output      |
| `uuid`             | Unique message/session identification     |

---

### 🔁 App Flow

```text
User speaks into mic → STT (speech_to_text)
↓
Text sent to Flask API → HTTP POST
↓
Streaming response shown in Markdown
↓
Result spoken aloud via TTS (flutter_tts)
```

---

### 📂 Flutter Code Structure

- `main.dart`: Entry point, handles STT/TTS logic
- `chat_home.dart`: UI + HTTP streaming integration
- `ChatMessage` `ChatSession`: message model structure

---

## 📄 License

MIT License © 2025 — Eren Yurtcu
