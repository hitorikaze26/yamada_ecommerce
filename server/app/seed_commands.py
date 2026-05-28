import click
from flask.cli import with_appcontext

from sqlalchemy import select

from .extensions import bcrypt
from .models import db, User, Role, RoleTypes, UserRole, ReportType, Category


# Keys are the role being REPORTED (target). (type_key, display_name, description, category)
REPORT_TYPES_SEED = {
    'buyer': [
        ('fake_orders', 'Fake Orders', 'Fraudulent or nonexistent orders placed', 'fraud'),
        ('payment_fraud', 'Payment Fraud', 'Suspicious payment activity or unauthorized charges', 'fraud'),
        ('harassment', 'Harassment', 'Abusive, threatening, or intimidating behavior', 'harassment'),
        ('inappropriate_language', 'Inappropriate Language', 'Use of offensive or profane language', 'inappropriate_content'),
        ('refund_abuse', 'Refund Abuse', 'Abusing the refund system', 'misconduct'),
        ('fake_reviews', 'Fake Reviews', 'Fabricated or misleading product reviews', 'fraud'),
        ('return_abuse', 'Return Abuse', 'Abusing the return policy', 'misconduct'),
        ('spam', 'Spam', 'Unsolicited or repetitive messages', 'spam'),
        ('off_platform_transactions', 'Off-Platform Transactions', 'Attempting transactions outside the platform', 'fraud'),
        ('threatening_behavior', 'Threatening Behavior', 'Direct threats or intimidation', 'harassment'),
    ],
    'seller': [
        ('fake_products', 'Fake Products', 'Counterfeit or non-existent products listed', 'fraud'),
        ('misleading_listings', 'Misleading Listings', 'Product descriptions that deceive buyers', 'fraud'),
        ('poor_product_quality', 'Poor Product Quality', 'Products not meeting reasonable quality standards', 'misconduct'),
        ('wrong_item_sent', 'Wrong Item Sent', 'Item received does not match the order', 'misconduct'),
        ('harassment', 'Harassment', 'Abusive or threatening behavior', 'harassment'),
        ('delayed_shipping', 'Delayed Shipping', 'Excessive delays in shipping orders', 'misconduct'),
        ('scam_activity', 'Scam Activity', 'Fraudulent or deceptive business practices', 'fraud'),
        ('inappropriate_products', 'Inappropriate Products', 'Listing prohibited or offensive items', 'inappropriate_content'),
        ('fake_discounts', 'Fake Discounts', 'Misleading or false discount claims', 'fraud'),
        ('spam_promotions', 'Spam Promotions', 'Excessive unsolicited promotional messages', 'spam'),
        ('refund_refusal_abuse', 'Refund Refusal Abuse', 'Unfairly refusing legitimate refund requests', 'misconduct'),
        ('off_platform_transactions', 'Off-Platform Transactions', 'Attempting sales outside the platform', 'fraud'),
        ('review_manipulation', 'Review Manipulation', 'Faking or coercing product reviews', 'misconduct'),
    ],
    'rider': [
        ('fake_delivery_completion', 'Fake Delivery Completion', 'Marking deliveries as completed without actual delivery', 'fraud'),
        ('package_tampering', 'Package Tampering', 'Interfering with or opening packages', 'safety'),
        ('harassment', 'Harassment', 'Abusive or threatening behavior toward customers', 'harassment'),
        ('delivery_delay_abuse', 'Delivery Delay Abuse', 'Excessive or intentional delivery delays', 'misconduct'),
        ('unprofessional_conduct', 'Unprofessional Conduct', 'Behavior not meeting professional standards', 'misconduct'),
        ('location_fraud', 'Location Fraud', 'Falsifying GPS or location data', 'fraud'),
        ('theft', 'Theft', 'Stealing packages or items', 'safety'),
        ('inappropriate_language', 'Inappropriate Language', 'Use of offensive or profane language', 'inappropriate_content'),
        ('delivery_cancellation_abuse', 'Delivery Cancellation Abuse', 'Abusing the cancellation system', 'misconduct'),
        ('dangerous_driving', 'Dangerous Driving', 'Reckless or unsafe driving behavior', 'safety'),
    ],
}


@click.command("seed-report-types")
@with_appcontext
def seed_report_types_command():
    """Seed the report_types table with all default report reasons."""
    count = 0
    updated = 0
    for target_role, types in REPORT_TYPES_SEED.items():
        for type_key, display_name, description, category in types:
            existing = db.session.execute(
                select(ReportType).where(
                    ReportType.target_role == target_role,
                    ReportType.type_key == type_key,
                )
            ).scalar_one_or_none()
            if existing is None:
                rt = ReportType(
                    target_role=target_role,
                    type_key=type_key,
                    display_name=display_name,
                    description=description,
                    category=category,
                    is_active=True,
                )
                db.session.add(rt)
                count += 1
            else:
                existing.display_name = display_name
                existing.description = description
                existing.category = category
                existing.target_role = target_role
                updated += 1
    db.session.commit()
    click.echo(f"Seeded {count} report types, updated {updated}.")


@click.command("seed-admin")
@with_appcontext
def seed_admin_command():
    """Create a fixed admin user if it doesn't already exist."""
    admin_email = "noeasumbra122602@gmail.com"
    admin_username = "Hitorikaze"
    admin_password = "admin123" 

    # Check if admin user already exists
    existing_user = db.session.execute(
        select(User).where(User.email == admin_email)
    ).scalar_one_or_none()

    # Ensure admin role exists
    admin_role = db.session.execute(
        select(Role).where(Role.id == RoleTypes.ADMIN.value)
    ).scalar_one_or_none()

    if admin_role is None:
        admin_role = Role(id=RoleTypes.ADMIN.value, name="admin")
        db.session.add(admin_role)
        db.session.commit()
        click.echo("Created ADMIN role.")

    # Hash password using the same bcrypt extension used by the app
    password_hash = bcrypt.generate_password_hash(admin_password).decode("utf-8")

    if existing_user:
        # Update existing admin user's password and username to ensure it matches
        existing_user.username = admin_username
        existing_user.password_hash = password_hash
        db.session.commit()

        # Ensure the user has the ADMIN role
        existing_user_role = db.session.execute(
            select(UserRole).where(
                UserRole.user_id == existing_user.id,
                UserRole.role_id == admin_role.id,
            )
        ).scalar_one_or_none()

        if existing_user_role is None:
            db.session.add(UserRole(user_id=existing_user.id, role_id=admin_role.id))
            db.session.commit()

        click.echo(f"Admin user already exists: {admin_email}")
        return

    admin_user = User(
        email=admin_email,
        username=admin_username,
        password_hash=password_hash,
        email_verified=True,
        active=True,
    )
    db.session.add(admin_user)
    db.session.flush()

    db.session.add(UserRole(user_id=admin_user.id, role_id=admin_role.id))
    db.session.commit()
    click.echo(f"Created admin user: {admin_email}")


DEFAULT_CATEGORIES = [
    ("dress-skirts", "Dresses and Skirts"),
    ("bottoms", "Bottoms"),
    ("tops-blouses", "tops and blouses"),
    ("activewear", "activewear and yoga pants"),
    ("lingerie-sleepwear", "lingerie and sleepwear"),
    ("jackets-coats", "jackets and coats"),
    ("accessories-shoes", "shoes and accessories"),
]


@click.command("seed-categories")
@with_appcontext
def seed_categories_command():
    """Seed the categories table with the default marketplace categories."""
    count = 0
    for slug, name in DEFAULT_CATEGORIES:
        existing = db.session.execute(
            select(Category).where(Category.name == name)
        ).scalar_one_or_none()
        if existing is None:
            db.session.add(Category(name=name))
            count += 1
    db.session.commit()
    click.echo(f"Seeded {count} categories.")


@click.command("geofill-stores")
@with_appcontext
def geofill_stores_command():
    """Geocode all stores that are missing latitude/longitude."""
    from app.models import Store
    from app.services.shipping_service import ShippingService

    stores = db.session.execute(
        select(Store).where(
            Store.latitude.is_(None) | Store.longitude.is_(None)
        )
    ).scalars().all()

    if not stores:
        click.echo("All stores already have coordinates.")
        return

    click.echo(f"Geocoding {len(stores)} stores without coordinates…")
    success = 0
    for store in stores:
        address = store.address or store.store_name
        coords = ShippingService.geocode_address(address)
        if coords:
            store.latitude = coords[0]
            store.longitude = coords[1]
            success += 1
            click.echo(f"  ✓ {store.store_name} → ({coords[0]:.4f}, {coords[1]:.4f})")
        else:
            click.echo(f"  ✗ {store.store_name} — could not geocode")
    db.session.commit()
    click.echo(f"Done. Updated {success}/{len(stores)} stores.")
