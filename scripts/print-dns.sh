#!/usr/bin/env bash
# Prints every DNS record you need to publish for the configured domains.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
[ -f .env ] && source .env
HOSTNAME_FQDN=${MAIL_HOSTNAME:-mail.example.com}
PUBLIC_IP=${PUBLIC_IP:-$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo "<YOUR.SERVER.IPV4>")}
PUBLIC_IP6=${PUBLIC_IP6:-}

bar() { printf '\n%s\n' "────────────────────────────────────────────────────────────"; }

bar
echo "Mail host: $HOSTNAME_FQDN"
echo "Server IP: $PUBLIC_IP"
bar

cat <<EOF

A) Records for the mail host itself (zone of $(echo "$HOSTNAME_FQDN" | cut -d. -f2-))

  $HOSTNAME_FQDN.   IN A     $PUBLIC_IP
EOF
[ -n "$PUBLIC_IP6" ] && echo "  $HOSTNAME_FQDN.   IN AAAA  $PUBLIC_IP6"
cat <<EOF

  PTR (reverse DNS) — set at your hosting/VPS provider, not in the zone file:
  $PUBLIC_IP  ->  $HOSTNAME_FQDN
  Without a matching PTR, Gmail/Outlook will reject or spam-folder your mail.
EOF

while read -r domain; do
  [ -z "$domain" ] && continue
  case "$domain" in \#*) continue ;; esac
  bar
  echo "B) Records in the zone of: $domain"
  cat <<EOF

  ; Inbound mail
  $domain.               IN MX    10 $HOSTNAME_FQDN.

  ; SPF — only this server may send for $domain
  $domain.               IN TXT   "v=spf1 mx a:$HOSTNAME_FQDN -all"

  ; DMARC — start at p=none, tighten to quarantine/reject after a week of clean reports
  _dmarc.$domain.        IN TXT   "v=DMARC1; p=none; rua=mailto:postmaster@$domain; ruf=mailto:postmaster@$domain; fo=1; adkim=r; aspf=r"

  ; Autodiscover / autoconfig for mail clients (optional but handy)
  autodiscover.$domain.  IN CNAME $HOSTNAME_FQDN.
  autoconfig.$domain.    IN CNAME $HOSTNAME_FQDN.
  _imaps._tcp.$domain.   IN SRV   0 1 993 $HOSTNAME_FQDN.
  _submission._tcp.$domain. IN SRV 0 1 587 $HOSTNAME_FQDN.

  ; DKIM
EOF
  # Read the public keys from inside the container: on Linux the generated
  # files are owned by root and unreadable for the host user.
  dkim=""
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx mailserver; then
    dkim=$(docker exec mailserver sh -c \
      "cat /tmp/docker-mailserver/rspamd/dkim/*$domain.public.txt \
           /tmp/docker-mailserver/opendkim/keys/$domain/mail.txt 2>/dev/null" 2>/dev/null || true)
  fi
  if [ -z "$dkim" ]; then
    dkim=$(cat docker-data/dms/config/rspamd/dkim/*"$domain".public.txt \
               docker-data/dms/config/opendkim/keys/"$domain"/mail.txt 2>/dev/null || true)
  fi
  if [ -n "$dkim" ]; then
    echo "  ; selector 'mail'"
    echo "$dkim" | sed 's/^/  /'
  else
    echo "  (no DKIM key yet — run: ./mailctl dkim)"
  fi
done < domains.txt

bar
echo "Verify once published:"
FIRST=$(grep -vE '^\s*(#|$)' domains.txt | head -1)
echo "  dig +short MX $FIRST"
echo "  dig +short TXT mail._domainkey.$FIRST"
echo "  dig +short TXT _dmarc.$FIRST"
echo "  dig +short -x $PUBLIC_IP"
echo "  Send a test mail to check-auth@verifier.port25.com or use https://www.mail-tester.com"
bar
