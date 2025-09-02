#!/bin/bash
# deploy-and-test.sh
# 一键部署 OPUS-MT Docker 服务并运行快速测试
# © 2025 Danny

set -e

REPO_URL="https://github.com/gzdanny/opusmt-docker-init.git"
REPO_DIR="opusmt-docker-init"
PORT=8888  # 必须与 docker-compose.yml 中宿主机端口一致

echo "🚀 Starting OPUS-MT deployment on Debian..."

# 1. 安装依赖
echo "📦 Installing dependencies..."
sudo apt update && sudo apt install -y docker.io docker-compose git

# 2. 克隆仓库（如果已存在则跳过）
if [ ! -d "$REPO_DIR" ]; then
    echo "📥 Cloning repository..."
    git clone "$REPO_URL"
else
    echo "🔄 Repository already exists, pulling latest changes..."
    cd "$REPO_DIR"
    git pull
    cd ..
fi

# 3. 构建镜像
echo "🔨 Building Docker image..."
cd "$REPO_DIR"
sudo docker-compose build --no-cache

# 4. 启动服务
echo "▶️ Starting service..."
sudo docker-compose up -d

# 5. 等待服务启动
echo "⏳ Waiting for service to start..."
sleep 5

# 6. 运行快速测试
if [ -f "quick-test.sh" ]; then
    echo "🧪 Running quick test..."
    chmod +x quick-test.sh
    ./quick-test.sh localhost $PORT
else
    echo "⚠️ quick-test.sh not found, skipping test."
fi

echo "✅ Deployment and test completed."
echo "🌐 API docs available at: http://localhost:$PORT/docs"
