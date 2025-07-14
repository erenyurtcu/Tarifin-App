from flask import Flask, request, Response
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, TextIteratorStreamer
import torch
import threading

app = Flask(__name__)

# BitsAndBytes config
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16
)

# Model ve tokenizer yükle
model_path = "./output_longest"
tokenizer = AutoTokenizer.from_pretrained(model_path, use_fast=True)
model = AutoModelForCausalLM.from_pretrained(
    model_path,
    device_map="auto",
    quantization_config=bnb_config,
    trust_remote_code=True
)

@app.route("/generate", methods=["POST"])
def generate():
    data = request.get_json()
    input_text = data.get("text", "")

    if not input_text.strip():
        return Response("No input text provided.", status=400)

    # Tokenize input
    inputs = tokenizer(input_text, return_tensors="pt").to(model.device)

    # Streamer
    streamer = TextIteratorStreamer(tokenizer, skip_special_tokens=True, skip_prompt=True)

    # Generate thread
    generation_kwargs = {
        "input_ids": inputs["input_ids"],
        "max_new_tokens": 800,
        "streamer": streamer,
        "eos_token_id": tokenizer.eos_token_id,
        "pad_token_id": tokenizer.pad_token_id
    }
    thread = threading.Thread(target=model.generate, kwargs=generation_kwargs)
    thread.start()

    def stream_output():
        for new_text in streamer:
            yield new_text

    return Response(stream_output(), mimetype="text/plain")

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
