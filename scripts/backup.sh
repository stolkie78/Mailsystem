#!/usr/bin/env bash
# Backup everything that matters: config (bind mount) + mail data (named volumes).
# Usage: ./scripts/backup.sh [target-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

DEST=${1:-backups}
STAMP=$(date +%F-%H%M)
mkdir -p "$DEST"

echo "==> config, settings and webmail database"
tar czf "$DEST/mail-config-$STAMP.tar.gz" \
  docker-data/dms/config docker-data/roundcube/db \
  .env mailserver.env domains.txt config

echo "==> mailboxes (named volume mail-data)"
docker run --rm \
  -v mailsystem_mail-data:/data:ro \
  -v "$PWD/$DEST":/backup \
  alpine tar czf "/backup/mail-data-$STAMP.tar.gz" -C /data .

echo
echo "Written to $DEST:"
ls -lh "$DEST" | grep "$STAMP"
cat <<EOF

Restore:
  tar xzf $DEST/mail-config-$STAMP.tar.gz
  docker volume create mailsystem_mail-data
  docker run --rm -v mailsystem_mail-data:/data -v "\$PWD/$DEST":/backup \\
    alpine tar xzf /backup/mail-data-$STAMP.tar.gz -C /data
  docker compose up -d
EOF
