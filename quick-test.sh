#!/bin/bash
# quick-test.sh
# 快速测试 OPUS-MT Docker 服务的翻译效果
# © 2025 Danny

# 默认访问地址和端口
# 注意：这里的默认端口应与 docker-compose.yml 中宿主机暴露的端口（冒号左边）一致
SERVER_IP=${1:-localhost}
PORT=${2:-8888}

echo "🔍 Testing OPUS-MT translation server at http://$SERVER_IP:$PORT"
echo "------------------------------------------------------------"

function test_case() {
    local text="$1"
    local src="$2"
    local tgt="$3"
    echo -e "\n📤 Source ($src): $text"
    result=$(curl -s -X POST http://$SERVER_IP:$PORT/translate \
      -H "Content-Type: application/json" \
      -d "{\"q\":\"$text\",\"source\":\"$src\",\"target\":\"$tgt\"}")
    echo "📥 Response: $result"
}

# 希腊语 -> 英语
test_case "Καλημέρα σας, καλώς ήρθατε." "el" "en"

# 英语 -> 希腊语
test_case "Please review the attached document." "en" "el"

# 中文 -> 英语
test_case "请查看我附带的文件。" "zh" "en"

# 英语 -> 中文
test_case "The meeting will be held tomorrow morning." "en" "zh"

# 中文 -> 希腊语（中转）
test_case "我喜欢学习语言。" "zh" "el"

# 希腊语 -> 中文（中转）
test_case "Η τεχνητή νοημοσύνη αλλάζει τον κόσμο." "el" "zh"

echo -e "\n✅ Test completed."
