#!/bin/bash
set -e

# ================================
# Bare-metal Local Deployment Script
# - Python 3.10 via pyenv
# - Model pre-download
# - Multi-direction warmup with debug output
# For development/debugging only
# Production deployment should use Docker
# ================================

# 默认服务端口（可通过第一个参数覆盖）
PORT=${1:-8888}
# 固定 Python 版本，确保与 Docker 环境一致
PYTHON_VERSION=3.10.14

# ANSI 颜色定义
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RESET="\033[0m"

echo -e "${YELLOW}=== [1/10] Installing base system dependencies ===${RESET}"
sudo apt update
sudo apt install -y --no-install-recommends \
    ca-certificates tzdata git curl build-essential pkg-config \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    wget llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev python3-pip

echo -e "${YELLOW}=== [2/10] Ensuring Python 3.10 via pyenv ===${RESET}"
if ! command -v python3.10 >/dev/null 2>&1; then
    echo "Python 3.10 not found. Installing via pyenv..."
    if [ ! -d "$HOME/.pyenv" ]; then
        curl https://pyenv.run | bash
    fi
    # 将 pyenv 初始化命令写入 ~/.bashrc，确保下次登录可用
    if ! grep -q 'pyenv init' ~/.bashrc 2>/dev/null; then
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc
        echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    fi
    # 当前 shell 立即加载 pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - bash)"
    eval "$(pyenv virtualenv-init -)"
    pyenv install -s $PYTHON_VERSION
    pyenv global $PYTHON_VERSION
else
    echo "Python 3.10 is already available."
fi

echo -e "${YELLOW}=== [3/10] Cloning repository ===${RESET}"
if [ -d "$HOME/opusmt-docker-init" ]; then
    echo "Directory ~/opusmt-docker-init already exists. Pulling latest changes..."
    cd ~/opusmt-docker-init
    git pull
else
    git clone https://github.com/gzdanny/opusmt-docker-init.git ~/opusmt-docker-init
    cd ~/opusmt-docker-init
fi

echo -e "${YELLOW}=== [4/10] Removing old virtual environment if exists ===${RESET}"
if [ -d "venv" ]; then
    echo "Existing virtual environment detected. Removing..."
    rm -rf venv
fi

echo -e "${YELLOW}=== [5/10] Creating Python 3.10 virtual environment ===${RESET}"
python3.10 -m venv venv
source venv/bin/activate

echo -e "${YELLOW}=== [6/10] Upgrading pip ===${RESET}"
pip install --upgrade pip

echo -e "${YELLOW}=== [7/10] Installing Python dependencies (matching Dockerfile) ===${RESET}"
pip install fastapi "uvicorn[standard]" \
    transformers==4.42.0 sentencepiece sacremoses \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch huggingface_hub

echo -e "${YELLOW}=== [8/10] Pre-downloading translation models to avoid startup delays ===${RESET}"
python3 - <<'PY'
from huggingface_hub import snapshot_download
models = [
    "Helsinki-NLP/opus-mt-tc-big-el-en",
    "Helsinki-NLP/opus-mt-tc-big-en-el",
    "Helsinki-NLP/opus-mt-zh-en",
    "Helsinki-NLP/opus-mt-en-zh"
]
for m in models:
    print(f"📥 Downloading {m} ...")
    snapshot_download(m)
PY

echo -e "${YELLOW}=== [9/10] Starting service on port $PORT (background) ===${RESET}"
uvicorn app:app --host 0.0.0.0 --port "$PORT" --workers 1 --reload &
SERVER_PID=$!

# 等待服务启动（最多 30 秒）
for i in $(seq 1 30); do
  if curl -s "http://127.0.0.1:$PORT/docs" >/dev/null; then
    break
  fi
  sleep 1
done

echo -e "${YELLOW}=== [10/10] Warming up models with long, meaningful sentences (en/zh/el) ===${RESET}"
function warmup_case() {
    local text="$1"
    local src="$2"
    local tgt="$3"
    local payload="{\"q\":\"$text\",\"source\":\"$src\",\"target\":\"$tgt\"}"

    echo -e "${BLUE}--- Warmup: $src → $tgt ---${RESET}"
    echo "📤 Warmup POST payload: $payload"
    result=$(curl -s -X POST http://127.0.0.1:$PORT/translate \
      -H "Content-Type: application/json" \
      -d "$payload")
    echo "📥 Warmup Response: $result"
}

# 六个方向的长句测试
warmup_case "On a quiet evening by the harbor, conversations linger over warm bread and olives, reminding us that progress matters most when it stays close to people and solves real problems with clarity and care." "en" "zh"
warmup_case "在一个宁静而明朗的傍晚，海港边的人们一边分享新鲜的面包与橄榄，一边讨论那些真正能解决问题、并且贴近人的进步。" "zh" "en"
warmup_case "When teams trust each other and explain complex ideas with simple language, collaboration becomes lighter, decisions get better, and ambitions turn into results that truly help people." "en" "el"
warmup_case "Τις πρώτες ώρες του πρωινού, όταν η πόλη ξυπνά αργά, ένας απαλός άνεμος μεταφέρει μυρωδιές από φρέσκο ψωμί και καφέ, θυμίζοντας πως οι μικρές συνήθειες κρατούν τη ζωή ισορροπημένη." "el" "en"
warmup_case "当我们把复杂的想法讲清楚、把困难的事情做简单，人们就更容易彼此理解，也更愿意一起把事情向前推进。" "zh" "el"
warmup_case "Η τεχνολογία έχει αξία μόνο όταν κάνει τη ζωή μας πιο ανθρώπινη και προσβάσιμη, δημιουργώντας ευκαιρίες για όλους χωρίς να χάνεται η ουσία της επικοινωνίας." "el" "zh"

echo -e "${GREEN}✅ System is ready. Access API docs at: http://<server-ip>:$PORT/docs${RESET}"

# 保持前台阻塞，方便调试时查看日志
wait $SERVER_PID
