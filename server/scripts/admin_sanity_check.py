#!/usr/bin/env python3
"""Sanity-check admin login and real data endpoints (production or local).

Usage:
  cd server
  set API_BASE_URL=https://your-api.up.railway.app/api
  set ADMIN_EMAIL=noeasumbra122602@gmail.com
  set ADMIN_PASSWORD=your-password
  python scripts/admin_sanity_check.py
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

# Reuse URL normalization from verify script
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scripts.verify_production_env import normalize_api_base  # noqa: E402


def _request(
    method: str,
    url: str,
    *,
    token: str | None = None,
    body: dict | None = None,
    cookies: dict | None = None,
) -> tuple[int, dict | str, dict]:
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    if cookies:
        req.add_header("Cookie", "; ".join(f"{k}={v}" for k, v in cookies.items()))
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            set_cookies = {}
            # urllib merges Set-Cookie poorly; token in JSON is enough for Bearer
            try:
                parsed = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                parsed = raw
            return resp.status, parsed, set_cookies
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = raw
        return exc.code, parsed, {}


def _count_list(payload: dict, *keys: str) -> int | None:
    for key in keys:
        val = payload.get(key)
        if isinstance(val, list):
            return len(val)
    return None


def main() -> int:
    api_base = os.environ.get("API_BASE_URL", "http://127.0.0.1:5000/api").strip()
    try:
        api_base = normalize_api_base(api_base)
    except ValueError as exc:
        print(f"ERROR: {exc}")
        return 1

    email = os.environ.get("ADMIN_EMAIL", "noeasumbra122602@gmail.com").strip()
    password = os.environ.get("ADMIN_PASSWORD", "admin123")

    print("=== Admin account sanity check ===\n")
    print(f"API: {api_base}")
    print(f"Admin: {email}\n")

    errors: list[str] = []

    status, login_body, _ = _request(
        "POST",
        f"{api_base}/accounts/login",
        body={"username": email, "password": password, "role": "admin"},
    )

    if status != 200 or not isinstance(login_body, dict):
        print(f"LOGIN FAILED ({status}): {login_body}")
        return 1

    token = login_body.get("access_token")
    roles = login_body.get("roles", [])
    print(f"LOGIN OK — roles={roles}, user_id={login_body.get('user_id')}")

    if "admin" not in [str(r).lower() for r in roles]:
        errors.append("Logged in but JWT roles do not include 'admin'")

    if not token:
        errors.append("No access_token in login response (Bearer calls may fail)")

    headers_token = token or ""

    endpoints = [
        ("GET", "/admin/get-users", "users", ("users",)),
        ("GET", "/admin/stores", "stores", ("stores",)),
        ("GET", "/admin/products", "products", ("products",)),
        ("GET", "/admin/orders", "orders", ("orders",)),
        ("GET", "/admin/get-store-registrations", "pending sellers", ("registrations", "pending")),
        ("GET", "/admin/analytics?days=30", "analytics", ()),
        ("GET", "/admin/categories", "categories", ("categories",)),
        ("GET", "/admin/refund-requests", "refunds", ("refunds", "items")),
        ("GET", "/admin/coupons", "coupons", ("coupons",)),
    ]

    print("\n--- Data endpoints ---")
    for method, path, label, list_keys in endpoints:
        status, body, _ = _request(
            method,
            f"{api_base}{path}",
            token=headers_token,
        )
        if status != 200:
            msg = body.get("msg", body) if isinstance(body, dict) else body
            detail = body.get("detail") if isinstance(body, dict) else None
            print(f"  FAIL {label}: HTTP {status} — {msg}")
            if detail:
                print(f"       detail: {detail}")
            errors.append(f"{label}: HTTP {status}")
            continue

        if not isinstance(body, dict):
            print(f"  OK   {label}: non-JSON 200")
            continue

        if label == "analytics":
            summary = body.get("summary") or {}
            print(
                f"  OK   analytics: orders={summary.get('totalOrders')} "
                f"revenue={summary.get('totalRevenue')} users={summary.get('totalUsers')} "
                f"sellers={summary.get('totalSellers')}"
            )
            if not summary:
                errors.append("analytics: empty summary")
            continue

        count = _count_list(body, *list_keys) if list_keys else None
        if count is not None:
            print(f"  OK   {label}: {count} record(s)")
            sample_key = list_keys[0]
            sample = (body.get(sample_key) or [None])[0]
            if sample and isinstance(sample, dict):
                sid = sample.get("id") or sample.get("userId") or sample.get("storeId")
                name = (
                    sample.get("email")
                    or sample.get("shopName")
                    or sample.get("name")
                    or sample.get("givenName")
                )
                print(f"       sample: id={sid} {name or ''}".rstrip())
        else:
            print(f"  OK   {label}: keys={list(body.keys())[:6]}")

    # Non-admin should be blocked
    print("\n--- Authorization check (buyer login) ---")
    buyer_email = os.environ.get("BUYER_EMAIL", "").strip()
    buyer_password = os.environ.get("BUYER_PASSWORD", "").strip()
    if buyer_email and buyer_password:
        b_status, b_body, _ = _request(
            "POST",
            f"{api_base}/accounts/login",
            body={"username": buyer_email, "password": buyer_password, "role": "buyer"},
        )
        b_token = b_body.get("access_token") if isinstance(b_body, dict) else None
        if b_status == 200 and b_token:
            a_status, a_body, _ = _request(
                "GET",
                f"{api_base}/admin/get-users",
                token=b_token,
            )
            if a_status == 403:
                print("  OK   buyer token correctly denied on /admin/get-users")
            else:
                print(f"  FAIL buyer reached admin API: HTTP {a_status}")
                errors.append("buyer can access admin API")
        else:
            print(f"  SKIP buyer login failed ({b_status})")
    else:
        print("  SKIP set BUYER_EMAIL + BUYER_PASSWORD to test 403 guard")

    print()
    if errors:
        print("FAILED:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("PASSED — admin account can fetch real production data.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
