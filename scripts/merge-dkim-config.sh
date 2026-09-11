#!/usr/bin/env bash
# docker-mailserver writes only the last generated domain into
# rspamd/override.d/dkim_signing.conf. This rebuilds the domain{} block from
# every private key present, so all domains are signed.
#
# The rewrite runs inside the container: on Linux the config directory is owned
# by root (the container writes as root), so the host user cannot write there.
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER=mailserver
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" || {
  echo "The '$CONTAINER' container is not running. Start it with: ./mailctl up" >&2
  exit 1
}

docker exec -i "$CONTAINER" bash -s <<'INNER'
set -euo pipefail
CONF=/tmp/docker-mailserver/rspamd/override.d/dkim_signing.conf
KEYDIR=/tmp/docker-mailserver/rspamd/dkim

[ -f "$CONF" ] || { echo "no dkim_signing.conf yet - run ./mailctl dkim first" >&2; exit 1; }

# keep everything before the domain block
awk '/^domain \{/{exit} {print}' "$CONF" > "$CONF.tmp"

{
  echo "domain {"
  for key in "$KEYDIR"/*.private.txt; do
    [ -e "$key" ] || continue
    file=$(basename "$key")
    base=${file%.private.txt}     # <algo>-<keysize>-<selector>-<domain>
    rest=${base#*-*-}             # <selector>-<domain>
    selector=${rest%%-*}
    domain=${rest#*-}
    printf '    %s {\n        path = "%s/%s";\n        selector = "%s";\n    }\n' \
      "$domain" "$KEYDIR" "$file" "$selector"
  done
  echo "}"
} >> "$CONF.tmp"

mv "$CONF.tmp" "$CONF"
sed -n '/^domain {/,$p' "$CONF"
INNER

echo "Rebuilt docker-data/dms/config/rspamd/override.d/dkim_signing.conf"
