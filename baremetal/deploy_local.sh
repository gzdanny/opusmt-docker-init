#!/bin/bash
set -e

# ================================
# Bare-metal Local Deployment Script (Python 3.10)
# For development/debugging only
# Production deployment should use Docker
# ================================

PORT=${1:-8888}

echo "=== [1/7] Installing system dependencies ==="
sudo apt update
sudo apt install -y --no-install-recommends \
    ca-certificates tzdata git curl \
    build-essential pkg-config \
    python3.10 python3.10-venv python3.10-dev python3-pip

echo "=== [2/7] Cloning repository ==="
if [ -d "$HOME/opusmt-docker-init" ]; then
    echo "Directory ~/opusmt-docker-init already exists. Pulling latest changes..."
    cd ~/opusmt-docker-init
    git pull
else
    git clone https://github.com/gzdanny/opusmt-docker-init.git ~/opusmt-docker-init
    cd ~/opusmt-docker-init
fi

echo "=== [3/7] Removing old virtual environment if exists ==="
if [ -d "venv" ]; then
    echo "Existing virtual environment detected. Removing..."
    rm -rf venv
fi

echo "=== [4/7] Creating Python 3.10 virtual environment ==="
python3.10 -m venv venv
source venv/bin/activate

echo "=== [5/7] Upgrading pip ==="
pip install --upgrade pip

echo "=== [6/7] Installing Python dependencies (matching Dockerfile) ==="
pip install fastapi "uvicorn[standard]" \
    transformers==4.42.0 sentencepiece sacremoses \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch

echo "=== [7/7] Starting service on port $PORT ==="
echo "You can stop it with Ctrl+C."
echo "Access API docs at: http://<server-ip>:$PORT/docs"
uvicorn app:app --host 0.0.0.0 --port "$PORT" --workers 1 --reload
