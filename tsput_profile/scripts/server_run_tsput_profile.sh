#!/usr/bin/env bash
# Запускать НА СЕРВЕРЕ из каталога с репозиторием tsput_profile (по умолчанию ~/tsput_profile).
set -euo pipefail
ROOT="${TSPUT_PROFILE_DIR:-$HOME/tsput_profile}"
cd "$ROOT"
echo "Каталог: $(pwd)"
echo "Сборка и запуск Docker..."
docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build
echo ""
docker compose ps
echo ""
echo "Проверка API:"
curl -sS http://127.0.0.1:8080/health && echo ""
