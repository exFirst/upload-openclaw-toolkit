#!/bin/bash
# Zipline automatic backup script
# Usage: ./backup.sh
# Recommended: add to crontab (daily at 3 AM)

set -e

BACKUP_DIR="$HOME/zipline-backups"
DATE=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR/{db,files}"

echo "=== Zipline Backup: $DATE ==="

# 1. Database dump
echo "Backing up database..."
docker compose exec -T postgresql pg_dump -U zipline zipline | gzip > "$BACKUP_DIR/db/zipline-db-$DATE.sql.gz"
echo "  ✅ Database: $(du -h "$BACKUP_DIR/db/zipline-db-$DATE.sql.gz" | cut -f1)"

# 2. Uploaded files
echo "Backing up uploaded files..."
tar -czf "$BACKUP_DIR/files/zipline-uploads-$DATE.tar.gz" uploads/ 2>/dev/null || echo "  ⚠️  No uploads directory found"
echo "  ✅ Files: $(du -h "$BACKUP_DIR/files/zipline-uploads-$DATE.tar.gz" 2>/dev/null | cut -f1)"

# 3. .env backup (secrets!)
echo "Backing up .env..."
cp .env "$BACKUP_DIR/db/zipline-env-$DATE.txt" 2>/dev/null || echo "  ⚠️  No .env found"

# 4. Clean old backups
echo "Cleaning backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR/db" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR/files" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo ""
echo "=== Backup Complete ==="
echo "Location: $BACKUP_DIR"
