#!/bin/bash
set -e

# ================================
# Bare-metal Local Deployment Script
# For development/debugging only
# Production deployment should use Docker
# ================================

# Default port is 8888, can be overridden by first argument
PORT=${1:-8888}

echo "=== [1/5] Installing system dependencies ==="
sudo apt update
sudo apt install -y --no-install-recommends \
    ca-certificates tzdata git curl python3 python3-venv python3-pip

echo "=== [2/5] Cloning repository ==="
if [ -d "$HOME/opusmt-docker-init" ]; then
    echo "Directory ~/opusmt-docker-init already exists. Pulling latest changes..."
    cd ~/opusmt-docker-init
    git pull
else
    git clone https://github.com/gzdanny/opusmt-docker-init.git ~/opusmt-docker-init
    cd ~/opusmt-docker-init
fi

echo "=== [3/5] Creating Python virtual environment ==="
if [ -d "venv" ]; then
    echo "Existing virtual environment detected. Removing..."
    rm -rf venv
fi
python3 -m venv venv
source venv/bin/activate

echo "=== [4/5] Installing Python dependencies ==="
pip install --upgrade pip
pip install fastapi "uvicorn[standard]" \
    transformers==4.42.0 sentencepiece sacremoses \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch

echo "=== [5/5] Starting service on port $PORT ==="
echo "You can stop it with Ctrl+C."
echo "Access API docs at: http://<server-ip>:$PORT/docs"
uvicorn app:app --host 0.0.0.0 --port "$PORT" --workers 1 --reload
