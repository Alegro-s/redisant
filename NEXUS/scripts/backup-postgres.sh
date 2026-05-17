set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL (same as server)}"
: "${BACKUP_DIR:=/var/backups/nexus}"
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="$BACKUP_DIR/nexus-$STAMP.sql.gz"
pg_dump "$DATABASE_URL" | gzip -c > "$FILE"
echo "Wrote $FILE"
find "$BACKUP_DIR" -name 'nexus-*.sql.gz' -mtime +14 -delete 2>/dev/null || true
