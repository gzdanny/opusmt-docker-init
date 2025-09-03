#!/bin/bash
set -e

# ================================
# Bare-metal Local Deployment Script (Python 3.10 via pyenv)
# For development/debugging only
# Production deployment should use Docker
# ================================

PORT=${1:-8888}
PYTHON_VERSION=3.10.14

echo "=== [1/8] Installing base system dependencies ==="
sudo apt update
sudo apt install -y --no-install-recommends \
    ca-certificates tzdata git curl build-essential pkg-config \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    wget llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev python3-pip

echo "=== [2/8] Checking Python version ==="
if ! command -v python3.10 >/dev/null 2>&1; then
    echo "Python 3.10 not found. Installing via pyenv..."
    if [ ! -d "$HOME/.pyenv" ]; then
        curl https://pyenv.run | bash
    fi

    # 配置 pyenv 环境变量（永久生效）
    if ! grep -q 'pyenv init' ~/.bashrc; then
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc
        echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    fi

    # 立刻加载 pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - bash)"
    eval "$(pyenv virtualenv-init -)"

    pyenv install -s $PYTHON_VERSION
    pyenv global $PYTHON_VERSION
else
    echo "Python 3.10 is already available."
fi

echo "=== [3/8] Cloning repository ==="
if [ -d "$HOME/opusmt-docker-init" ]; then
    echo "Directory ~/opusmt-docker-init already exists. Pulling latest changes..."
    cd ~/opusmt-docker-init
    git pull
else
    git clone https://github.com/gzdanny/opusmt-docker-init.git ~/opusmt-docker-init
    cd ~/opusmt-docker-init
fi

echo "=== [4/8] Removing old virtual environment if exists ==="
if [ -d "venv" ]; then
    echo "Existing virtual environment detected. Removing..."
    rm -rf venv
fi

echo "=== [5/8] Creating Python 3.10 virtual environment ==="
python3.10 -m venv venv
source venv/bin/activate

echo "=== [6/8] Upgrading pip ==="
pip install --upgrade pip

echo "=== [7/8] Installing Python dependencies (matching Dockerfile) ==="
pip install fastapi "uvicorn[standard]" \
    transformers==4.42.0 sentencepiece sacremoses \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch

echo "=== [8/8] Starting service on port $PORT ==="
echo "You can stop it with Ctrl+C."
echo "Access API docs at: http://<server-ip>:$PORT/docs"
uvicorn app:app --host 0.0.0.0 --port "$PORT" --workers 1 --reload
