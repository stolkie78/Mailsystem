# Mailsystem

A self-hosted mail server in Docker for **gsit.nl** and **stolkies.com**.

| Component | Image | Role |
|---|---|---|
| [docker-mailserver](https://docker-mailserver.github.io/docker-mailserver/latest/) | `ghcr.io/docker-mailserver/docker-mailserver:15.0.2` | Postfix + Dovecot + Rspamd + Fail2ban + OpenDKIM/DMARC |
| [Roundcube](https://roundcube.net) | `roundcube/roundcubemail:1.6.9-apache` | Full-featured webmail (folders, contacts, filters, forwarding, vacation, HTML editor, attachments up to 25 MB) |

Features: unlimited mail domains, mailboxes, aliases and forwards; server-side
filters via ManageSieve; spam filtering with Rspamd; DKIM/SPF/DMARC signing and
verification; brute-force protection; quotas.

## Layout

```
compose.yaml                 the two services
.env                         MAIL_HOSTNAME, webmail port
mailserver.env               docker-mailserver settings
domains.txt                  mail domains (gsit.nl, stolkies.com)
setup.sh                     first-run bootstrap
mailctl                      admin CLI (accounts, aliases, forwarding, DKIM, DNS)
config/                      Roundcube overrides
certs/                       TLS certificates (Let's Encrypt volume)
docker-data/                 config + webmail db (mail itself is in Docker volumes)
scripts/backup.sh            backup of config + mailboxes
docs/DNS-SETUP.md            DNS records, step by step
docs/DOMAINS-AND-MAILBOXES.md  domains, mailboxes, aliases, forwarding
```

## Quick start

```bash
# 1. set the public hostname of the server
$EDITOR .env                 # MAIL_HOSTNAME=mail.gsit.nl

# 2. certificates + containers + postmaster mailboxes + DKIM keys
./setup.sh

# 3. print the DNS records to publish, then publish them
./mailctl dns                # details: docs/DNS-SETUP.md

# 4. create mailboxes
./mailctl account add info@gsit.nl
./mailctl account add info@stolkies.com

# 5. log in to webmail
open http://localhost:8080
```

`setup.sh` prints the generated postmaster passwords and writes them to
`initial-passwords.txt` — store them in your password manager and delete the file.

## Ports

| Port | Purpose |
|---|---|
| 25 | SMTP, inbound mail from other servers |
| 465 | Submission, implicit TLS |
| 587 | Submission, STARTTLS |
| 993 | IMAPS |
| 4190 | ManageSieve (filters / forwarding rules) |
| 8080 | Roundcube webmail (put a reverse proxy with HTTPS in front of this) |

## Common tasks

```bash
./mailctl account add info@gsit.nl 'password'      # new mailbox
./mailctl alias add sales@gsit.nl info@gsit.nl     # extra address
./mailctl forward add jobs@gsit.nl you@gmail.com   # forward to external
./mailctl catchall stolkies.com info@stolkies.com  # catch-all
./mailctl dkim                                     # (re)generate DKIM keys
./mailctl dns                                      # DNS records to publish
./mailctl logs mailserver                          # tail logs
./mailctl debug                                    # service status
./scripts/backup.sh                                # backup
```

Full reference: [docs/DOMAINS-AND-MAILBOXES.md](docs/DOMAINS-AND-MAILBOXES.md).

## Before going to production

1. Run on a host with a **static IP**, **port 25 open** and a **PTR record**
   matching `MAIL_HOSTNAME` — see [docs/DNS-SETUP.md](docs/DNS-SETUP.md).
2. Replace the self-signed certificate with Let's Encrypt (`SSL_TYPE=letsencrypt`).
3. Put Roundcube behind a reverse proxy with HTTPS; do not expose port 8080
   directly.
4. Publish SPF, DKIM and DMARC for **both** domains and verify with
   <https://www.mail-tester.com>.
5. Schedule `./scripts/backup.sh` (config + mailbox volume).

> Running this on a laptop/desktop works for testing (webmail, local delivery
> between the two domains), but outbound mail to the internet needs a proper
> server — or configure a relay host (`RELAY_HOST`) in `mailserver.env`.
