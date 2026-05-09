# Zipline 🚀

**Your own file sharing + link shortener.**  
Think: personal Dropbox + bit.ly, but you own it.

Share files with friends, upload screenshots from ShareX, shorten links, create vanity URLs. Everything runs on your server.

Made by [diced](https://github.com/diced/zipline).  
Full docs: [zipline.diced.sh](https://zipline.diced.sh)

---

## 🔗 Zipline + OpenClaw: What You Can Do

Zipline and OpenClaw complement each other perfectly. Here's everything the combo enables:

- **📎 Upload files on demand** — OpenClaw uploads reports, screenshots, audio files to Zipline via API, returns a shareable link
- **🔗 Shorten long URLs** — OpenClaw sends a long URL, Zipline returns a short link ready to paste anywhere
- **📸 Screenshot → link** — ShareX auto-uploads screenshots to Zipline, OpenClaw picks up the link for reports
- **🔒 Share private files** — OpenClaw uploads with password protection, only recipients with the password can view
- **⏳ Temp links with expiry** — OpenClaw sets `Max-Age` or `Max-Views`, files self-destruct after time or views
- **🖼️ Host images & embeds** — Upload images/video/audio, rich embeds in Discord, Telegram, anywhere
- **📊 State & backups** — OpenClaw stores JSON state files or backup archives on Zipline
- **🤖 Webhooks & alerts** — Zipline sends Discord/HTTP webhooks on upload, OpenClaw can listen and react
- **📁 User file management** — OpenClaw lists, tags, folders, deletes files on Zipline through the API
- **🔐 Auto-register users** — OpenClaw creates invite codes or manages Zipline user registration
- **🌐 Vanity short links** — OpenClaw shortens URLs with custom slugs like `go/offer-page` instead of random gibberish
- **📈 Metrics monitoring** — OpenClaw reads Zipline's Prometheus metrics endpoint for dashboards

### Practical examples

```bash
# OpenClaw uploads a daily report → shareable link
curl -X POST https://zipline.example.com/api/user/files \
  -H "Authorization: TOKEN" \
  -F "file=@daily-report.pdf"

# OpenClaw shortens a tracking URL → vanity link
curl -X POST https://zipline.example.com/api/user/urls \
  -H "Authorization: TOKEN" \
  -d '{"destination": "...", "vanity": "track-order"}'

# OpenClaw uploads a password-protected file → secure share
curl -X POST https://zipline.example.com/api/user/files \
  -H "Authorization: TOKEN" \
  -H "X-Zipline-Password: secret123" \
  -F "file=@private.pdf"

# OpenClaw creates a link that expires after 10 views
curl -X POST https://zipline.example.com/api/user/urls \
  -H "Authorization: TOKEN" \
  -d '{"destination": "https://...", "maxViews": 10}'

# OpenClaw lists all uploaded files
curl -X GET https://zipline.example.com/api/user/files \
  -H "Authorization: TOKEN"

# OpenClaw deletes an old file
curl -X DELETE https://zipline.example.com/api/user/files/FILE_ID \
  -H "Authorization: TOKEN"
```

### OpenClaw tool config

Add Zipline as a tool in your OpenClaw configuration:

```yaml
tools:
  zipline_upload:
    description: "Upload a file to Zipline and return the shareable URL"
    api:
      kind: "url"
      url: "https://zipline.example.com/api/user/files"
      method: "POST"
      headers:
        Authorization: "YOUR_TOKEN"
      body:
        kind: "form-data"
        fields:
          file: "$FILE"

  zipline_shorten:
    description: "Shorten a URL using Zipline"
    api:
      kind: "url"
      url: "https://zipline.example.com/api/user/urls"
      method: "POST"
      headers:
        Authorization: "YOUR_TOKEN"
        Content-Type: "application/json"
      body:
        kind: "json"
        fields:
          destination: "$URL"
          vanity: "$VANITY"
```

---

## 🎯 Quick Start (5 minutes)

**Option A — Clone this repo** (includes config files and scripts):

```bash
git clone https://github.com/exFirst/upload-openclaw-toolkit.git ~/zipline
cd ~/zipline
cp .env.example .env
# Edit .env — replace secrets
docker compose up -d
```

**Option B — From scratch:**

```bash
mkdir ~/zipline && cd ~/zipline
curl -LO https://zipline.diced.sh/docker-compose.yml
echo "POSTGRESQL_PASSWORD=$(openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -32)" > .env
echo "CORE_SECRET=$(openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -32)" >> .env
docker compose up -d
```

Open `http://your-server:3000` — you'll see a setup page.  
Create an admin account. Done ✅

> **Hardware note:** Zipline needs a CPU with AVX support. Most modern Intel/AMD CPUs have it.

---

> **Screenshot workflow:** ShareX → Zipline → link in clipboard.  
> Combine with OpenClaw for auto-reports. See [ShareX setup below](#-sharex-integration).

---

## 📸 ShareX Integration

Set up ShareX to auto-upload screenshots to your server:

1. ShareX → **Destinations** → **Custom uploader settings...**
2. Create new uploader:

- **Method:** `POST`
- **URL:** `https://your-zipline.com/api/user/files`
- **Body:** `Form data (multipart)`
- **File form name:** `file`
- **Header:** `Authorization: YOUR_TOKEN`

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

- **Local** — single server, small files. Just set `DATASOURCE_LOCAL_DIRECTORY`
- **S3 / Cloudflare R2** — scalable, backups, multiple servers. Set 5 env vars (type, key, secret, bucket, region)
- **Backblaze B2** — cheapest S3-compatible. Same as S3 with custom endpoint

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

The repo includes [backup.sh](backup.sh) — ready to use:

```bash
# Make executable and test
chmod +x backup.sh
./backup.sh

# Add to crontab (daily at 3 AM)
crontab -e
# Add:
0 3 * * * ~/zipline/backup.sh
```

### Restore
```bash
docker compose down -v
docker compose up -d postgresql
docker compose exec -T postgresql psql -U zipline -d zipline < zipline-db-20250101.sql  # use a specific backup file
# OR for gzipped backups:
gunzip -c zipline-db-20250101.sql.gz | docker compose exec -T postgresql psql -U zipline -d zipline
tar -xzf zipline-uploads-20250101.tar.gz -C ~/zipline/
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
