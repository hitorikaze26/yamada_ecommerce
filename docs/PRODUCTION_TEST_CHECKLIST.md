# Production test checklist (Section K)

Run against **production** Railway + Vercel URLs after each deploy.

## Prerequisites

```powershell
cd server
$env:FLASK_APP="app:create_app"
$env:API_BASE_URL="https://YOUR-API.up.railway.app/api"
$env:CORS_ORIGIN="https://YOUR-APP.vercel.app"
python scripts/verify_production_env.py
```

## 1. Smoke (~5 min)

- [ ] `GET https://YOUR-API/api/health` → `200`, `checks.database` = `ok`
- [ ] Vercel home loads; browser console has no requests to `127.0.0.1:5000`
- [ ] Product images load (Supabase or Railway static URLs)

## 2. Authentication (~15 min)

- [ ] Register buyer → verification email or admin approval path
- [ ] Login buyer → `Set-Cookie` for `access_token_cookie`
- [ ] Hard refresh → still logged in (`GET /api/accounts/protected`)
- [ ] `POST /api/accounts/refresh` → `200` with new token
- [ ] Forgot password → email received (check Railway logs if not)
- [ ] Admin login → `/admin` works; buyer token on `/api/admin/*` → `403`

## 3. Buyer workflow (~20 min)

- [ ] Search / filter / sort products
- [ ] Add to cart → refresh page → cart persists
- [ ] Checkout COD — single click places one order
- [ ] Double-click checkout — no duplicate orders (idempotency)
- [ ] Order in `/buyer/orders`
- [ ] Cancel pending order → inventory restored (variant product spot-check)

## 4. Seller workflow (~25 min)

- [ ] Upload product images → redeploy Railway → images still visible (Supabase)
- [ ] Admin approves seller if pending
- [ ] Seller updates inventory
- [ ] New order notification / seller order list

## 5. Admin workflow (~15 min)

- [ ] Dashboard loads
- [ ] Approve/reject seller application
- [ ] User/product/order management endpoints respond

## 6. Security (~10 min)

- [ ] `GET /api/admin/...` without token → `401`
- [ ] Buyer token on admin route → `403`
- [ ] 11 rapid login attempts → `429` on login
- [ ] Invalid file upload on product → rejected

## 7. Performance (~10 min)

- [ ] Lighthouse on home (LCP reasonable on mobile)
- [ ] Large product list paginates or loads without timeout

## 8. Realtime (optional)

- [ ] Chat message on two tabs (requires gunicorn `-w 1`)
- [ ] In-app notification on new order
