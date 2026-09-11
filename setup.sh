#!/usr/bin/env bash
# First-run bootstrap: certificates, containers, accounts, DKIM keys.
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
source .env
FQDN=${MAIL_HOSTNAME:?set MAIL_HOSTNAME in .env}
SSL_DIR=docker-data/dms/config/ssl

echo "==> 1/5 Self-signed TLS certificate for $FQDN"
mkdir -p "$SSL_DIR/demoCA"
if [ ! -f "$SSL_DIR/$FQDN-cert.pem" ] || [ ! -f "$SSL_DIR/demoCA/cacert.pem" ]; then
  SAN="DNS:$FQDN"
  while read -r d; do
    [ -z "$d" ] && continue
    case "$d" in \#*) continue ;; esac
    SAN="$SAN,DNS:mail.$d,DNS:$d,DNS:autodiscover.$d,DNS:autoconfig.$d"
  done < domains.txt

  # docker-mailserver's SSL_TYPE=self-signed expects a CA at demoCA/cacert.pem
  # plus a server certificate signed by it.
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "$SSL_DIR/demoCA/cakey.pem" \
    -out    "$SSL_DIR/demoCA/cacert.pem" \
    -subj "/CN=Mailsystem local CA" 2>/dev/null

  openssl req -nodes -newkey rsa:2048 \
    -keyout "$SSL_DIR/$FQDN-key.pem" \
    -out    "$SSL_DIR/$FQDN.csr" \
    -subj "/CN=$FQDN" 2>/dev/null

  openssl x509 -req -in "$SSL_DIR/$FQDN.csr" \
    -CA "$SSL_DIR/demoCA/cacert.pem" -CAkey "$SSL_DIR/demoCA/cakey.pem" \
    -CAcreateserial -days 3650 \
    -extfile <(printf 'subjectAltName=%s\nbasicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\n' "$SAN") \
    -out "$SSL_DIR/$FQDN-cert.pem" 2>/dev/null

  rm -f "$SSL_DIR/$FQDN.csr"
  chmod 600 "$SSL_DIR/$FQDN-key.pem" "$SSL_DIR/demoCA/cakey.pem"
  echo "    created $SSL_DIR/$FQDN-cert.pem"
else
  echo "    already present, skipping"
fi

echo "==> 2/5 Starting containers"
docker compose up -d

echo "==> 3/5 Waiting for the mailserver to become healthy"
for _ in $(seq 1 60); do
  if docker exec mailserver ss --listening --tcp 2>/dev/null | grep -qE 'LISTEN.+:smtp'; then
    echo "    up"; break
  fi
  sleep 2
done

echo "==> 4/5 Creating the postmaster mailbox per domain"
while read -r d; do
  [ -z "$d" ] && continue
  case "$d" in \#*) continue ;; esac
  if grep -q "^postmaster@$d|" docker-data/dms/config/postfix-accounts.cf 2>/dev/null; then
    echo "    postmaster@$d exists"
  else
    pw=$(openssl rand -base64 18)
    docker exec mailserver setup email add "postmaster@$d" "$pw" >/dev/null
    echo "    postmaster@$d  password: $pw"
    echo "postmaster@$d $pw" >> initial-passwords.txt
  fi
done < domains.txt
[ -f initial-passwords.txt ] && chmod 600 initial-passwords.txt && \
  echo "    (also saved to initial-passwords.txt — store them safely, then delete the file)"

echo "==> 5/5 Generating DKIM keys"
while read -r d; do
  [ -z "$d" ] && continue
  case "$d" in \#*) continue ;; esac
  echo "    $d"
  docker exec mailserver setup config dkim domain "$d" keysize 2048 >/dev/null 2>&1 || true
done < domains.txt
./scripts/merge-dkim-config.sh >/dev/null
docker compose restart mailserver >/dev/null

cat <<EOF

Done.
  Webmail:  http://localhost:${WEBMAIL_PORT:-8080}
  Next:     ./mailctl dns      # DNS records to publish (see docs/DNS-SETUP.md)
            ./mailctl account add info@gsit.nl
EOF
