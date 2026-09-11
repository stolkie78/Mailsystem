# Domains, mailboxes, aliases and forwarding

All commands run from the project root. `./mailctl` wraps docker-mailserver's
`setup` command; everything is stored as plain files under
`docker-data/dms/config/` so it is easy to back up and inspect.

## Adding a mail domain

There is no "create domain" step — a domain exists as soon as a mailbox exists
for it. Adding `setbaas.nl` is therefore:

```bash
echo "setbaas.nl" >> domains.txt          # so DKIM/DNS helpers know about it
./mailctl account add postmaster@setbaas.nl
./mailctl dkim                              # (re)generate DKIM for all domains
./mailctl dns                               # publish the printed records
```

`gsit.nl` and `setbaas.nl` are already in `domains.txt` and are created by
`./setup.sh`.

## Mailboxes

```bash
./mailctl account add info@gsit.nl 'S3cret-pass'   # password optional -> prompt
./mailctl account list
./mailctl account password info@gsit.nl
./mailctl account del info@gsit.nl
./mailctl quota set info@gsit.nl 5G
```

## Aliases (extra addresses for an existing mailbox)

```bash
./mailctl alias add sales@gsit.nl info@gsit.nl
./mailctl alias add support@gsit.nl info@gsit.nl
./mailctl alias list
./mailctl alias del sales@gsit.nl info@gsit.nl
```

Aliases cost nothing — they are not mailboxes and do not consume storage.

## Forwarding

### 1. Server-side forward to an external address

```bash
./mailctl forward add jobs@gsit.nl recruiter@gmail.com
```

Mail to `jobs@gsit.nl` is delivered straight to Gmail. Note: forwarded mail
keeps the original sender, which can fail the *external* sender's SPF at the
final destination. Keeping a local copy avoids surprises:

```bash
./mailctl forward add jobs@gsit.nl recruiter@gmail.com
./mailctl forward add jobs@gsit.nl jobs@gsit.nl      # also keep a local copy
```

### 2. Catch-all for a whole domain

```bash
./mailctl catchall setbaas.nl info@setbaas.nl
```

Everything addressed to an unknown mailbox `@setbaas.nl` lands in
`info@setbaas.nl`. Convenient, but it attracts spam — prefer explicit aliases.

### 3. Cross-domain

```bash
./mailctl alias add info@setbaas.nl info@gsit.nl
```

### 4. User-managed forwarding (Roundcube)

Users can do it themselves without admin help:
**Settings → Filters → Forwarding** (the ManageSieve plugin is enabled). They
can also set an out-of-office/vacation auto-reply there, and build rules such as
"move everything from X to folder Y".

### 5. Regex / advanced routing

For patterns beyond simple aliases, edit
`docker-data/dms/config/postfix-virtual.cf` (one `alias target` pair per line)
and run `docker compose restart mailserver`.

## Sending from an alias in Roundcube

Roundcube → **Settings → Identities → Create**. Because `SPOOF_PROTECTION=1` is
enabled, a user may only send as an address that belongs to their own mailbox
(their login address or an alias pointing to it).

## Connecting a desktop/mobile client

| Setting | Value |
|---|---|
| IMAP server | `mail.gsit.nl`, port **993**, SSL/TLS |
| SMTP server | `mail.gsit.nl`, port **587**, STARTTLS (or 465, implicit TLS) |
| Username | the full email address |
| Password | the mailbox password |
| Sieve/filters | `mail.gsit.nl`, port **4190**, STARTTLS |

Works for both domains — the hostname is the same, only the username differs.

## Backups

State lives in two places:

| What | Where |
|---|---|
| Accounts, aliases, DKIM keys, TLS certs | `docker-data/dms/config/` (bind mount) |
| Webmail settings, contacts, filters | `docker-data/roundcube/db/` (bind mount) |
| The mailboxes themselves | Docker volume `mailsystem_mail-data` |

Mail data uses a named volume on purpose: Postfix and Dovecot need unix
sockets and POSIX permissions that bind mounts on macOS/Windows cannot provide.

```bash
./scripts/backup.sh              # writes both archives into ./backups
```

Restore instructions are printed by that script.

## Day-to-day operations

```bash
./mailctl up | down | restart | status
./mailctl logs mailserver
./mailctl debug                 # service status inside the container
docker exec -ti mailserver postqueue -p     # mail queue
docker exec -ti mailserver postqueue -f     # flush the queue
```
