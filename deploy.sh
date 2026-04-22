#!/bin/bash
# 部署脚本：将 Godot 项目同步到服务器
# 用法: ./deploy.sh

SERVER="root@8.161.225.239"
SSH_KEY="$HOME/.ssh/id_ed25519"
REMOTE_PATH="/server/godot_server"
LOCAL_PATH="$(dirname "$0")"

echo "=== 星河放置 部署脚本 ==="
echo "目标服务器: $SERVER"
echo "远程路径: $REMOTE_PATH"

# 同步项目文件（排除本地开发文件）
rsync -avz --delete \
  -e "ssh -i $SSH_KEY" \
  --exclude=".godot/" \
  --exclude="*.import" \
  --exclude="export_presets.cfg" \
  --exclude="deploy.sh" \
  --exclude=".git/" \
  --exclude="md/" \
  --exclude="csv/" \
  "$LOCAL_PATH/" \
  "$SERVER:$REMOTE_PATH/"

echo ""
echo "=== 同步完成 ==="
echo "重启服务端: ssh -i $SSH_KEY $SERVER 'systemctl restart godot-server'"
