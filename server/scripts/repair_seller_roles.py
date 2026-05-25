#!/usr/bin/env python3
"""One-off: ensure users with a seller_profiles row have the seller role by name.

Usage (Railway shell):
  cd server && FLASK_APP=app:create_app flask shell
  >>> from scripts.repair_seller_roles import repair
  >>> repair()
"""
from __future__ import annotations

from app import create_app, db
from app.models import User, UserRole, Role, Seller
from sqlalchemy import select, func


def repair(dry_run: bool = True) -> int:
    app = create_app()
    fixed = 0
    with app.app_context():
        seller_role = db.session.execute(
            select(Role).where(func.lower(Role.name) == "seller")
        ).scalar_one_or_none()
        if seller_role is None:
            seller_role = Role(name="seller")
            db.session.add(seller_role)
            db.session.flush()
            print(f"Created seller role id={seller_role.id}")

        sellers = db.session.execute(select(Seller)).scalars().all()
        for seller in sellers:
            existing = db.session.execute(
                select(UserRole).where(
                    UserRole.user_id == seller.user_id,
                    UserRole.role_id == seller_role.id,
                )
            ).scalar_one_or_none()
            if existing:
                continue
            user = db.session.get(User, seller.user_id)
            print(f"Add seller role for user_id={seller.user_id} email={user.email if user else '?'}")
            if not dry_run:
                db.session.add(UserRole(user_id=seller.user_id, role_id=seller_role.id))
            fixed += 1
        if not dry_run:
            db.session.commit()
    print(f"{'Would fix' if dry_run else 'Fixed'} {fixed} user(s). Pass dry_run=False to apply.")
    return fixed


if __name__ == "__main__":
    repair(dry_run=False)
