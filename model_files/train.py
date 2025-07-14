from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from trl import SFTTrainer
from datasets import load_dataset
import torch

# Önceki model checkpoint'i
model_id = "./output_long"  # En son eğitim burada tamamlandı

# Tokenizer
tokenizer = AutoTokenizer.from_pretrained(model_id, use_fast=False)
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = "right"

# Quantization ayarları
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
)

# Modeli yükle (devam edilecek checkpoint)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True,
)
model = prepare_model_for_kbit_training(model)

# LoRA ayarları
lora_config = LoraConfig(
    r=64,
    lora_alpha=16,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)
model = get_peft_model(model, lora_config)

# Dataset: sadece 3000+ karakterli output'lar
dataset = load_dataset("json", data_files="data/all_data.jsonl")["train"]
dataset = dataset.filter(lambda x: len(x.get("output", "")) >= 3000)

# Formatlama
def merge_fields(example):
    instruction = example.get("instruction", "").strip()
    input_text = example.get("input", "").strip()
    output_text = example.get("output", "").strip()
    metadata = example.get("metadata", {})

    if input_text:
        prompt = f"### Soru:\n{instruction}\n\n### Girdi:\n{input_text}\n"
    else:
        prompt = f"### Soru:\n{instruction}\n"

    metadata_str = ""
    if metadata and isinstance(metadata, dict):
        meta_lines = "\n".join([f"- {k}: {v}" for k, v in metadata.items()])
        metadata_str = f"\n### Bilgiler:\n{meta_lines}\n"

    example["text"] = prompt + metadata_str + "\n### Yanıt:\n" + output_text.strip()
    return example

dataset = dataset.map(merge_fields)

# Tokenize
dataset = dataset.map(
    lambda e: tokenizer(e["text"], truncation=True, padding="max_length", max_length=1024),
    batched=True
)
dataset.set_format(type="torch")

# Eğitim ayarları
training_args = TrainingArguments(
    output_dir="./output_longest",
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,
    num_train_epochs=2,
    logging_dir="./logs_longest",
    logging_steps=10,
    save_strategy="steps",
    save_steps=100,
    learning_rate=2e-4,
    fp16=True,
    bf16=False,
    save_total_limit=2,
    report_to="none",
    dataloader_num_workers=2,
)

# Trainer
trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    tokenizer=tokenizer,
    dataset_text_field="text",
    max_seq_length=1024,
    args=training_args
)

# Eğitimi başlat
trainer.train()

# Kaydet
trainer.save_model("./output_longest")
tokenizer.save_pretrained("./output_longest")
