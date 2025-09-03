#!/bin/bash
set -e

# ================================
# Bare-metal Local Deployment Script (Python 3.10 via pyenv + Warmup)
# For development/debugging only
# Production deployment should use Docker
# ================================

PORT=${1:-8888}
PYTHON_VERSION=3.10.14

echo "=== [1/9] Installing base system dependencies ==="
sudo apt update
sudo apt install -y --no-install-recommends \
    ca-certificates tzdata git curl build-essential pkg-config \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    wget llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev python3-pip

echo "=== [2/9] Ensuring Python 3.10 via pyenv ==="
if ! command -v python3.10 >/dev/null 2>&1; then
    echo "Python 3.10 not found. Installing via pyenv..."
    if [ ! -d "$HOME/.pyenv" ]; then
        curl https://pyenv.run | bash
    fi
    # Persist pyenv init to future shells if missing
    if ! grep -q 'pyenv init' ~/.bashrc 2>/dev/null; then
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc
        echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    fi
    # Load pyenv for current shell
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - bash)"
    eval "$(pyenv virtualenv-init -)"
    pyenv install -s $PYTHON_VERSION
    pyenv global $PYTHON_VERSION
else
    echo "Python 3.10 is already available."
fi

echo "=== [3/9] Cloning repository ==="
if [ -d "$HOME/opusmt-docker-init" ]; then
    echo "Directory ~/opusmt-docker-init already exists. Pulling latest changes..."
    cd ~/opusmt-docker-init
    git pull
else
    git clone https://github.com/gzdanny/opusmt-docker-init.git ~/opusmt-docker-init
    cd ~/opusmt-docker-init
fi

echo "=== [4/9] Removing old virtual environment if exists ==="
if [ -d "venv" ]; then
    echo "Existing virtual environment detected. Removing..."
    rm -rf venv
fi

echo "=== [5/9] Creating Python 3.10 virtual environment ==="
python3.10 -m venv venv
source venv/bin/activate

echo "=== [6/9] Upgrading pip ==="
pip install --upgrade pip

echo "=== [7/9] Installing Python dependencies (matching Dockerfile) ==="
pip install fastapi "uvicorn[standard]" \
    transformers==4.42.0 sentencepiece sacremoses \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch

echo "=== [8/9] Starting service on port $PORT (background) ==="
uvicorn app:app --host 0.0.0.0 --port "$PORT" --workers 1 --reload &
SERVER_PID=$!

# Wait until the service is ready (up to 30s)
for i in $(seq 1 30); do
  if curl -s "http://127.0.0.1:$PORT/docs" >/dev/null; then
    break
  fi
  sleep 1
done

echo "=== [9/9] Warming up models with long, meaningful sentences (en/zh/el) ==="
declare -A TESTS

# en -> zh
TESTS["en-zh"]="On a quiet evening by the harbor, conversations linger over warm bread and olives, reminding us that progress matters most when it stays close to people and solves real problems with clarity and care."

# zh -> en
TESTS["zh-en"]="在一个宁静而明朗的傍晚，海港边的人们一边分享新鲜的面包与橄榄，一边讨论那些真正能解决问题、并且贴近人的进步。"

# en -> el
TESTS["en-el"]="When teams trust each other and explain complex ideas with simple language, collaboration becomes lighter, decisions get better, and ambitions turn into results that truly help people."

# el -> en
TESTS["el-en"]="Τις πρώτες ώρες του πρωινού, όταν η πόλη ξυπνά αργά, ένας απαλός άνεμος μεταφέρει μυρωδιές από φρέσκο ψωμί και καφέ, θυμίζοντας πως οι μικρές συνήθειες κρατούν τη ζωή ισορροπημένη."

# zh -> el
TESTS["zh-el"]="当我们把复杂的想法讲清楚、把困难的事情做简单，人们就更容易彼此理解，也更愿意一起把事情向前推进。"

# el -> zh
TESTS["el-zh"]="Η τεχνολογία έχει αξία μόνο όταν κάνει τη ζωή μας πιο ανθρώπινη και προσβάσιμη, δημιουργώντας ευκαιρίες για όλους χωρίς να χάνεται η ουσία της επικοινωνίας."

for key in "${!TESTS[@]}"; do
  src="${key%-*}"
  tgt="${key#*-}"
  sentence="${TESTS[$key]}"
  echo "--- Warmup: $src → $tgt ---"
  # Use curl URL-encoding to safely send Unicode text
  curl -sG "http://127.0.0.1:$PORT/translate" \
    --data-urlencode "text=$sentence" \
    --data-urlencode "src=$src" \
    --data-urlencode "tgt=$tgt" \
    || true
  echo -e "\n"
done

echo "✅ System is ready. Access API docs at: http://<server-ip>:$PORT/docs"
wait $SERVER_PID
