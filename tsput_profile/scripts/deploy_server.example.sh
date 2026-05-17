#!/usr/bin/env bash
# Залить код на сервер и пересобрать Docker. Подставь: ./deploy_server.example.sh user@host [~/tsput_profile]
set -euo pipefail
USER_HOST="${1:?usage: $0 user@host [remote_dir]}"
REMOTE_DIR="${2:-~/tsput_profile}"

rsync -avz --delete \
  --exclude '.git' \
  --exclude 'build' \
  --exclude '.env' \
  --exclude 'backend/.venv' \
  --exclude '**/__pycache__' \
  --exclude '.dart_tool' \
  --exclude 'android/.gradle' \
  ./ "$USER_HOST:$REMOTE_DIR/"

ssh "$USER_HOST" "cd $REMOTE_DIR && docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build"

echo "Готово. Проверь: curl -sS http://SERVER:8080/health"
