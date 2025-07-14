from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
import torch

model_id = "NousResearch/Nous-Hermes-2-Mistral-7B-DPO"

tokenizer = AutoTokenizer.from_pretrained(model_id, use_fast=False)

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    device_map="auto",
    torch_dtype=torch.float16,
    quantization_config=BitsAndBytesConfig(load_in_4bit=True)
)

prompt = "Tarifin: Bir tavuk yemeği öner, 30 dakikada hazır olsun."
inputs = tokenizer(prompt, return_tensors="pt").to("cuda")
outputs = model.generate(**inputs, max_new_tokens=100)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))