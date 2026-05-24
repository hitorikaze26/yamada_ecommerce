# Deploy backend on Railway (Option C — migrate via cloud)

Use this when your PC cannot reach Supabase locally. Railway runs `flask db upgrade` before each deploy via [`server/railway.json`](../server/railway.json).

## Stack overview

| Layer | Platform |
|-------|----------|
| Web | Vercel (`client/`) |
| API | **Railway** (`server/`) |
| Database | Supabase (PostgreSQL) |
| Mobile | Flutter (`mobile_ecomm/`) → Railway API URL |

## 1. Supabase connection string

Supabase Dashboard → **Connect** → **Transaction pooler** (IPv4, port **6543**):

```
postgresql://postgres.ejbrslppplbraljaifaz:YOUR_PASSWORD@aws-1-ap-northeast-1.pooler.supabase.com:6543/postgres
```

Replace `YOUR_PASSWORD` and URL-encode special characters.

## 2. Create Railway project

1. Go to [railway.app](https://railway.app) → sign in with GitHub.
2. **New Project** → **Deploy from GitHub repo** → select `yamada_ecommerce`.
3. When prompted for the service, set **Root Directory** to `server`.
4. Railway reads [`server/railway.json`](../server/railway.json) and [`server/Procfile`](../server/Procfile).

## 3. Environment variables

In Railway → your service → **Variables**:

| Key | Value |
|-----|--------|
| `FLASK_APP` | `app:create_app` |
| `FLASK_ENV` | `production` |
| `DATABASE_URL` | Supabase Transaction pooler URI (port 6543) |
| `SECRET_KEY` | random string (`python -c "import secrets; print(secrets.token_urlsafe(32))"`) |
| `JWT_SECRET_KEY` | random string |
| `WTF_CSRF_SECRET_KEY` | random string |
| `CORS_ORIGINS` | `https://YOUR-APP.vercel.app,http://localhost:3000` |
| `MAIL_BACKEND` | `smtp` |
| `MAIL_SERVER` | `smtp.gmail.com` |
| `MAIL_PORT` | `587` |
| `MAIL_USE_TLS` | `true` |
| `MAIL_USERNAME` | your Gmail |
| `MAIL_PASSWORD` | Gmail app password |
| `MAIL_DEFAULT_SENDER` | `Yamada Support <your@gmail.com>` |

Optional: `OPENROUTESERVICE_API_KEY`, `TWILIO_*`

## 4. Public domain

1. Railway service → **Settings** → **Networking** → **Generate Domain**.
2. Note the URL, e.g. `https://yamada-api-production.up.railway.app`.

## 5. Deploy

1. Push to GitHub or click **Deploy** in Railway.
2. Check **Deploy Logs** — look for `flask db upgrade` in the pre-deploy phase.
3. Verify: `https://YOUR-DOMAIN.up.railway.app/api/health` → `{"status":"ok"}`.

## 6. Seed admin (one time)

Railway → service → **Shell** (or CLI):

```bash
flask seed-admin
flask seed-report-types
```

Or with Railway CLI from `server/`:

```bash
railway run flask seed-admin
railway run flask seed-report-types
```

## 7. Deploy Vercel (web)

1. [vercel.com](https://vercel.com) → import same GitHub repo.
2. **Root Directory:** `client`
3. Environment variable:

```
NEXT_PUBLIC_API_BASE_URL=https://YOUR-DOMAIN.up.railway.app/api
```

4. Deploy, then update Railway `CORS_ORIGINS` with your Vercel URL.

## 8. Mobile (optional)

`mobile_ecomm/.env`:

```
API_BASE_URL=https://YOUR-DOMAIN.up.railway.app/api
APP_SHARE_BASE_URL=https://YOUR-APP.vercel.app
```

Then `flutter build apk`.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Pre-deploy migrate fails | Check Deploy Logs; verify `DATABASE_URL` and `FLASK_APP=app:create_app` |
| Health check fails | Increase timeout in `railway.json`; check gunicorn/eventlet logs |
| CORS on login | Add exact Vercel URL to `CORS_ORIGINS` on Railway |
| Build can't find gunicorn | Ensure `pip install -r requirements.txt` runs; check `requirements.txt` |
| Emails not sent | Set `MAIL_*` variables on Railway |

## Railway CLI (optional)

```bash
npm i -g @railway/cli
railway login
cd server
railway link
railway up
railway logs
railway domain
```
