# Zipline 🚀

**Your own file sharing + link shortener.**  
Think: personal Dropbox + bit.ly, but you own it.

Share files with friends, upload screenshots from ShareX, shorten links, create vanity URLs. Everything runs on your server.

Made by [diced](https://github.com/diced/zipline).  
Full docs: [zipline.diced.sh](https://zipline.diced.sh)

---

## 🎯 Quick Start (5 minutes)

```bash
# 1. Create a folder
mkdir ~/zipline && cd ~/zipline

# 2. Download the setup
curl -LO https://zipline.diced.sh/docker-compose.yml

# 3. Generate passwords
echo "POSTGRESQL_PASSWORD=$(openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -32)" > .env
echo "CORE_SECRET=$(openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -32)" >> .env

# 4. Run!
docker compose up -d
```

Open `http://your-server:3000` — you'll see a setup page.  
Create an admin account. Done ✅

> **Hardware note:** Zipline needs a CPU with AVX support. Most modern Intel/AMD CPUs have it.

---

## 🔗 Integrate with OpenClaw

Zipline gives OpenClaw the ability to **upload files and shorten URLs** via API.

### Upload a file from OpenClaw

```bash
# Using curl in an OpenClaw action
curl -X POST https://your-zipline.com/api/user/files \
  -H "Authorization: YOUR_TOKEN" \
  -F "file=@report.pdf"
# Returns: {"url": "https://zipline.example.com/u/abc123"}
```

### Shorten a URL from OpenClaw

```bash
curl -X POST https://your-zipline.com/api/user/urls \
  -H "Authorization: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"destination": "https://very-long-url.com/page"}'
# Returns: {"url": "https://zipline.example.com/go/abc123"}
```

### Auto-upload screenshots

Combine with ShareX → every screenshot → auto-uploaded → URL in clipboard.  
(See [ShareX setup below](#-sharex-integration).)

### OpenClaw tool example

```yaml
# In your OpenClaw tool config
tools:
  zipline_upload:
    description: "Upload a file to Zipline"
    api:
      kind: "url"
      url: "https://your-zipline.com/api/user/files"
      headers:
        Authorization: "YOUR_TOKEN"
```

---

## 📸 ShareX Integration

Set up ShareX to auto-upload screenshots to your server:

1. ShareX → **Destinations** → **Custom uploader settings...**
2. Create new uploader:

| Setting | Value |
|---------|-------|
| Method | `POST` |
| URL | `https://your-zipline.com/api/user/files` |
| Body | `Form data (multipart)` |
| File form name | `file` |
| Header | `Authorization: YOUR_TOKEN` |

3. **Response parsing:**
   - URL: `$json:url$`
   - Deletion URL: `$json:id$`

Done. Screenshots → your server instantly.

---

## 🔗 URL Shortener

Built-in. No extra services needed.

### Via Dashboard
- Go to **URLs** → **Shorten URL**
- Paste the link → get a short one

### Via API
```bash
curl -X POST https://zipline.example.com/api/user/urls \
  -H "Authorization: YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"destination": "https://example.com"}'
```
→ `https://zipline.example.com/go/x7k2p9`

### Vanity URLs
```bash
curl -X POST ... -d '{"destination": "...", "vanity": "my-link"}'
```
→ `https://zipline.example.com/go/my-link`

### Password-protect a URL
```bash
curl -X POST ... \
  -H "X-Zipline-Password: secret123" \
  -d '{"destination": "https://private-site.com"}'
```
→ Visitors must enter password  
→ You can access with `?pw=secret123`

---

## 📁 File Sharing

### Upload via Dashboard
Drag & drop files. Get a link. Share it.

### Upload via API
```bash
curl -X POST https://zipline.example.com/api/user/files \
  -H "Authorization: YOUR_TOKEN" \
  -F "file=@photo.jpg"
```

### Password-protected files
```bash
curl -X POST ... \
  -H "Authorization: YOUR_TOKEN" \
  -H "X-Zipline-Password: secret123" \
  -F "file=@private.pdf"
```

### Auto-expire files
```bash
# Delete after 7 days
curl -X POST ... -H "X-Zipline-Max-Age: 7d"

# Delete after 5 views
curl -X POST ... -H "X-Zipline-Max-Views: 5"
```

---

## 🔐 Authentication

Your Zipline instance needs to be secure. Here's how.

### Option 1: Local login (default)
Username + password. First user = admin.

### Option 2: OAuth (Discord, GitHub, Google)
```ini
# .env
FEATURES_OAUTH_REGISTRATION=true
OAUTH_DISCORD_CLIENT_ID=your_id
OAUTH_DISCORD_CLIENT_SECRET=your_secret
```

Same pattern for GitHub, Google, or any OIDC provider.

### Option 3: API tokens (for programs)
Dashboard → Account Settings → API Tokens → Generate.

### Option 4: 2FA
```ini
MFA_TOTP_ENABLED=true
```
Users scan QR code with Google Authenticator / Authy.

### Option 5: Passkeys (passwordless)
```ini
MFA_PASSKEYS_ENABLED=true
MFA_PASSKEYS_RP_ID=zipline.example.com
MFA_PASSKEYS_ORIGIN=https://zipline.example.com
```
Login with fingerprint / Face ID / Windows Hello.

---

## ⚙️ Configuration (`.env`)

Full example:

```ini
# === Required ===
CORE_SECRET=your-random-32-char-secret
POSTGRESQL_PASSWORD=your-db-password

# === Domain & URL style ===
CORE_RETURN_HTTPS_URLS=true        # Set true with SSL
CORE_DEFAULT_DOMAIN=zipline.example.com
CORE_TRUST_PROXY=true              # Set true behind Nginx/Caddy

# === Datasource ===
# Local storage (default):
DATASOURCE_TYPE=local
DATASOURCE_LOCAL_DIRECTORY=./uploads

# OR S3 (AWS, Cloudflare R2, Backblaze B2, Minio):
# DATASOURCE_TYPE=s3
# DATASOURCE_S3_ACCESS_KEY_ID=...
# DATASOURCE_S3_SECRET_ACCESS_KEY=...
# DATASOURCE_S3_BUCKET=zipline

# === Files ===
FILES_ROUTE=/u
FILES_LENGTH=6
FILES_MAX_FILE_SIZE=100mb
FILES_DEFAULT_EXPIRATION=30d
FILES_REMOVE_GPS_METADATA=true

# === URL Shortener ===
URLS_ROUTE=/go
URLS_LENGTH=6

# === Features ===
FEATURES_IMAGE_COMPRESSION=true
FEATURES_THUMBNAILS_ENABLED=true
```

### Storage options

| Type | Best for | Setup |
|------|----------|-------|
| **Local** | Single server, small files | Just set `DATASOURCE_LOCAL_DIRECTORY` |
| **S3 / Cloudflare R2** | Scalable, backups, multiple servers | Set 5 env vars (type, key, secret, bucket, region) |
| **Backblaze B2** | Cheapest S3-compatible | Same as S3 with custom endpoint |

---

## 💾 Backup

Back up **database** (users, URLs, metadata) + **files** (uploads).

### Database (pg_dump)
```bash
docker compose exec -T postgresql pg_dump -U zipline zipline | gzip > backup-$(date +%Y%m%d).sql.gz
```

### Files
```bash
tar -czf uploads-$(date +%Y%m%d).tar.gz ~/zipline/uploads/
```

### Auto-backup script (cron)

Save as `~/zipline/backup.sh`:

```bash
#!/bin/bash
DIR="$HOME/zipline-backups"
mkdir -p "$DIR/{db,files}"

docker compose exec -T postgresql pg_dump -U zipline zipline | gzip > "$DIR/db/db-$(date +%Y%m%d).sql.gz"
tar -czf "$DIR/files/uploads-$(date +%Y%m%d).tar.gz" -C ~/zipline uploads/

# Keep 30 days
find "$DIR" -name "*.gz" -mtime +30 -delete
```

Add to crontab (`crontab -e`):
```cron
0 3 * * * ~/zipline/backup.sh
```

### Restore
```bash
docker compose down -v
docker compose up -d postgresql
docker compose exec -T postgresql psql -U zipline -d zipline < backup.sql
tar -xzf uploads-backup.tar.gz -C ~/zipline/
docker compose up -d
```

---

## 🌐 Reverse Proxy

Always use a reverse proxy for SSL and domain routing.

### Nginx
```nginx
server {
    listen 80;
    server_name zipline.example.com;
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
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
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Caddy (easiest)
```caddyfile
zipline.example.com {
    reverse_proxy localhost:3000
}
```
Caddy handles SSL automatically.

> Don't forget: `CORE_RETURN_HTTPS_URLS=true` and `CORE_TRUST_PROXY=true` in `.env`.

---

## 🔄 Updating

```bash
cd ~/zipline
docker compose pull
docker compose up -d
```

Migrations run automatically.

---

## 📋 Full docker-compose.yml

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

---

## 🙏 Acknowledgments

- **[diced](https://github.com/diced)** — built and maintains Zipline. The entire project, docs, Docker images, regular updates.
- **[Zipline Contributors](https://github.com/diced/zipline/graphs/contributors)** — bug reports, features, PRs.
- **[PostgreSQL](https://postgresql.org/)** — rock-solid database.
- **[Docker](https://docker.com/)** — easy deployment.
- **[Next.js](https://nextjs.org/)** & **[Tailwind CSS](https://tailwindcss.com/)** — Zipline's dashboard.
- **[Prisma](https://prisma.io/)** — database schema & migrations.
- **[ffmpeg](https://ffmpeg.org/)** — video thumbnails.
- **[Sharp](https://sharp.pixelplumbing.com/)** — image compression.
- **[ShareX](https://getsharex.com/)** — perfect screenshot companion.
- **[Let's Encrypt](https://letsencrypt.org/)** — free SSL.
- **[Nginx](https://nginx.org/)** & **[Caddy](https://caddyserver.com/)** — reverse proxies.

Built with ❤️ by the open-source community.
