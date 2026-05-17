
set -euo pipefail
BASE="${WAYPOINT_CONTRACT_BASE:-http://127.0.0.1:8080}"
BASE="${BASE%/}"

echo "Checking $BASE/health ..."
curl -sf "$BASE/health" >/dev/null

echo "Checking $BASE/engine/manifest JSON ..."
curl -sf "$BASE/engine/manifest" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d.get('releases'), list)"

echo "OK"
