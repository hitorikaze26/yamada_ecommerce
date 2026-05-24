# YAMADA E-Commerce

Full-stack e-commerce platform with buyer, seller, rider, and admin roles. This monorepo contains three applications:

| App | Stack | Port / target |
|-----|-------|---------------|
| [`client/`](client/) | Next.js 16, React 19, TypeScript, Tailwind | Web — local `:3000`, deploy on **Vercel** |
| [`server/`](server/) | Flask, SQLAlchemy, Socket.IO, JWT | API — local `:5000`, deploy on **Railway** |
| [`mobile_ecomm/`](mobile_ecomm/) | Flutter, Riverpod, Dio | Mobile — local device/emulator, optional store release |

## Architecture

```
┌─────────────┐     ┌─────────────┐
│   Vercel    │     │   Flutter   │
│  (Next.js)  │     │   mobile    │
└──────┬──────┘     └──────┬──────┘
       │  HTTPS REST + WS   │
       └────────┬───────────┘
                ▼
       ┌─────────────────┐
       │ Railway (Flask) │
       │  + Socket.IO    │
       └────────┬────────┘
                │
       ┌────────┴────────┐
       │    Supabase    │  ← production (PostgreSQL)
       │  or local MySQL│  ← local development
       └────────────────┘
```

## Prerequisites

- **Node.js** 20+
- **Python** 3.11+
- **Flutter** SDK 3.x
- **MySQL** 8+ (local development)
- **Supabase** account (production database)
- **Git** and **GitHub CLI** (`gh`) for publishing

---

## Local development

### 1. Backend (`server/`)

```powershell
cd server
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env          # then edit with your local values
flask db upgrade
python run.py
```

API runs at `http://127.0.0.1:5000`. Health check: `GET /api/health`.

**Local database:** Set `DEV_DATABASE_URL` in `server/.env`:

```env
FLASK_ENV=development
DEV_DATABASE_URL=mysql+pymysql://root:YOUR_PASSWORD@localhost:3306/yamada_db
MAIL_BACKEND=console
```

Create the database first:

```sql
CREATE DATABASE yamada_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Seed admin (optional):

```powershell
flask seed-admin
flask seed-report-types
```

### 2. Web client (`client/`)

```powershell
cd client
npm install
copy .env.example .env.local
npm run dev
```

Open `http://localhost:3000`. Default API URL: `http://127.0.0.1:5000/api`.

### 3. Mobile app (`mobile_ecomm/`)

```powershell
cd mobile_ecomm
copy .env.example .env
# Edit .env — uncomment the API_BASE_URL for your device (emulator / simulator / LAN IP)
flutter pub get
flutter run
```

| Device | `API_BASE_URL` |
|--------|----------------|
| Android emulator | `http://10.0.2.2:5000/api` |
| iOS simulator | `http://localhost:5000/api` |
| Physical phone | `http://<YOUR_PC_LAN_IP>:5000/api` |

---

## Environment variables

### Server — [`server/.env.example`](server/.env.example)

| Variable | Required | Description |
|----------|----------|-------------|
| `FLASK_ENV` | Yes | `development` or `production` |
| `DATABASE_URL` | Production | Supabase PostgreSQL connection string |
| `DEV_DATABASE_URL` | Local | MySQL URI when `DATABASE_URL` is unset |
| `SECRET_KEY` | Production | Flask secret |
| `JWT_SECRET_KEY` | Production | JWT signing key |
| `CORS_ORIGINS` | Production | Comma-separated web origins (Vercel URL) |
| `MAIL_BACKEND` | Dev: `console` | `console` logs emails to terminal; `smtp` sends real mail |
| `MAIL_*` | With `smtp` | SMTP for notifications, chat alerts, password reset |
| `OPENROUTESERVICE_API_KEY` | Optional | Shipping distance routing |
| `TWILIO_*` | Optional | SMS notifications |

Generate secrets:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Web — [`client/.env.example`](client/.env.example)

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_API_BASE_URL` | Flask API base URL (must end with `/api`) |
| `NEXT_PUBLIC_PH_SGG_BASE_URL` | Optional PSGC geo API override |

### Mobile — [`mobile_ecomm/.env.example`](mobile_ecomm/.env.example)

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Flask API base URL |
| `APP_SHARE_BASE_URL` | Optional public web URL for sharing links |
| `PH_SGG_BASE_URL` | Philippine geographic data API |

---

## Email notifications

Every in-app notification (orders, refunds, account approvals, etc.) and new chat message (except system/auto-replies) also sends a copy to the user's registered email.

| `MAIL_BACKEND` | Behavior |
|----------------|----------|
| `console` | Emails printed in the Flask server terminal (default for local dev) |
| `smtp` | Real delivery via Gmail or other SMTP (`MAIL_USERNAME`, `MAIL_PASSWORD`) |

---

## Forgot password (web)

1. Open `http://localhost:3000/auth/forgot-password`
2. Enter your account email and submit
3. With `MAIL_BACKEND=console`, check the **Flask terminal** for the 6-digit PIN (not your inbox)
4. Click **Enter reset code** or go to `/auth/reset-pin?email=you@example.com`
5. Enter PIN → set new password → sign in

For real inbox delivery, set `MAIL_BACKEND=smtp` and valid `MAIL_*` credentials in `server/.env`.

Ensure migrations are applied: `flask db upgrade` (creates `password_reset_code` table).

---

## Deployment

### Step 1 — Supabase (database)

1. Create a project at [supabase.com](https://supabase.com).
2. Go to **Project Settings → Database → Connection string**.
3. **Windows / home networks:** Supabase **Direct** (`db.<ref>.supabase.co`) is often **IPv6-only** and will **timeout**. Use **Transaction pooler** instead (IPv4):
   - Host: `aws-1-ap-northeast-1.pooler.supabase.com`
   - Port: **6543**
   - User: `postgres.<your-project-ref>` (e.g. `postgres.ejbrslppplbraljaifaz`)
4. For **Railway**, use the same **Transaction pooler** URL (`:6543`) as `DATABASE_URL`.
5. Set as `DATABASE_URL` (the server auto-normalizes `postgres://` and adds `sslmode=require`).

Run migrations against Supabase (one-time, from your machine):

```powershell
cd server
.\.venv\Scripts\activate
pip install psycopg2-binary

$env:FLASK_ENV="production"
# Windows-friendly (IPv4 pooler — replace ref, password, region if different):
$env:DATABASE_URL="postgresql://postgres.PROJECT_REF:PASSWORD@aws-1-ap-northeast-1.pooler.supabase.com:6543/postgres"

# Test connection first (fails fast with a clear error if URL/network is wrong)
python scripts/check_db_connection.py

flask db upgrade
flask seed-admin
flask seed-report-types
```

> **Note:** `server/.env` defaults to local MySQL (`FLASK_ENV=development`). You must set `FLASK_ENV=production` and `DATABASE_URL` in the **same PowerShell session** before migrating Supabase.

**If `flask db upgrade` shows no output for a long time:**

1. Wait 30–60s — the first lines are `Alembic: preparing database connection...`
2. First run on empty Supabase can take **5–15 minutes** (many migrations); you should then see `Running upgrade ...` lines
3. Run `python scripts/check_db_connection.py` — if all attempts timeout, your ISP blocks Postgres; migrate via **Railway** instead (see below)
4. Ensure `pip install psycopg2-binary` completed in your venv

> **Note:** Local dev uses MySQL; production uses PostgreSQL on Supabase. Migrations are SQLAlchemy-based and should work on both, but test `flask db upgrade` against Supabase before going live.

**If local connection times out (Globe / home ISP blocks Postgres ports):**

Your PC may not reach Supabase on ports `5432` or `6543` at all (`timeout expired` to `13.114.6.6`). This is a **network block**, not a wrong password.

1. **Supabase → Database → Network Restrictions:** allow your public IP `216.247.83.140/32` or disable restrictions temporarily.
2. **Try mobile hotspot** (different ISP) and run `python scripts/check_db_connection.py` again.
3. **Skip local migrate — use Railway instead** (recommended if local times out):

   Full guide: [`docs/DEPLOY-RAILWAY.md`](docs/DEPLOY-RAILWAY.md)

   1. Copy **Transaction pooler** URI (port **6543**) from Supabase → set as `DATABASE_URL` on Railway.
   2. Create Railway service with **Root Directory** `server` (reads [`server/railway.json`](server/railway.json)).
   3. Deploy — `preDeployCommand: flask db upgrade` runs migrations on Railway’s network.
   4. In Railway **Shell** (once): `flask seed-admin` && `flask seed-report-types`.
   5. Deploy Vercel with `NEXT_PUBLIC_API_BASE_URL=https://<railway-host>/api`.

Your Supabase **Transaction pooler** connection string is the correct format — keep using port **6543**.

### Step 2 — Railway (backend API)

1. Push this repo to GitHub.
2. In [Railway](https://railway.app), **New Project** → **Deploy from GitHub repo**.
3. Set **Root Directory** to `server`.
4. Config is in [`server/railway.json`](server/railway.json):
   - **Build:** `pip install -r requirements.txt`
   - **Pre-deploy:** `flask db upgrade`
   - **Start:** `gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:$PORT --timeout 120 wsgi:app`
   - **Health check:** `/api/health`
5. **Settings → Networking → Generate Domain** for a public URL.
6. Set environment variables:

```env
FLASK_APP=app:create_app
FLASK_ENV=production
DATABASE_URL=<supabase-transaction-pooler-uri>
SECRET_KEY=<generated>
JWT_SECRET_KEY=<generated>
WTF_CSRF_SECRET_KEY=<generated>
CORS_ORIGINS=https://your-app.vercel.app,http://localhost:3000
MAIL_BACKEND=smtp
MAIL_USERNAME=...
MAIL_PASSWORD=...
OPENROUTESERVICE_API_KEY=...
```

7. Note your Railway URL: e.g. `https://yamada-api-production.up.railway.app`.

**Mobile and web** both call this same API URL.

See [`docs/DEPLOY-RAILWAY.md`](docs/DEPLOY-RAILWAY.md) for the full walkthrough.

### Step 3 — Vercel (web frontend)

1. Import the GitHub repo in [Vercel](https://vercel.com).
2. Set **Root Directory** to `client`.
3. Add environment variable:

```env
NEXT_PUBLIC_API_BASE_URL=https://yamada-api-production.up.railway.app/api
```

4. Deploy. Update `CORS_ORIGINS` on Railway with your Vercel domain.

Local dev is unaffected — Vercel uses its own env vars; your machine keeps `client/.env.local`.

### Step 4 — Mobile production build (optional)

```powershell
cd mobile_ecomm
# Edit .env:
# API_BASE_URL=https://your-api.up.railway.app/api
# APP_SHARE_BASE_URL=https://your-app.vercel.app
flutter build apk
# or: flutter build ios
```

The `.env` file is gitignored and bundled into the app at build time.

---

## Security checklist

- Never commit `.env`, `.env.local`, or signing keys.
- Rotate any credentials that were previously hardcoded in source before pushing.
- Use strong `SECRET_KEY` and `JWT_SECRET_KEY` in production.
- Set `CORS_ORIGINS` to your actual Vercel domain only (plus localhost for testing).

---

## Known limitations

| Topic | Detail |
|-------|--------|
| **Railway free tier** | Limited usage; upgrade if you hit limits. Cold starts possible on idle services. |
| **File uploads** | Files in `server/app/static/` are ephemeral on Railway — lost on redeploy. Use Supabase Storage or S3 for production persistence. |
| **Dual database** | Local = MySQL, production = Supabase PostgreSQL. Test migrations on Supabase before deploy. |
| **TypeScript** | `client/next.config.mjs` has `ignoreBuildErrors: true` — fix TS errors when time allows. |
| **Socket.IO** | Single worker (`-w 1`) required for in-memory threading mode. Scale with Redis adapter for multiple instances. |

---

## Project structure

```
yamada_e-comerce_part2/
├── client/           # Next.js web app
├── server/           # Flask API + migrations
│   ├── app/          # Blueprints, models, services
│   ├── migrations/   # Alembic migrations
│   ├── run.py        # Local dev server
│   ├── wsgi.py       # Production entry (gunicorn)
│   ├── railway.json  # Railway deploy config
│   └── Procfile      # Start command fallback
└── mobile_ecomm/     # Flutter mobile app
```

---

## License

Private project — all rights reserved.
