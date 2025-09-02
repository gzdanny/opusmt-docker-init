FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HUB_DISABLE_TELEMETRY=1

# 安装基础依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata git curl \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖（CPU 版 PyTorch）
RUN pip install --no-cache-dir \
    fastapi uvicorn[standard] \
    transformers==4.42.0 sentencepiece sacremoses \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch==2.3.1+cpu

# 预下载 OPUS-MT 模型
RUN python - <<'PY'
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
models = [
    "Helsinki-NLP/opus-mt-el-en",
    "Helsinki-NLP/opus-mt-en-el",
    "Helsinki-NLP/opus-mt-zh-en",
    "Helsinki-NLP/opus-mt-en-zh",
]
for m in models:
    AutoTokenizer.from_pretrained(m)
    AutoModelForSeq2SeqLM.from_pretrained(m)
print("All models cached.")
PY

WORKDIR /app
COPY app.py /app/app.py

EXPOSE 8000
CMD [ "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1" ]
