#!/usr/bin/env bash
# Скачать модель в контейнер Ollama (один раз после первого deploy).
set -euo pipefail
MODEL="${ROZA_MODEL:-qwen2.5:3b}"
echo "==> ollama pull $MODEL"
docker exec roza-ollama ollama pull "$MODEL"
echo "OK"
