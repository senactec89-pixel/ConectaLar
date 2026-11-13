# ConectaLar VPS homologation

This stack is only for invited internal testing with fictitious data. It is not
the production API and must not receive real identity documents or real customer
data. Keep `api.conectarlar.com` and all existing services untouched; this stack
serves only `api-homologacao.conectarlar.com`.

The API itself will be reachable from the public internet. Sharing the APK only
with testers is not an access-control boundary, so treat this as a temporary
homologation endpoint and use synthetic accounts/data only.

## What runs

- MySQL 8.4 on a private Docker network, with no host port published.
- The NestJS API on an internal port, with manual professional approval enabled
  only for `NODE_ENV=production`, `CONECTALAR_STAGE=homologacao` and the isolated
  database `conectalar_homologacao`.
- ClamAV on an un-published Docker network; uploads fail closed until scanning
  is healthy.
- Caddy on public TCP 80/443 (and UDP 443), with persistent certificate storage.
- Private persistent Docker volumes for MySQL, uploaded test files, scanner
  signatures and Caddy state.

## Before starting

Confirm the DNS A record for `api-homologacao.conectarlar.com` points to this
VPS. Remove any stale AAAA record unless IPv6 is routed to this VPS. UFW must
allow TCP 80/443. UDP 443 is optional and only needed for HTTP/3; enable it with
`ufw allow 443/udp` if desired. Do not install another web server on these
ports.

This VPS currently has no swap. ClamAV recommends at least 3 GiB of RAM (4 GiB
preferred), and signature reloads can briefly need more. Before starting the
scanner, add 4 GiB of swap to reduce out-of-memory risk; swap is not a substitute
for monitoring RAM. See the [official ClamAV Docker guidance](https://docs.clamav.net/manual/Installing/Docker.html).

On this new VPS, this command creates `/swapfile` only when it does not already
exist, enables it, and makes it persist after reboot. If `/swapfile` already
exists but is not active, stop and inspect it instead of overwriting it:

```sh
if swapon --show=NAME --noheadings | grep -Fxq /swapfile; then
  echo '/swapfile is already active'
elif [ -e /swapfile ]; then
  echo '/swapfile already exists; inspect it before continuing'
  exit 1
else
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
fi
grep -qE '^/swapfile\s' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
free -h
swapon --show
```

From the VPS, clone the handoff branch in a dedicated directory, then enter
`deploy/homologacao`:

```sh
git clone --branch handoff/conectalar-continuacao-2026-11-12 \
  https://github.com/senactec89-pixel/ConectaLar.git /opt/conectalar
cd /opt/conectalar/deploy/homologacao
cp .env.example .env
chmod 600 .env
nano .env
```

Replace every `CHANGE_ME_...` value. Generate the three encryption/token keys
separately, each with `openssl rand -base64 48`. Make the DB passwords unique.
Configure SMTP before launch; the API intentionally refuses production-mode
startup without it. If Google sign-in is being tested, set the OAuth Web client
ID expected by the API; it is not the Android Maps API key. Never send secrets
in chat or commit `.env`.

## First deployment

Validate Compose and build the API image:

```sh
docker compose config --quiet
docker compose build api
docker compose pull db clamav proxy
docker compose up -d db clamav
docker compose ps
```

Wait until `db` and `clamav` show `healthy`. The first ClamAV start downloads
signatures and may take several minutes. Then run migrations against the empty,
dedicated database:

```sh
docker compose run --rm api node node_modules/typeorm/cli.js migration:run -d dist/database/data-source.js
```

Create the first administrator once. Keep these values only in this interactive
shell; use a strong password and do not put it in command history:

```sh
read -r -p 'Admin name: ' INITIAL_ADMIN_NAME
read -r -p 'Admin email: ' INITIAL_ADMIN_EMAIL
read -r -s -p 'Admin password: ' INITIAL_ADMIN_PASSWORD; printf '\n'
export INITIAL_ADMIN_NAME INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD
docker compose run --rm \
  -e BOOTSTRAP_INITIAL_ADMIN_ON_BUILD=true \
  -e INITIAL_ADMIN_NAME -e INITIAL_ADMIN_EMAIL -e INITIAL_ADMIN_PASSWORD \
  api node scripts/bootstrap-initial-admin-if-enabled.mjs
unset INITIAL_ADMIN_NAME INITIAL_ADMIN_EMAIL INITIAL_ADMIN_PASSWORD
```

Start the API and HTTPS proxy:

```sh
docker compose up -d api proxy
docker compose ps
docker compose logs --tail=100 api proxy
curl -fsS https://api-homologacao.conectarlar.com/health/ready
```

After the administrator enrolls MFA, create only invited synthetic test accounts.
The migrations create the base categories, but the service catalog is not
automatically published or enabled. Configure the test services and options
through the administrator screens before trying to submit a request.
Do not run `docker compose down -v`: `-v` deletes the database, uploaded files,
scanner signatures and Caddy certificates.

## Routine operation

```sh
docker compose ps
docker compose logs -f --tail=100 api
docker compose pull
docker compose build api
docker compose up -d
```

Before each update, make a database backup and test restore procedures. A simple
manual SQL backup (store outside the Git checkout, restrict permissions, and
encrypt before moving it off the VPS):

```sh
umask 077
mkdir -p backups
docker compose exec -T db sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$MYSQL_DATABASE"' > "backups/homologacao-$(date -u +%Y%m%dT%H%M%SZ).sql"
```

The Docker volumes live on this VPS and are not a substitute for an off-server,
encrypted backup. Keep only synthetic data in this environment.
