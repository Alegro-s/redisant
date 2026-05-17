#!/usr/bin/env bash
# Только очистка legacy на VPS (без деплоя). Запуск: bash server-wipe-legacy.sh
set -euo pipefail

echo "Останавливаем Docker..."
docker ps -q | xargs -r docker stop 2>/dev/null || true

echo "Удаляем legacy каталоги в HOME..."
rm -rf "$HOME/nexus" "$HOME/tsput_profile" "$HOME/lynx_check.sh" "$HOME/lynx_check_output.txt"

echo "Опционально: удалить все образы/volumes (раскомментируйте при необходимости)"
# docker system prune -af --volumes

echo "Готово. Можно запускать server-reset-and-deploy.sh"
