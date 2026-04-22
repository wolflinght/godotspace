#!/bin/bash
# 部署脚本：push 后在服务器执行 git pull 并重启
# 用法: ./deploy.sh

SERVER="root@8.161.225.239"
SSH_KEY="$HOME/.ssh/id_ed25519"

echo "=== 星河放置 部署 ==="

# 1. push 到 GitHub
git push origin main
if [ $? -ne 0 ]; then
  echo "Push 失败，中止部署"
  exit 1
fi

# 2. 服务器 pull 最新代码并重启
ssh -i "$SSH_KEY" "$SERVER" "
  cd /server/godot_server &&
  git pull origin main &&
  systemctl restart godot-server &&
  echo '服务端已重启'
"

echo "=== 部署完成 ==="
