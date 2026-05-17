
set -euo pipefail
URL="${1:?Укажите URL git: $0 <url>}"
DEST="${2:-nexus-deploy}"

git clone --filter=blob:none --sparse "$URL" "$DEST"
cd "$DEST"
git sparse-checkout init --cone
git sparse-checkout set server docker-compose.yml docker-compose.cloud-db.yml .env.example scripts

echo ""
echo "[NEXUS] Минимальный клон: $(pwd)"
echo "  Локальная БД:   cp .env.example .env && nano .env && docker compose up -d --build"
echo "  Облачная БД:    см. docker-compose.cloud-db.yml"
