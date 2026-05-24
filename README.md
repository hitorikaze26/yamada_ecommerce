# YAMADA E-Commerce

Full-stack e-commerce platform with buyer, seller, rider, and admin roles. This monorepo contains three applications:

| App | Stack | Port / target |
|-----|-------|---------------|
| [`client/`](client/) | Next.js 16, React 19, TypeScript, Tailwind | Web — local `:3000`, deploy on **Vercel** |
| [`server/`](server/) | Flask, SQLAlchemy, Socket.IO, JWT | API — local `:5000`, deploy on **Render** |
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
       │  Render (Flask) │
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
| `MAIL_*` | Optional | SMTP for email verification / password reset |
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

## Deployment

### Step 1 — Supabase (database)

1. Create a project at [supabase.com](https://supabase.com).
2. Go to **Project Settings → Database** and copy the **Connection string** (URI mode).
3. Use the **Transaction pooler** URL on Render if you hit connection limits.
4. Set as `DATABASE_URL` on Render (the server auto-normalizes `postgres://` to `postgresql+psycopg2://`).

Run migrations against Supabase (one-time, from your machine):

```powershell
cd server
$env:FLASK_ENV="production"
$env:DATABASE_URL="postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres"
flask db upgrade
flask seed-admin
flask seed-report-types
```

> **Note:** Local dev uses MySQL; production uses PostgreSQL on Supabase. Migrations are SQLAlchemy-based and should work on both, but test `flask db upgrade` against Supabase before going live.

### Step 2 — Render (backend API)

1. Push this repo to GitHub.
2. In [Render](https://render.com), create a **Blueprint** from `server/render.yaml`, or manually:
   - **Root Directory:** `server`
   - **Build:** `pip install -r requirements.txt`
   - **Start:** `gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:$PORT --timeout 120 wsgi:app`
   - **Health check path:** `/api/health`
3. Enable **WebSockets**.
4. Set environment variables:

```env
FLASK_ENV=production
DATABASE_URL=<supabase-connection-string>
SECRET_KEY=<generated>
JWT_SECRET_KEY=<generated>
CORS_ORIGINS=https://your-app.vercel.app,http://localhost:3000
MAIL_BACKEND=smtp
MAIL_USERNAME=...
MAIL_PASSWORD=...
OPENROUTESERVICE_API_KEY=...
```

5. Note your Render URL: `https://yamada-api.onrender.com`.

**Mobile and web** both call this same API URL.

### Step 3 — Vercel (web frontend)

1. Import the GitHub repo in [Vercel](https://vercel.com).
2. Set **Root Directory** to `client`.
3. Add environment variable:

```env
NEXT_PUBLIC_API_BASE_URL=https://yamada-api.onrender.com/api
```

4. Deploy. Update `CORS_ORIGINS` on Render with your Vercel domain.

Local dev is unaffected — Vercel uses its own env vars; your machine keeps `client/.env.local`.

### Step 4 — Mobile production build (optional)

```powershell
cd mobile_ecomm
# Edit .env:
# API_BASE_URL=https://yamada-api.onrender.com/api
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
| **Render free tier** | Service spins down after inactivity; first request may be slow (cold start). |
| **File uploads** | Files in `server/app/static/` are ephemeral on Render — lost on redeploy. Use Supabase Storage or S3 for production persistence. |
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
│   └── render.yaml   # Render Blueprint
└── mobile_ecomm/     # Flutter mobile app
```

---

## License

Private project — all rights reserved.
