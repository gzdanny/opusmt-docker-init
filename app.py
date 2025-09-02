# © 2025 Danny. Licensed under Apache License 2.0.

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
import torch
import re

app = FastAPI(title="OPUS-MT Translation Server", version="1.0.0")

# 支持的模型映射
MODELS = {
    ("el", "en"): "Helsinki-NLP/opus-mt-el-en",
    ("en", "el"): "Helsinki-NLP/opus-mt-en-el",
    ("zh", "en"): "Helsinki-NLP/opus-mt-zh-en",
    ("en", "zh"): "Helsinki-NLP/opus-mt-en-zh",
}

# 模型缓存
loaded = {}
def load(model_name):
    if model_name not in loaded:
        tok = AutoTokenizer.from_pretrained(model_name)
        mdl = AutoModelForSeq2SeqLM.from_pretrained(model_name)
        loaded[model_name] = (tok, mdl)
    return loaded[model_name]

# 单次翻译
def translate_once(text: str, src: str, tgt: str, max_new_tokens=256) -> str:
    key = (src, tgt)
    if key not in MODELS:
        raise ValueError(f"Unsupported direction: {src}->{tgt}")
    model_name = MODELS[key]
    tok, mdl = load(model_name)
    inputs = tok(text, return_tensors="pt")
    with torch.no_grad():
        out = mdl.generate(**inputs, max_new_tokens=max_new_tokens, do_sample=False)
    return tok.decode(out[0], skip_special_tokens=True)

# 简单语言检测
def guess_lang(text: str) -> str:
    if re.search(r"[\u0370-\u03FF\u1F00-\u1FFF]", text):  # 希腊字母
        return "el"
    if re.search(r"[\u4e00-\u9fff]", text):  # 中文
        return "zh"
    return "en"

# 请求与响应模型
class TranslateReq(BaseModel):
    q: str
    source: Optional[str] = "auto"   # "auto" | "el" | "en" | "zh"
    target: str                      # "el" | "en" | "zh"
    max_new_tokens: Optional[int] = 256

class TranslateResp(BaseModel):
    translatedText: str
    route: List[str]
    detectedSource: str

@app.post("/translate", response_model=TranslateResp)
def translate(req: TranslateReq):
    src = req.source.lower() if req.source else "auto"
    tgt = req.target.lower()
    if tgt not in ("el", "en", "zh"):
        raise HTTPException(400, "target must be one of: el,en,zh")

    detected = guess_lang(req.q) if src == "auto" else src
    if detected == tgt:
        return TranslateResp(translatedText=req.q, route=["noop"], detectedSource=detected)

    route = []
    try:
        # 直接支持的方向
        if (detected, tgt) in MODELS:
            out = translate_once(req.q, detected, tgt, req.max_new_tokens)
            route.append(f"{detected}->{tgt}")
            return TranslateResp(translatedText=out, route=route, detectedSource=detected)

        # 不直接支持的方向，用英语中转
        if (detected, "en") in MODELS and ("en", tgt) in MODELS:
            mid = translate_once(req.q, detected, "en", req.max_new_tokens)
            route.append(f"{detected}->en")
            out = translate_once(mid, "en", tgt, req.max_new_tokens)
            route.append(f"en->{tgt}")
            return TranslateResp(translatedText=out, route=route, detectedSource=detected)

        raise HTTPException(400, f"Unsupported translation route: {detected}->{tgt}")
    except ValueError as e:
        raise HTTPException(400, str(e))
