#!/usr/bin/env bash
# Запускать НА СЕРВЕРЕ (Ubuntu), от того же пользователя, у которого лежит ~/tula-travel.
# Останавливает Docker-стек в каталоге (если есть) и удаляет папку целиком.
set -euo pipefail
TT="${TULA_TRAVEL_DIR:-$HOME/tula-travel}"
if [[ ! -d "$TT" ]]; then
  echo "Каталог не найден: $TT — ничего не делаю."
  exit 0
fi
echo "Останавливаю контейнеры в $TT (если compose есть)..."
if [[ -f "$TT/docker-compose.yml" ]] || [[ -f "$TT/docker-compose.yaml" ]]; then
  (cd "$TT" && docker compose down --remove-orphans 2>/dev/null) || true
fi
if command -v docker-compose >/dev/null 2>&1; then
  (cd "$TT" && docker-compose down --remove-orphans 2>/dev/null) || true
fi
echo "Удаляю $TT ..."
rm -rf "$TT"
echo "Готово: tula-travel удалён."
