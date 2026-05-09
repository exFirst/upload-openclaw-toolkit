# Zipline Deployment Guide 🚀

A comprehensive guide to deploying and configuring [Zipline](https://github.com/diced/zipline) — a lightweight, modern file upload and URL shortening server built with Node.js, designed for ShareX integration, self-hosted file sharing, and more.

**Official repo:** [github.com/diced/zipline](https://github.com/diced/zipline)  
**Documentation:** [zipline.diced.sh](https://zipline.diced.sh)

> **Note for contributors:** This guide is based on Zipline v4. For migration from v3, see [the official migration docs](https://zipline.diced.sh/docs/migrate).

---

## 📖 Table of Contents

- [Features](#-features)
- [Quick Start with Docker Compose](#-quick-start-with-docker-compose)
- [Configuration](#%EF%B8%8F-configuration)
  - [.env File](#env-file)
  - [Core Settings](#core-settings)
  - [Datasource: Local vs S3](#datasource-local-vs-s3)
- [Setting Up a File Share Server](#-setting-up-a-file-share-server)
  - [Uploader Authentication (Tokens)](#uploader-authentication-tokens)
  - [ShareX Integration](#sharex-integration)
  - [File Access & Permissions](#file-access--permissions)
  - [Password-Protected Files](#password-protected-files)
- [Setting Up URL Shortening](#-setting-up-url-shortening)
  - [Creating Short Links via Dashboard](#creating-short-links-via-dashboard)
  - [Creating Short Links via API](#creating-short-links-via-api)
  - [Vanity URLs](#vanity-urls)
  - [Password-Protected URLs](#password-protected-urls)
- [Authentication Methods](#-authentication-methods)
  - [Local Login](#local-login)
  - [OAuth (Discord, GitHub, Google, OIDC)](#oauth-discord-github-google-oidc)
  - [API Tokens](#api-tokens)
  - [Two-Factor Authentication (2FA / TOTP)](#two-factor-authentication-2fa--totp)
  - [Passkeys (Passwordless Login)](#passkeys-passwordless-login)
- [Backup & Restore](#-backup--restore)
  - [Database Backup (PostgreSQL)](#database-backup-postgresql)
  - [File Storage Backup](#file-storage-backup)
  - [Automated Backup Script](#automated-backup-script)
  - [Full Restore](#full-restore)
- [Reverse Proxy Setup](#-reverse-proxy-setup)
  - [Nginx](#nginx)
  - [Caddy](#caddy)
  - [Nginx + SSL (Let's Encrypt)](#nginx--ssl-lets-encrypt)
- [Updating](#-updating)
- [Acknowledgments](#-acknowledgments)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **File uploads** | Upload any file through dashboard, API, or ShareX |
| **URL shortening** | Built-in shortener with vanity URLs and password protection |
| **Partial uploads** | Split large files into chunks for reliable uploads |
| **Image compression** | Automatic WebP/JPEG compression |
| **Video thumbnails** | Auto-generated preview thumbnails via ffmpeg |
| **Multiple datasources** | Local filesystem or S3-compatible storage (AWS, Cloudflare R2, Backblaze B2, Minio) |
| **Authentication** | Local, OAuth (Discord, GitHub, Google, OIDC), API tokens |
| **2FA** | TOTP (Google Authenticator, Authy) + Passkeys |
| **Password protection** | Protect files and URLs with passwords |
| **View limits** | Auto-delete files/URLs after N views |
| **Expiration** | Auto-delete files after a set duration |
| **Discord webhooks** | Notifications on upload/URL creation |
| **HTTP webhooks** | Send event data anywhere |
| **Invites** | Invite-only registration with quotas |
| **Embeds** | Rich embeds for images, videos, audio in Discord/Telegram |
| **PWA** | Installable as a Progressive Web App |
| **Custom themes** | Full theming support |
| **Metrics** | Prometheus-compatible metrics endpoint |

---

## 🐳 Quick Start with Docker Compose

The recommended way to run Zipline in production.

### 1. Create a project directory

```bash
mkdir ~/zipline && cd ~/zipline
```

### 2. Create the `docker-compose.yml`

```yaml
services:
  postgresql:
    image: postgres:16
    restart: unless-stopped
    env_file:
      - .env
    environment:
      POSTGRES_USER: ${POSTGRESQL_USER:-zipline}
      POSTGRES_PASSWORD: ${POST…WORD is required}
      POSTGRES_DB: ${POSTGRESQL_DB:-zipline}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD', 'pg_isready', '-U', 'zipline']
      interval: 10s
      timeout: 5s
      retries: 5

  zipline:
    image: ghcr.io/diced/zipline:latest
    restart: unless-stopped
    ports:
      - '3000:3000'
    env_file:
      - .env
    environment:
      - DATABASE_URL=postgres://${POSTGRESQL_USER:-zipline}:${POSTGRESQL_PASSWORD}@postgresql:5432/${POSTGRESQL_DB:-zipline}
    depends_on:
      postgresql:
        condition: service_healthy
    volumes:
      - './uploads:/zipline/uploads'
      - './public:/zipline/public'
      - './themes:/zipline/themes'
    healthcheck:
      test: ['CMD', 'wget', '-q', '--spider', 'http://0.0.0.0:3000/api/healthcheck']
      interval: 15s
      timeout: 2s
      retries: 2

volumes:
  pgdata:
```

### 3. Generate secrets and create `.env`

```bash
# Generate a random database password
echo "POSTGRESQL_PASSWORD=$(openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -32 | tr -d '\n')" > .env

# Generate a random secret for cookie signing
echo "CORE_SECRET=$(openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -32 | tr -d '\n')" >> .env
```

**Requirements:**
- `POSTGRESQL_PASSWORD` — PostgreSQL password (required)
- `CORE_SECRET` — used to sign cookies, must be strong (required)
- `DATABASE_URL` — auto-built from `POSTGRESQL_*` variables
  
**Hardware note:** Zipline requires a CPU with AVX support. Docker images do not support non-AVX CPUs.

### 4. Start the server

```bash
docker compose pull
docker compose up -d
```

Zipline will be available at `http://<your-server-ip>:3000`.  
On first visit you'll be redirected to the setup page to create the admin account.

---

## ⚙️ Configuration

### `.env` File

```ini
# === Required ===
POSTGRESQL_USER=zipline
POSTGRESQL_PASSWORD=your-strong-password
POSTGRESQL_DB=zipline
CORE_SECRET=your-32-char-secret

# === Core ===
CORE_PORT=3000
CORE_HOSTNAME=0.0.0.0
CORE_RETURN_HTTPS_URLS=false    # Set true behind reverse proxy with SSL
CORE_DEFAULT_DOMAIN=zipline.example.com
CORE_TRUST_PROXY=false          # Set true behind Nginx/Caddy

# === Datasource (pick one) ===
# Local storage (default)
DATASOURCE_TYPE=local
DATASOURCE_LOCAL_DIRECTORY=./uploads

# === URL Shortener ===
URLS_ROUTE=/go
URLS_LENGTH=6

# === Files ===
FILES_ROUTE=/u
FILES_LENGTH=6
FILES_MAX_FILE_SIZE=100mb
FILES_DEFAULT_EXPIRATION=30d    # Auto-delete after 30 days
FILES_REMOVE_GPS_METADATA=true

# === Features ===
FEATURES_USER_REGISTRATION=true
FEATURES_OAUTH_REGISTRATION=false
FEATURES_IMAGE_COMPRESSION=true
FEATURES_THUMBNAILS_ENABLED=true
FEATURES_DELETE_ON_MAX_VIEWS=true

# === Chunks (large file uploads) ===
CHUNKS_ENABLED=true
CHUNKS_SIZE=25mb
CHUNKS_MAX=95mb

# === Multi-Factor ===
MFA_TOTP_ENABLED=true
MFA_TOTP_ISSUER=Zipline
MFA_PASSKEYS_ENABLED=true
MFA_PASSKEYS_RP_ID=zipline.example.com
MFA_PASSKEYS_ORIGIN=https://zipline.example.com
```

### Core Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CORE_HOSTNAME` | string | `0.0.0.0` | Bind address |
| `CORE_PORT` | number | `3000` | Listen port |
| `CORE_SECRET` | string | *required* | Cookie signing secret |
| `CORE_RETURN_HTTPS_URLS` | boolean | `false` | Return `https://` URLs |
| `CORE_DEFAULT_DOMAIN` | string | — | Domain for returned URLs |
| `CORE_TRUST_PROXY` | boolean | `false` | Enable behind reverse proxy |
| `DATABASE_URL` | string | *required* | PostgreSQL connection string |

### Datasource: Local vs S3

**Local filesystem** (default):

```ini
DATASOURCE_TYPE=local
DATASOURCE_LOCAL_DIRECTORY=./uploads
```

**S3-compatible** (AWS, Cloudflare R2, Backblaze B2, Hetzner, Minio):

```ini
DATASOURCE_TYPE=s3
DATASOURCE_S3_ACCESS_KEY_ID=your-key
DATASOURCE_S3_SECRET_ACCESS_KEY=your-secret
DATASOURCE_S3_BUCKET=zipline
DATASOURCE_S3_REGION=us-east-1

# Custom endpoint (non-AWS):
# Cloudflare R2
DATASOURCE_S3_ENDPOINT=https://123abc.r2.cloudflarestorage.com
# Backblaze B2
DATASOURCE_S3_ENDPOINT=https://s3.us-west-004.backblazeb2.com
# Minio (local)
DATASOURCE_S3_ENDPOINT=http://localhost:9000
DATASOURCE_S3_FORCE_PATH_STYLE=true
```

> ⚠️ **Warning:** For non-AWS providers, you may need `DATASOURCE_S3_FORCE_PATH_STYLE=true`.

---

## 📁 Setting Up a File Share Server

Zipline is perfect for self-hosted file sharing — similar to a personal Dropbox or an image host for ShareX.

### Uploader Authentication (Tokens)

Every user gets an API token for programmatic uploads:

1. Log into the dashboard
2. Go to Account Settings → API Tokens
3. Generate a new token
4. Use it in the `Authorization` header:

```bash
curl -X POST https://your-zipline.com/api/user/files \
  -H "Authorization: YOUR_TOKEN" \
  -F "file=@screenshot.png"
```

Response:
```json
{
  "id": "file_abc123",
  "name": "screenshot.png",
  "url": "https://your-zipline.com/u/abc123",
  "type": "image/png",
  "size": 123456,
  "createdAt": "2026-03-03T10:00:00.000Z"
}
```

### ShareX Integration

Zipline is fully ShareX-compatible. Configure it in ShareX:

1. In ShareX, go to **Destinations → Custom uploader settings...**
2. Create a new uploader with these settings:

**Request:**

| Field | Value |
|-------|-------|
| Method | `POST` |
| URL | `https://your-zipline.com/api/user/files` |
| Body | `Form data (multipart)` |
| File form name | `file` |
| Header: `Authorization` | `YOUR_TOKEN` |
| Header: `X-Zipline-File-Name` | `%ra%` (optional — keeps original filename) |

**Response parsing:**

| Type | Value |
|------|-------|
| URL | `$json:url$` |
| Thumbnail URL | `$json:url$` |
| Deletion URL | `$json:id$` |

Now any screenshot you take with ShareX will auto-upload to your Zipline server.

### File Access & Permissions

Files are served at `{FILES_ROUTE}/{code}` (default: `/u/abc123`).

- **Public:** By default, files are accessible to anyone with the URL
- **Private:** You can make files require authentication via dashboard settings
- **Password-protected:** Set a password per-file (see below)

### Password-Protected Files

Protect files with a password via API:

```bash
curl -X POST https://your-zipline.com/api/user/files \
  -H "Authorization: YOUR_TOKEN" \
  -H "X-Zipline-Password: secret123" \
  -F "file=@private.pdf"
```

Users accessing the file will see a password prompt.  
Access with: `https://your-zipline.com/u/abc123?pw=secret123`

### Additional File Features

- **Expiration:** `X-Zipline-Max-Age: 7d` — auto-deletes after 7 days
- **Max views:** `X-Zipline-Max-Views: 5` — auto-deletes after 5 views
- **Format overrides:** via dashboard settings (random, UUID, dates, original name, gfycat-style)

---

## 🔗 Setting Up URL Shortening

Zipline includes a fully-featured URL shortener — think of it as your personal `bit.ly`.

### How It Works

1. You provide a destination URL
2. Zipline generates a short code (configurable length)
3. Visitors get redirected to the destination via `{URLS_ROUTE}/{code}`

Configuration via `.env`:

```ini
URLS_ROUTE=/go       # default: /go, can be /s or even /
URLS_LENGTH=6        # code length (default: 6, min: 4)
```

### Creating Short Links via Dashboard

1. Navigate to the **URLs** section
2. Click **"Shorten URL"**
3. Enter the destination URL
4. Optionally configure:
   - Custom vanity URL (e.g., `my-cool-link`)
   - Password protection
   - Max views (auto-disable after N clicks)
   - Enable/disable state

### Creating Short Links via API

```bash
curl -X POST https://your-zipline.com/api/user/urls \
  -H "Authorization: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "https://example.com/very/long/url",
    "vanity": "mylink"
  }'
```

Response:
```json
{
  "id": "url_abc123",
  "code": "x7k2p9",
  "vanity": "mylink",
  "destination": "https://example.com/very/long/url",
  "url": "https://your-zipline.com/go/mylink",
  "views": 0,
  "enabled": true,
  "createdAt": "2026-03-03T10:00:00.000Z"
}
```

### Vanity URLs

Create custom short links instead of random codes:

```bash
curl -X POST https://your-zipline.com/api/user/urls \
  -H "Authorization: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "https://github.com/diced/zipline",
    "vanity": "zipline-repo"
  }'
```
→ `https://your-zipline.com/go/zipline-repo`

> ⚠️ Vanity URLs must be unique across the entire system. If taken, you'll get a `400` error.

### Password-Protected URLs

```bash
curl -X POST https://your-zipline.com/api/user/urls \
  -H "Authorization: YOUR_TOKEN" \
  -H "X-Zipline-Password: secret123" \
  -H "Content-Type: application/json" \
  -d '{"destination": "https://private-site.com"}'
```

Access with password: `https://your-zipline.com/go/abc123?pw=secret123`

### Multiple Domains

Serve short URLs from different domains. Pass them in the header:

```bash
curl -X POST https://your-zipline.com/api/user/urls \
  -H "Authorization: YOUR_TOKEN" \
  -H "X-Zipline-Domain: short.domain.com" \
  -H "Content-Type: application/json" \
  -d '{"destination": "https://example.com"}'
```

Multiple domains (Zipline picks one randomly):
```bash
X-Zipline-Domain: short1.com,short2.com,short3.com
```

---

## 🔐 Authentication Methods

### Local Login

Default authentication — username and password.

- Register through the dashboard (if registration is enabled)
- First user (via setup page) becomes super admin
- Settings: `FEATURES_USER_REGISTRATION=true|false`

### OAuth (Discord, GitHub, Google, OIDC)

Zipline supports 4 OAuth providers out of the box.

**1. Enable OAuth in settings:**

- Dashboard → Settings → Features → Enable OAuth Registration
- Or via `.env`: `FEATURES_OAUTH_REGISTRATION=true`

**2. Configure provider credentials:**

Each provider requires specific environment variables. Example for **Discord**:

```ini
OAUTH_DISCORD_CLIENT_ID=your_discord_client_id
OAUTH_DISCORD_CLIENT_SECRET=your_discord_client_secret
```

And for **GitHub**:

```ini
OAUTH_GITHUB_CLIENT_ID=your_github_client_id
OAUTH_GITHUB_CLIENT_SECRET=your_github_client_secret
```

**3. Optional settings:**

- **Bypass Local Login** — automatically redirects users to the first OAuth provider. Falls back to `?local=true` query parameter if needed.
- **Login Only** — prevents creating new accounts via OAuth (existing OAuth users can still log in).

### API Tokens

All programmatic access (ShareX, scripts) goes through API tokens.

- Generate in Dashboard → Account Settings → API Tokens
- Pass in `Authorization: YOUR_TOKEN` header
- Each token is tied to a user and inherits their permissions

### Two-Factor Authentication (2FA / TOTP)

Enable TOTP-based 2FA for user accounts.

**Server settings:**

```ini
MFA_TOTP_ENABLED=true
MFA_TOTP_ISSUER=Zipline
```

**User setup:**
1. Dashboard → Account Settings → Enable 2FA
2. Scan QR code with Google Authenticator, Authy, or 2FAS
3. Enter code to confirm

After this, login requires username + password + TOTP code.

### Passkeys (Passwordless Login)

Modern phishing-resistant authentication using WebAuthn.

**Server settings:**

```ini
MFA_PASSKEYS_ENABLED=true
MFA_PASSKEYS_RP_ID=zipline.example.com       # Relying Party ID (your domain)
MFA_PASSKEYS_ORIGIN=https://zipline.example.com
```

**User setup:**
1. Dashboard → Account Settings → Add Passkey
2. Use OS dialog (Face ID, fingerprint, Windows Hello, security key)
3. Login with a single click — no password needed

---

## 💾 Backup & Restore

A proper backup strategy covers both the **database** and the **file storage**.

### Database Backup (PostgreSQL)

Zipline stores metadata, URLs, users, and settings in PostgreSQL. Back it up with `pg_dump`:

```bash
# Manual backup
docker compose exec -T postgresql pg_dump -U zipline zipline > ~/backups/zipline-db-$(date +%Y%m%d-%H%M%S).sql

# Compressed
docker compose exec -T postgresql pg_dump -U zipline zipline | gzip > ~/backups/zipline-db-$(date +%Y%m%d-%H%M%S).sql.gz
```

### File Storage Backup

**If using local storage:**

```bash
# Backup the uploads directory
rsync -av ~/zipline/uploads/ ~/backups/uploads/

# Or tar it
tar -czf ~/backups/zipline-uploads-$(date +%Y%m%d-%H%M%S).tar.gz ~/zipline/uploads/
```

**If using S3** (Cloudflare R2, Backblaze B2, etc.):
- Use your S3 provider's native backup/replication
- Or sync to another bucket: `aws s3 sync s3://your-bucket s3://backup-bucket`

Don't forget to also back up `public/` (public assets) and `themes/` (custom themes) if you use them.

### Automated Backup Script

Save as `~/zipline/backup.sh` and set up a cron job:

```bash
#!/bin/bash
# Zipline auto-backup script

BACKUP_DIR="$HOME/zipline-backups"
DB_CONTAINER="zipline-postgresql-1"  # Adjust based on `docker compose ps`
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR/{db,files}"
DATE=$(date +%Y%m%d-%H%M%S)

# Backup database
docker compose exec -T postgresql pg_dump -U zipline zipline | gzip > "$BACKUP_DIR/db/zipline-db-$DATE.sql.gz"

# Backup files
tar -czf "$BACKUP_DIR/files/zipline-uploads-$DATE.tar.gz" -C "$(dirname $(pwd))" uploads/

# Remove backups older than retention period
find "$BACKUP_DIR/db" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR/files" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
```

Make it executable and add to crontab:

```bash
chmod +x ~/zipline/backup.sh
crontab -e
# Add:
0 3 * * * ~/zipline/backup.sh
```

This runs daily at 3:00 AM and keeps 30 days of backups.

### Full Restore

```bash
# Stop and remove volumes
docker compose down -v

# Restore database from SQL dump
docker compose up -d postgresql
docker compose exec -T postgresql psql -U zipline -d zipline < zipline-db-backup.sql

# Restore files
tar -xzf zipline-uploads-backup.tar.gz -C ~/zipline/

# Start everything
docker compose up -d
```

---

## 🔄 Reverse Proxy Setup

For production, always run Zipline behind a reverse proxy for SSL termination, domain routing, and better security.

### Nginx

```nginx
server {
    listen 80;
    server_name zipline.example.com;
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Nginx + SSL (Let's Encrypt)

```nginx
server {
    listen 443 ssl http2;
    server_name zipline.example.com;
    client_max_body_size 100M;

    ssl_certificate /etc/letsencrypt/live/zipline.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zipline.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Don't forget to set `CORE_RETURN_HTTPS_URLS=true` and `CORE_TRUST_PROXY=true` in your `.env`.

### Caddy

Simplest option — Caddy handles SSL automatically:

```caddyfile
zipline.example.com {
    reverse_proxy localhost:3000
}
```

---

## 🔄 Updating

```bash
cd ~/zipline
docker compose pull
docker compose up -d
```

Zipline applies database migrations automatically on startup — no manual migration steps needed.

---

## 🙏 Acknowledgments

Zipline is built on the shoulders of giants. This guide exists thanks to:

- **[diced](https://github.com/diced)** — creator and lead maintainer of Zipline. Built the entire platform, the docs site, the Docker images, and continues to ship regular updates with new features.
- **[Zipline Contributors](https://github.com/diced/zipline/graphs/contributors)** — everyone who filed bug reports, suggested features, and submitted pull requests.
- **[PostgreSQL](https://www.postgresql.org/)** — the rock-solid database that powers Zipline's metadata storage.
- **[Docker](https://www.docker.com/)** and **[Docker Compose](https://docs.docker.com/compose/)** — making deployment trivial across any Linux server.
- **[Prisma](https://www.prisma.io/)** — the ORM that handles Zipline's database schema and migrations.
- **[Next.js](https://nextjs.org/)** — the React framework behind Zipline's admin dashboard.
- **[Tailwind CSS](https://tailwindcss.com/)** — for Zipline's clean, modern UI.
- **[ffmpeg](https://ffmpeg.org/)** — generating video thumbnails behind the scenes.
- **[Sharp](https://sharp.pixelplumbing.com/)** — fast image processing for compression and thumbnails.
- **[ShareX](https://getsharex.com/)** — the excellent open-source screenshot tool that integrates perfectly with Zipline's API.
- **[Let's Encrypt](https://letsencrypt.org/)** — free SSL certificates for secure file hosting.
- **[Nginx](https://nginx.org/)** and **[Caddy](https://caddyserver.com/)** — reliable reverse proxy solutions.

Built with ❤️ by the open-source community.
