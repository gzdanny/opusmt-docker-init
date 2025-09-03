from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
import torch

app = FastAPI()

# ✅ 使用最新可用的模型 ID
MODELS = {
    "el-en": "Helsinki-NLP/opus-mt-tc-big-el-en",
    "en-el": "Helsinki-NLP/opus-mt-tc-big-en-el",
    "zh-en": "Helsinki-NLP/opus-mt-zh-en",
    "en-zh": "Helsinki-NLP/opus-mt-en-zh"
}

# 缓存已加载的模型
loaded_models = {}

class TranslationRequest(BaseModel):
    q: str
    source: str
    target: str
    max_new_tokens: int = 256

def load_model(model_id):
    """加载模型并带错误捕获"""
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_id)
        model = AutoModelForSeq2SeqLM.from_pretrained(model_id)
        return tokenizer, model
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load model '{model_id}': {str(e)}"
        )

@app.on_event("startup")
def preload_models():
    """启动时预加载所有模型（可选）"""
    for key, model_id in MODELS.items():
        print(f"Loading model: {model_id}")
        loaded_models[key] = load_model(model_id)
    print("✅ All models loaded.")

@app.post("/translate")
def translate(req: TranslationRequest):
    route = f"{req.source}-{req.target}"
    if route not in MODELS:
        raise HTTPException(status_code=400, detail=f"Unsupported translation route: {route}")

    tokenizer, model = loaded_models.get(route) or load_model(MODELS[route])
    inputs = tokenizer(req.q, return_tensors="pt")
    with torch.no_grad():
        outputs = model.generate(**inputs, max_new_tokens=req.max_new_tokens)
    translated = tokenizer.decode(outputs[0], skip_special_tokens=True)

    return {
        "translatedText": translated,
        "route": [route],
        "detectedSource": req.source
    }
