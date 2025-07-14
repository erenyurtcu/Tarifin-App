from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, TextIteratorStreamer
import gradio as gr
import torch
import threading

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16
)

model = AutoModelForCausalLM.from_pretrained(
    "./output_longest",
    device_map="auto",
    quantization_config=bnb_config,
    trust_remote_code=True
)

tokenizer = AutoTokenizer.from_pretrained("./output_longest", use_fast=True)

def chat(input_text):
    # Tokenize input
    inputs = tokenizer(input_text, return_tensors="pt").to(model.device)
    
    # Streamer oluştur
    streamer = TextIteratorStreamer(tokenizer, skip_special_tokens=True, skip_prompt=True)
    
    # Generate kwargs ile streaming
    generation_kwargs = {
        "input_ids": inputs["input_ids"],
        "max_new_tokens": 800,
        "streamer": streamer,
        "eos_token_id": tokenizer.eos_token_id,  
        "pad_token_id": tokenizer.pad_token_id
    }
    
    # Modelin çıktıyı stream etmesi için ayrı bir thread başlat
    thread = threading.Thread(target=model.generate, kwargs=generation_kwargs)
    thread.start()
    
    # Stream edilen çıktıyı topla ve yield et
    generated_text = ""
    for new_text in streamer:
        generated_text += new_text
        yield generated_text

# Gradio arayüzü
gr.Interface(
    fn=chat,
    inputs="text",
    outputs=gr.Markdown(),
    title="Fine-Tuned Tarifin Modeli"
).launch()