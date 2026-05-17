
set -euo pipefail

INGEST_URL="${WAYPOINT_INGEST_URL:-}"
API_KEY="${WAYPOINT_API_KEY:-}"
HOST_TAG="${WAYPOINT_HOST_LABEL:-$(hostname -s 2>/dev/null || hostname)}"

if [[ -f /etc/waypoint-metrics.env ]]; then
  set -a && source /etc/waypoint-metrics.env && set +a
  INGEST_URL="${WAYPOINT_INGEST_URL:-$INGEST_URL}"
  API_KEY="${WAYPOINT_API_KEY:-$API_KEY}"
  HOST_TAG="${WAYPOINT_HOST_LABEL:-$HOST_TAG}"
fi

if [[ -z "$INGEST_URL" || -z "$API_KEY" ]]; then
  echo "waypoint_host_send_metrics: set WAYPOINT_INGEST_URL and WAYPOINT_API_KEY" >&2
  exit 1
fi

load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)"
mem_total_kb=0
mem_avail_kb=0
if [[ -r /proc/meminfo ]]; then
  mem_total_kb="$(grep -E '^MemTotal:' /proc/meminfo | awk '{print $2}')"
  mem_avail_kb="$(grep -E '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
fi
mem_used_pct=0
if [[ "${mem_total_kb:-0}" -gt 0 ]]; then
  mem_used_pct="$(awk "BEGIN {printf \"%.2f\", 100 * ($mem_total_kb - $mem_avail_kb) / $mem_total_kb}")"
fi

disk_pct=0
disk_line="$(df -P / 2>/dev/null | tail -1 || true)"
if [[ -n "$disk_line" ]]; then
  disk_pct="$(echo "$disk_line" | awk '{gsub(/%/,"",$5); print $5}')"
fi

top_ps="$(ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | awk '{printf "%s(%s%%) ", $11, $3}' | head -c 400 || true)"

payload=$(cat <<EOF
{
  "metrics": [
    { "name": "host.load1", "value": $load1, "tags": { "host": "$HOST_TAG" } },
    { "name": "host.mem_used_percent", "value": $mem_used_pct, "tags": { "host": "$HOST_TAG" } },
    { "name": "host.disk_root_used_percent", "value": $disk_pct, "tags": { "host": "$HOST_TAG" } }
  ],
  "logs": [
    { "level": "info", "message": "host snapshot top_cpu: $top_ps", "tags": { "host": "$HOST_TAG" } }
  ]
}
EOF
)

code="$(curl -sS -o /tmp/waypoint_ingest_resp.txt -w "%{http_code}" -X POST "$INGEST_URL" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d "$payload" || echo "000")"

if [[ "$code" != "200" && "$code" != "204" ]]; then
  echo "waypoint_host_send_metrics: HTTP $code $(cat /tmp/waypoint_ingest_resp.txt 2>/dev/null || true)" >&2
  exit 1
fi
exit 0
