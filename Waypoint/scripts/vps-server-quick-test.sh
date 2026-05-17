set -euo pipefail

NEXUS_DIR="${NEXUS_DIR:-/root/NEXUS}"

[[ -d "$NEXUS_DIR" ]] || { echo "NEXUS_DIR not found: $NEXUS_DIR" >&2; exit 1; }
cd "$NEXUS_DIR"

if [[ ! -v USE_CLOUD_DB ]]; then
  if [[ -f docker-compose.cloud-db.yml ]] && docker compose -f docker-compose.cloud-db.yml ps --status running --services 2>/dev/null | grep -qx api; then
    USE_CLOUD_DB=1
  else
    USE_CLOUD_DB=0
  fi
fi

COMPOSE=(docker compose)
if [[ "$USE_CLOUD_DB" == "1" ]]; then
  COMPOSE=(docker compose -f docker-compose.cloud-db.yml)
fi

echo "=== [1/9] System snapshot ==="
echo "Uptime: $(uptime -p 2>/dev/null || true)"
echo "Disk:"
df -h | sed -n '1p;2p;3p;4p;5p' || true
echo "Docker:"
docker ps --format 'table {{.Names}}\t{{.Status}}' || true

echo
echo "=== [2/9] Compose status ==="
"${COMPOSE[@]}" ps || true

echo
echo "=== [3/9] API health endpoints ==="
for p in /health /ready /engine/manifest; do
  code="$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:8080${p}" || true)"
  echo "GET ${p} -> HTTP ${code}"
done

echo
echo "=== [4/9] Metrics endpoint (no JWT expected 401) ==="
code="$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:8080/me/system-metrics" || true)"
echo "GET /me/system-metrics (no auth) -> HTTP ${code} (expected 401)"

echo
echo "=== [5/9] Admin metrics endpoint (no JWT expected 401/403) ==="
code="$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:8080/admin/metrics" || true)"
echo "GET /admin/metrics (no auth) -> HTTP ${code} (expected 401/403)"

echo
echo "=== [6/9] Webhook service + auth check (NO email send) ==="
if systemctl list-unit-files 2>/dev/null | grep -q '^nexus-otp-webhook\.service'; then
  sudo systemctl is-active --quiet nexus-otp-webhook.service && echo "nexus-otp-webhook: active" || echo "nexus-otp-webhook: NOT active"
  echo "--- last webhook logs (tail 80) ---"
  journalctl -u nexus-otp-webhook.service --no-pager -n 80 2>/dev/null | tail -n 80 || true
else
  echo "systemd unit nexus-otp-webhook.service not found (skip systemctl check)"
fi

if [[ -f ".env" ]]; then
  SECRET="$(grep -E '^OTP_WEBHOOK_SECRET=' .env | head -n 1 | cut -d= -f2- | tr -d '\r')"
  if [[ -z "$SECRET" ]]; then
    echo "OTP_WEBHOOK_SECRET not found in .env (skip wrong-secret test)"
  else
    WRONG="WRONG_${SECRET:0:6}"
    http_code="$(curl -sS -o /dev/null -w "%{http_code}" \
      -X POST "http://127.0.0.1:9090/send-otp.php" \
      -H "Content-Type: application/json" \
      -H "X-Nexus-Webhook-Secret: ${WRONG}" \
      -d '{"purpose":"email_verification","channel":"email","login":"smoke","to_email":"a@b.c","code":"12345678","verify_url":""}' || true)"
    echo "Webhook wrong-secret auth -> HTTP ${http_code} (expected 401)"
  fi
else
  echo ".env not found in $NEXUS_DIR (skip webhook secret test)"
fi

echo
echo "=== [7/9] Ingest simulate endpoint (no JWT expected 401) ==="
code="$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "http://127.0.0.1:8080/me/ingest/simulate" \
  -H "Content-Type: application/json" \
  -d '{ "metrics":[{"name":"latency_ms","value":1.0}], "logs":[{"level":"warning","message":"ok"}] }' || true)"
echo "POST /me/ingest/simulate (no auth) -> HTTP ${code} (expected 401)"

echo
echo "=== [8/9] Database sanity (local Postgres container if present) ==="

_count_sql="SELECT 'users' as t, COUNT(*) FROM users UNION ALL SELECT 'api_keys', COUNT(*) FROM api_keys UNION ALL SELECT 'ingested_metrics', COUNT(*) FROM ingested_metrics UNION ALL SELECT 'ingested_logs', COUNT(*) FROM ingested_logs UNION ALL SELECT 'projects', COUNT(*) FROM projects UNION ALL SELECT 'assets', COUNT(*) FROM assets UNION ALL SELECT 'project_scenes', COUNT(*) FROM project_scenes;"

_pg_user="${POSTGRES_USER:-nexus}"
_pg_db="${POSTGRES_DB:-nexus}"

_run_counts_in_container() {
  local cname="$1"
  docker exec -i "$cname" psql -U "$_pg_user" -d "$_pg_db" -c "$_count_sql" || true
}

if [[ "$USE_CLOUD_DB" != "1" ]]; then
  if "${COMPOSE[@]}" ps db >/dev/null 2>&1; then
    "${COMPOSE[@]}" exec -T db psql -U "$_pg_user" -d "$_pg_db" -c "$_count_sql" || true
  else
    echo "db service not in this compose project; skip compose exec"
  fi
else
  _orphan_db="$(docker ps --filter "status=running" --format '{{.Names}}' | grep -E '(^|_)nexus-.*db(-|$)|(^|_)nexus-db-' | head -n 1 || true)"
  if [[ -n "$_orphan_db" ]]; then
    echo "USE_CLOUD_DB=1: найден локальный контейнер Postgres: ${_orphan_db}"
    echo "(Если API смотрит на внешний DATABASE_URL, эти цифры — только про контейнер, не обязательно про рабочую БД API.)"
    _run_counts_in_container "$_orphan_db"
  else
    echo "USE_CLOUD_DB=1: локального контейнера Postgres не видно — пропуск counts (данные только во внешней БД)."
  fi
fi

echo
echo "=== [9/9] Done ==="

