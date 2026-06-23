#!/bin/bash
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups/v_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
rsync -av --exclude 'build' --exclude '.dart_tool' --exclude 'backups' . "$BACKUP_DIR"
echo "Бэкап создан: $BACKUP_DIR"
