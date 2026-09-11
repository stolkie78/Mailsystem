#!/usr/bin/env bash
# docker-mailserver writes only the last generated domain into
# rspamd/override.d/dkim_signing.conf. This rebuilds the domain{} block from
# every private key present, so all domains are signed.
set -euo pipefail
cd "$(dirname "$0")/.."

CONF=docker-data/dms/config/rspamd/override.d/dkim_signing.conf
KEYDIR=docker-data/dms/config/rspamd/dkim
[ -f "$CONF" ] || { echo "no dkim_signing.conf yet — run ./mailctl dkim first" >&2; exit 1; }

# keep everything before the domain block
awk '/^domain \{/{exit} {print}' "$CONF" > "$CONF.tmp"

{
  echo "domain {"
  for key in "$KEYDIR"/*.private.txt; do
    [ -f "$key" ] || continue
    base=$(basename "$key" .private.txt)          # rsa-2048-<selector>-<domain>
    domain=${base#*-*-}                            # strip "rsa-2048-"
    selector=${domain%%-*}                         # <selector>
    domain=${domain#*-}                            # <domain>
    printf '    %s {\n        path = "/tmp/docker-mailserver/rspamd/dkim/%s";\n        selector = "%s";\n    }\n' \
      "$domain" "$(basename "$key")" "$selector"
  done
  echo "}"
} >> "$CONF.tmp"

mv "$CONF.tmp" "$CONF"
echo "Rebuilt $CONF:"
sed -n '/^domain {/,$p' "$CONF"
