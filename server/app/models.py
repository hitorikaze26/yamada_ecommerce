import datetime
import enum
import json
from typing import List

from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import (
    DeclarativeBase,
    Mapped,
    registry,
    mapped_column,
    relationship
)
from sqlalchemy import (
    ForeignKey,
    DATETIME,
    String,
    BIGINT,
    TEXT,
    VARCHAR,
    Column,
    Table,
    Enum,
    select,
    Integer,
    Float,
    Boolean,
    Numeric,
    JSON,
    UniqueConstraint,
)
from dataclasses import dataclass
from flask_bcrypt import generate_password_hash, check_password_hash

class RoleTypes(enum.Enum):
    ADMIN=1
    BUYER=2
    SELLER=3
    RIDER=4

class StoreRequestStatus(enum.Enum):
    """Stored as name strings in PostgreSQL (VARCHAR) after migration db4976136a6f."""

    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    PENDING = "PENDING"

class OrderStatus(enum.Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"
    RETURNED = "returned"
    COMPLETED = "completed"


class PaymentStatus(enum.Enum):
    HELD = "held"
    SETTLED = "settled"
    REFUNDED = "refunded"
    FAILED = "failed"


class RefundStatus(enum.Enum):
    REQUESTED = "requested"
    APPROVED_BY_SELLER = "approved_by_seller"
    REJECTED_BY_SELLER = "rejected_by_seller"
    APPROVED = "approved"
    REJECTED = "rejected"
    DISPUTED = "disputed"
    EVIDENCE_REQUESTED = "evidence_requested"
    ADMIN_REVIEW = "admin_review"


class ProductModerationStatus(enum.Enum):
    ACTIVE = "active"
    UNDER_REVIEW = "under_review"
    HIDDEN = "hidden"
    REMOVED = "removed"
    RESTRICTED = "restricted"


def product_is_public(product: "Product") -> bool:
    """True when a product should appear on the public storefront."""
    status = getattr(product, "moderation_status", None)
    if status is None:
        return bool(getattr(product, "is_live", False))
    status_val = status.value if hasattr(status, "value") else str(status)
    return status_val == ProductModerationStatus.ACTIVE.value and bool(product.is_live)


def product_can_seller_edit(product: "Product") -> bool:
    status = getattr(product, "moderation_status", None)
    if status is None:
        return True
    status_val = status.value if hasattr(status, "value") else str(status)
    return status_val not in (
        ProductModerationStatus.REMOVED.value,
        ProductModerationStatus.RESTRICTED.value,
    )


def _enum_values(enum_cls: type[enum.Enum]) -> list[str]:
    """Map Python enums to DB string values (MySQL ENUM stores .value, not .name)."""
    return [member.value for member in enum_cls]


class DeliveryStatus(enum.Enum):
    PENDING = "pending"
    PICKUP = "pickup"
    TRANSIT = "transit"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class ReportStatus(enum.Enum):
    PENDING = "pending"
    UNDER_REVIEW = "under_review"
    INVESTIGATING = "investigating"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class PunishmentSeverity(enum.Enum):
    WARNING = "warning"
    RESTRICTION = "restriction"
    BAN = "ban"


class ProblemReportStatus(enum.Enum):
    PENDING = "pending"
    REVIEWED = "reviewed"
    RESOLVED = "resolved"


class ProblemReportCategory(enum.Enum):
    APP = "app"
    STORE = "store"
    RIDER = "rider"


mapper_registry = registry(
    type_annotation_map = {
        str: String()
        .with_variant(VARCHAR(255), "mysql"),
    }
)

class Base(DeclarativeBase):
    registry=mapper_registry

db=SQLAlchemy(model_class=Base)


def _user_avatar_path(user: "User") -> str | None:
    """Best-effort avatar path from rider, buyer, or seller profile."""
    for attr in ("rider_profile", "buyer_profile", "seller"):
        try:
            profile = getattr(user, attr, None)
            if profile is None:
                continue
            path = getattr(profile, "avatar_path", None)
            if path:
                return path
        except Exception:
            continue
    return None


@dataclass
class User(Base):
    __tablename__='user'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    email: Mapped[str] = mapped_column(unique=True)
    password_hash: Mapped[str]
    username: Mapped[str] = mapped_column(unique=True)
    given_name: Mapped[str] = mapped_column(nullable=True)
    surname: Mapped[str] = mapped_column(nullable=True)
    contact_number: Mapped[str] = mapped_column(nullable=True)
    active: Mapped[bool] = mapped_column(default=True)
    email_verified: Mapped[bool] = mapped_column(default=False)
    is_archived: Mapped[bool] = mapped_column(default=False)
    last_active_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    archived_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    roles: Mapped[List["UserRole"]] = relationship(back_populates='user', cascade='all, delete')
    buyer_profile: Mapped["BuyerProfile"] = relationship(back_populates='user', cascade='all, delete')
    rider_profile: Mapped["RiderProfile"] = relationship(back_populates='user', cascade='all, delete')
    seller: Mapped["Seller"] = relationship(back_populates='user', cascade='all, delete')
    registration: Mapped["StoreRegistration"] = relationship(back_populates='user', cascade='all, delete')
    store: Mapped["Store"] = relationship(back_populates='user', cascade='all, delete')

    def set_password(self, password):
        self.password_hash=generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def isActive(self):
        return self.active

    def isVerified(self):
        return self.email_verified

    def setActive(self, activation: bool):
        self.active = activation

    def setVerification(self, verification: bool):
        self.email_verified = verification

    def touch_activity(self):
        self.last_active_at = datetime.datetime.now()

    def restore_from_archive(self):
        """Reactivate a soft-archived account when the user signs in again."""
        if self.is_archived:
            self.is_archived = False
            self.archived_at = None
        self.touch_activity()

    def archive_account(self):
        self.is_archived = True
        self.archived_at = datetime.datetime.now()
        self.active = False

    def to_json(self):
        user_roles: list[str] = []
        for ur in self.roles:
            try:
                if ur.role and ur.role.name:
                    user_roles.append(ur.role.name.lower())
            except Exception:
                continue

        primary_role = user_roles[0] if user_roles else "unknown"

        buyer_profile_data = None
        try:
            if self.buyer_profile is not None:
                bp = self.buyer_profile
                buyer_profile_data = {
                    "region_code": bp.region_code,
                    "region_name": bp.region_name,
                    "province_code": bp.province_code,
                    "province_name": bp.province_name,
                    "municipality_code": bp.municipality_code,
                    "municipality_name": bp.municipality_name,
                    "barangay_code": bp.barangay_code,
                    "barangay_name": bp.barangay_name,
                    "street_address": bp.street_address,
                    "postal_code": bp.postal_code,
                    "avatar_path": bp.avatar_path,
                    "valid_id_path": bp.valid_id_path,
                }
        except Exception:
            pass

        payload = {
            "id": self.id,
            "email": self.email,
            "username": self.username,
            "givenName": self.given_name,
            "surname": self.surname,
            "contactNumber": self.contact_number,
            "active": self.active,
            "emailVerified": self.email_verified,
            "isArchived": self.is_archived,
            "lastActiveAt": self.last_active_at.isoformat() if self.last_active_at else None,
            "archivedAt": self.archived_at.isoformat() if self.archived_at else None,
            "role": primary_role,
            "user_role": user_roles,
            "avatar": _user_avatar_path(self),
            "buyerProfile": buyer_profile_data,
            "buyer_profile": buyer_profile_data,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "updatedAt": self.updated_at.isoformat() if self.updated_at else None,
            # Legacy keys used by admin UI
            "Username": self.username,
            "User email": self.email,
            "User active": self.active,
            "User verified": self.email_verified,
            "is_archived": self.is_archived,
            "last_active_at": self.last_active_at.isoformat() if self.last_active_at else None,
            "archived_at": self.archived_at.isoformat() if self.archived_at else None,
            "given_name": self.given_name,
            "surname": self.surname,
            "contact_number": self.contact_number,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        return payload


class Role(Base):
    __tablename__='role'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    name: Mapped[str] = mapped_column(unique=True)

    user_roles: Mapped[List["UserRole"]] = relationship(back_populates='role')

class UserRole(Base):
    __tablename__='user_roles'

    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'), primary_key=True)
    role_id: Mapped[int] = mapped_column(ForeignKey('role.id', ondelete='CASCADE'), primary_key=True)
    assigned_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship(back_populates='roles')
    role: Mapped["Role"] = relationship(back_populates='user_roles')


@dataclass
class BuyerProfile(Base):
    __tablename__='buyer_profiles'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'), unique=True)
    region_code: Mapped[str] = mapped_column(nullable=True)
    region_name: Mapped[str] = mapped_column(nullable=True)
    province_code: Mapped[str] = mapped_column(nullable=True)
    province_name: Mapped[str] = mapped_column(nullable=True)
    municipality_code: Mapped[str] = mapped_column(nullable=True)
    municipality_name: Mapped[str] = mapped_column(nullable=True)
    barangay_code: Mapped[str] = mapped_column(nullable=True)
    barangay_name: Mapped[str] = mapped_column(nullable=True)
    street_address: Mapped[str] = mapped_column(nullable=True)
    postal_code: Mapped[str] = mapped_column(nullable=True)
    avatar_path: Mapped[str] = mapped_column(nullable=True)
    valid_id_path: Mapped[str] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship(back_populates='buyer_profile')


@dataclass
class Seller(Base):
    __tablename__='seller_profiles'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'), unique=True)
    full_name: Mapped[str] = mapped_column(nullable=True)
    residential_address: Mapped[str] = mapped_column(nullable=True)
    personal_phone_number: Mapped[str] = mapped_column(nullable=True)
    country: Mapped[str] = mapped_column(nullable=True)
    province: Mapped[str] = mapped_column(nullable=True)
    city: Mapped[str] = mapped_column(nullable=True)
    region_code: Mapped[str] = mapped_column(nullable=True)
    region_name: Mapped[str] = mapped_column(nullable=True)
    province_code: Mapped[str] = mapped_column(nullable=True)
    province_name: Mapped[str] = mapped_column(nullable=True)
    municipality_code: Mapped[str] = mapped_column(nullable=True)
    municipality_name: Mapped[str] = mapped_column(nullable=True)
    barangay_code: Mapped[str] = mapped_column(nullable=True)
    barangay_name: Mapped[str] = mapped_column(nullable=True)
    street_address: Mapped[str] = mapped_column(nullable=True)
    postal_code: Mapped[str] = mapped_column(nullable=True)
    avatar_path: Mapped[str] = mapped_column(nullable=True)
    banner_path: Mapped[str] = mapped_column(nullable=True)
    valid_id_path: Mapped[str] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship(back_populates='seller')
    registration: Mapped["StoreRegistration"] = relationship(back_populates='seller', cascade='all, delete')
    store: Mapped["Store"] = relationship(back_populates='seller', cascade='all, delete')
    wallet: Mapped["SellerWallet"] = relationship(back_populates='seller', cascade='all, delete')


@dataclass
class RiderProfile(Base):
    __tablename__='rider_profiles'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'), unique=True)
    region_code: Mapped[str] = mapped_column(nullable=True)
    region_name: Mapped[str] = mapped_column(nullable=True)
    province_code: Mapped[str] = mapped_column(nullable=True)
    province_name: Mapped[str] = mapped_column(nullable=True)
    municipality_code: Mapped[str] = mapped_column(nullable=True)
    municipality_name: Mapped[str] = mapped_column(nullable=True)
    barangay_code: Mapped[str] = mapped_column(nullable=True)
    barangay_name: Mapped[str] = mapped_column(nullable=True)
    street_address: Mapped[str] = mapped_column(nullable=True)
    postal_code: Mapped[str] = mapped_column(nullable=True)
    vehicle_type: Mapped[str] = mapped_column(nullable=True)
    license_number: Mapped[str] = mapped_column(nullable=True)
    license_path: Mapped[str] = mapped_column(nullable=True)
    orcr_path: Mapped[str] = mapped_column(nullable=True)
    avatar_path: Mapped[str] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship(back_populates='rider_profile')


@dataclass
class StoreRegistration(Base):
    __tablename__='store_registrations'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    seller_id: Mapped[int] = mapped_column(ForeignKey('seller_profiles.id', ondelete='CASCADE'), nullable=True)
    request_status: Mapped[StoreRequestStatus] = mapped_column(
        Enum(StoreRequestStatus, values_callable=_enum_values),
        default=StoreRequestStatus.PENDING,
    )
    store_purpose: Mapped[str] = mapped_column(nullable=True)
    shop_name: Mapped[str] = mapped_column(nullable=True)
    tagline: Mapped[str] = mapped_column(nullable=True)
    categories_json: Mapped[str] = mapped_column(nullable=True)
    dti_path: Mapped[str] = mapped_column(nullable=True)
    bir_tin_path: Mapped[str] = mapped_column(nullable=True)
    business_permit_path: Mapped[str] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship(back_populates='registration')
    seller: Mapped["Seller"] = relationship(back_populates='registration')

    def acceptStoreRegistration(self):
        self.request_status = StoreRequestStatus.ACCEPTED

    def rejectStoreRegistration(self):
        self.request_status = StoreRequestStatus.REJECTED

    def to_json(self):
        """Serialize for admin shop verification UI (legacy key names)."""
        seller = self.seller
        user = self.user
        status = self.request_status.name if self.request_status else "PENDING"
        return {
            "id": self.id,
            "user_id": self.user_id,
            "seller_id": self.seller_id,
            "Store name": self.shop_name or "",
            "Store purpose": self.store_purpose or "",
            "Store tagline": self.tagline or "",
            "Categories json": self.categories_json or "",
            "DTI path": self.dti_path,
            "BIR TIN path": self.bir_tin_path,
            "Business permit path": self.business_permit_path,
            "Request status": status,
            "Request date created": self.created_at.isoformat() if self.created_at else None,
            "Seller full name": seller.full_name if seller else "",
            "Seller email": user.email if user else "",
            "Seller street address": seller.street_address if seller else "",
            "Seller barangay": seller.barangay_name if seller else "",
            "Seller municipality": seller.municipality_name if seller else "",
            "Seller province": seller.province_name if seller else "",
            "Seller region": seller.region_name if seller else "",
        }


@dataclass
class Store(Base):
    __tablename__='stores'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'), unique=True)
    seller_id: Mapped[int] = mapped_column(ForeignKey('seller_profiles.id', ondelete='CASCADE'), unique=True)
    store_name: Mapped[str] = mapped_column(unique=True)
    store_email: Mapped[str] = mapped_column(nullable=True)
    description: Mapped[str] = mapped_column(TEXT, nullable=True)
    country: Mapped[str] = mapped_column(nullable=True)
    address: Mapped[str] = mapped_column(nullable=True)
    store_phone_number: Mapped[str] = mapped_column(nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=True)
    longitude: Mapped[float] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship(back_populates='store')
    seller: Mapped["Seller"] = relationship(back_populates='store')
    products: Mapped[List["Product"]] = relationship(back_populates='store', cascade='all, delete')

    def isAccepted(self):
        return True


@dataclass
class Product(Base):
    __tablename__='products'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'))
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(TEXT, nullable=True)
    price: Mapped[float] = mapped_column(Float, default=0)
    cost_price: Mapped[float] = mapped_column(Float, nullable=True)
    sale_price: Mapped[float] = mapped_column(Float, nullable=True)
    quantity: Mapped[int] = mapped_column(Integer, default=0)
    low_stock_threshold: Mapped[int] = mapped_column(Integer, nullable=True)
    image_url: Mapped[str] = mapped_column(nullable=True)
    is_live: Mapped[bool] = mapped_column(Boolean, default=True)
    moderation_status: Mapped[ProductModerationStatus] = mapped_column(
        Enum(ProductModerationStatus, values_callable=_enum_values),
        default=ProductModerationStatus.ACTIVE,
    )
    moderation_reason: Mapped[str] = mapped_column(TEXT, nullable=True)
    moderation_updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    moderation_updated_by: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="SET NULL"), nullable=True
    )
    edit_requested_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    edit_request_note: Mapped[str] = mapped_column(TEXT, nullable=True)
    rating: Mapped[float] = mapped_column(Float, default=0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    subcategory: Mapped[str] = mapped_column(String(100), nullable=True)
    brand: Mapped[str] = mapped_column(String(100), nullable=True)
    tags_json: Mapped[str] = mapped_column(TEXT, nullable=True)
    product_condition: Mapped[str] = mapped_column(String(50), nullable=True)
    weight_kg: Mapped[float] = mapped_column(Float, nullable=True)
    material: Mapped[str] = mapped_column(String(100), nullable=True)
    size_chart_json: Mapped[str] = mapped_column(TEXT, nullable=True)
    care_instructions: Mapped[str] = mapped_column(TEXT, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    store: Mapped["Store"] = relationship(back_populates='products')
    categories: Mapped[List["ProductCategory"]] = relationship(back_populates='product', cascade='all, delete')
    variations: Mapped[List["ProductVariation"]] = relationship(back_populates='product', cascade='all, delete')
    reviews: Mapped[List["Review"]] = relationship(back_populates='product', cascade='all, delete')
    media: Mapped[List["ProductMedia"]] = relationship(back_populates='product', cascade='all, delete')
    cart_items: Mapped[List["CartItem"]] = relationship(back_populates='product')
    order_items: Mapped[List["OrderItem"]] = relationship(back_populates='product')

    def to_json(self):
        images = []
        if self.image_url:
            images.append(self.image_url)

        tags = []
        if self.tags_json:
            try:
                parsed = json.loads(self.tags_json) if isinstance(self.tags_json, str) else self.tags_json
                if isinstance(parsed, list):
                    tags = parsed
            except Exception:
                pass

        size_chart = None
        if self.size_chart_json:
            try:
                size_chart = json.loads(self.size_chart_json) if isinstance(self.size_chart_json, str) else self.size_chart_json
            except Exception:
                pass

        return {
            'id': self.id,
            'storeId': self.store_id,
            'name': self.name,
            'description': self.description,
            'price': self.price,
            'costPrice': self.cost_price,
            'salePrice': self.sale_price,
            'quantity': self.quantity,
            'lowStockThreshold': self.low_stock_threshold,
            'images': images,
            'isLive': self.is_live,
            'moderationStatus': (
                self.moderation_status.value
                if hasattr(self.moderation_status, 'value')
                else str(self.moderation_status or 'active')
            ),
            'moderationReason': self.moderation_reason,
            'editRequestedAt': self.edit_requested_at.isoformat() if self.edit_requested_at else None,
            'editRequestNote': self.edit_request_note,
            'canEdit': product_can_seller_edit(self),
            'isPublic': product_is_public(self),
            'rating': self.rating,
            'reviewCount': self.review_count,
            'subcategory': self.subcategory,
            'brand': self.brand,
            'tags': tags,
            'condition': self.product_condition,
            'weightKg': self.weight_kg,
            'material': self.material,
            'sizeChart': size_chart,
            'careInstructions': self.care_instructions,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class ProductModerationLog(Base):
    __tablename__ = "product_moderation_logs"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"))
    admin_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    note: Mapped[str] = mapped_column(TEXT, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    product: Mapped["Product"] = relationship()
    admin: Mapped["User"] = relationship(foreign_keys=[admin_id])


class ProductCategory(Base):
    __tablename__='product_categories'

    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='CASCADE'), primary_key=True)
    category_id: Mapped[int] = mapped_column(ForeignKey('categories.id', ondelete='CASCADE'), primary_key=True)

    product: Mapped["Product"] = relationship(back_populates='categories', cascade='all, delete')
    category: Mapped["Category"] = relationship()


@dataclass
class ProductVariation(Base):
    __tablename__ = 'product_variations'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='CASCADE'))
    size: Mapped[str] = mapped_column(nullable=True)
    color: Mapped[str] = mapped_column(nullable=True)
    sku: Mapped[str] = mapped_column(nullable=True)
    price: Mapped[float] = mapped_column(Float, nullable=True)
    inventory: Mapped[int] = mapped_column(Integer, nullable=True)

    product: Mapped["Product"] = relationship(back_populates='variations')


@dataclass
class ProductMedia(Base):
    __tablename__ = 'product_media'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='CASCADE'))
    media_type: Mapped[str] = mapped_column(String(20), default='image')
    path: Mapped[str] = mapped_column(String(500), nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    product: Mapped["Product"] = relationship(back_populates='media')


@dataclass
class SellerWallet(Base):
    __tablename__ = 'seller_wallets'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    seller_id: Mapped[int] = mapped_column(ForeignKey('seller_profiles.id', ondelete='CASCADE'), unique=True)
    balance: Mapped[float] = mapped_column(Float, default=0.0)
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    seller: Mapped["Seller"] = relationship(back_populates='wallet')


@dataclass
class RiderDelivery(Base):
    __tablename__ = 'rider_deliveries'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey('orders.id', ondelete='SET NULL'), nullable=True)
    rider_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    status: Mapped[DeliveryStatus] = mapped_column(Enum(DeliveryStatus), default=DeliveryStatus.PENDING)
    fee: Mapped[float] = mapped_column(Float, default=0.0)
    distance_km: Mapped[float] = mapped_column(Float, nullable=True)
    proof_photo_path: Mapped[str] = mapped_column(nullable=True)
    proof_note: Mapped[str] = mapped_column(TEXT, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    order: Mapped["Order"] = relationship(back_populates='deliveries')
    rider: Mapped["User"] = relationship(foreign_keys=[rider_id])


@dataclass
class WishlistItem(Base):
    __tablename__ = 'wishlist_items'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='CASCADE'))
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    product: Mapped["Product"] = relationship()
    user: Mapped["User"] = relationship()


@dataclass
class StoreFollow(Base):
    __tablename__ = 'store_follows'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'))
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())


@dataclass
class RecentlyViewedProduct(Base):
    __tablename__ = 'recently_viewed_products'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='CASCADE'))
    viewed_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())


@dataclass
class Coupon(Base):
    __tablename__ = 'coupons'
    __table_args__ = (
        UniqueConstraint('code', 'store_id', name='uq_coupon_code_store'),
    )

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(TEXT, nullable=True)
    discount_type: Mapped[str] = mapped_column(String(20), default='percent')  # percent | fixed
    discount_value: Mapped[float] = mapped_column(Float, nullable=False)
    min_order_amount: Mapped[float] = mapped_column(Float, default=0.0)
    max_uses: Mapped[int] = mapped_column(Integer, nullable=True)
    used_count: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    scope: Mapped[str] = mapped_column(String(20), default='platform')
    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    store: Mapped["Store"] = relationship()


@dataclass
class CouponRedemption(Base):
    __tablename__ = 'coupon_redemptions'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    coupon_id: Mapped[int] = mapped_column(ForeignKey('coupons.id', ondelete='CASCADE'))
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    order_id: Mapped[int] = mapped_column(ForeignKey('orders.id', ondelete='SET NULL'), nullable=True)
    redeemed_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    coupon: Mapped["Coupon"] = relationship()
    user: Mapped["User"] = relationship()
    order: Mapped["Order"] = relationship()


@dataclass
class ReportType(Base):
    __tablename__ = 'report_types'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    # Role of the user being reported (buyer / seller / rider), not who filed the report.
    target_role: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    type_key: Mapped[str] = mapped_column(String(50), nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(TEXT, nullable=True)
    category: Mapped[str] = mapped_column(String(50), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())


@dataclass
class ProblemReport(Base):
    __tablename__ = 'problem_reports'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    reporter_user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    reporter_role: Mapped[str] = mapped_column(String(20), nullable=False)
    report_type_id: Mapped[int] = mapped_column(ForeignKey('report_types.id', ondelete='SET NULL'), nullable=True)
    description: Mapped[str] = mapped_column(TEXT, nullable=False)
    status: Mapped[ReportStatus] = mapped_column(Enum(ReportStatus), default=ReportStatus.PENDING)
    priority: Mapped[str] = mapped_column(String(20), default='medium')
    target_user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    target_role: Mapped[str] = mapped_column(String(20), nullable=True)
    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='SET NULL'), nullable=True)
    order_id: Mapped[int] = mapped_column(ForeignKey('orders.id', ondelete='SET NULL'), nullable=True)
    admin_notes: Mapped[str] = mapped_column(TEXT, nullable=True)
    resolved_by: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())
    resolved_at: Mapped[datetime.datetime] = mapped_column(nullable=True)

    reporter: Mapped["User"] = relationship(foreign_keys=[reporter_user_id])
    target_user: Mapped["User"] = relationship(foreign_keys=[target_user_id])
    resolver: Mapped["User"] = relationship(foreign_keys=[resolved_by])
    report_type: Mapped["ReportType"] = relationship()
    evidence: Mapped[List["ReportEvidence"]] = relationship(back_populates='report', cascade='all, delete')
    punishments: Mapped[List["Punishment"]] = relationship(back_populates='report', cascade='all, delete')


@dataclass
class ReportEvidence(Base):
    __tablename__ = 'report_evidence'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    report_id: Mapped[int] = mapped_column(ForeignKey('problem_reports.id', ondelete='CASCADE'))
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_type: Mapped[str] = mapped_column(String(50), default='image')
    original_filename: Mapped[str] = mapped_column(String(255), nullable=True)
    uploaded_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    report: Mapped["ProblemReport"] = relationship(back_populates='evidence')


@dataclass
class Punishment(Base):
    __tablename__ = 'punishments'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    report_id: Mapped[int] = mapped_column(ForeignKey('problem_reports.id', ondelete='SET NULL'), nullable=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    severity: Mapped[PunishmentSeverity] = mapped_column(Enum(PunishmentSeverity))
    restriction_type: Mapped[str] = mapped_column(String(100), nullable=True)
    reason: Mapped[str] = mapped_column(TEXT, nullable=False)
    issued_by: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    start_date: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    end_date: Mapped[datetime.datetime] = mapped_column(nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    report: Mapped["ProblemReport"] = relationship(back_populates='punishments')
    user: Mapped["User"] = relationship(foreign_keys=[user_id])
    issuer: Mapped["User"] = relationship(foreign_keys=[issued_by])


@dataclass
class ViolationHistory(Base):
    __tablename__ = 'violation_history'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    report_id: Mapped[int] = mapped_column(ForeignKey('problem_reports.id', ondelete='SET NULL'), nullable=True)
    punishment_id: Mapped[int] = mapped_column(ForeignKey('punishments.id', ondelete='SET NULL'), nullable=True)
    violation_type: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[str] = mapped_column(TEXT, nullable=True)
    issued_by: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())


@dataclass
class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))

    title: Mapped[str]
    body: Mapped[str] = mapped_column(TEXT)

    # Optional role context: buyer, seller, rider, admin
    role: Mapped[str] = mapped_column(nullable=True)

    # Optional page/context key for client-side filtering (e.g. "orders", "dashboard")
    page: Mapped[str] = mapped_column(nullable=True)

    created_at: Mapped[datetime.datetime] = mapped_column(
        default=lambda: datetime.datetime.now()
    )
    read: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped["User"] = relationship()


class Category(Base):
    __tablename__='categories'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    name: Mapped[str]

@dataclass
class Order(Base):
    __tablename__ = 'orders'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.PENDING)
    total_amount: Mapped[float] = mapped_column(Float, default=0.0)  # Product subtotal only
    shipping_fee: Mapped[float] = mapped_column(Float, default=0.0)  # Separate shipping fee
    admin_commission: Mapped[float] = mapped_column(Float, default=0.0)  # 10% of product price
    payment_method: Mapped[str] = mapped_column(nullable=True)
    shipping_address: Mapped[str] = mapped_column(TEXT, nullable=True)
    delivery_notes: Mapped[str] = mapped_column(TEXT, nullable=True)
    coupon_id: Mapped[int] = mapped_column(ForeignKey('coupons.id', ondelete='SET NULL'), nullable=True)
    coupon_discount: Mapped[float] = mapped_column(Float, default=0.0)
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True, unique=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    buyer_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='SET NULL'), nullable=True)
    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='SET NULL'), nullable=True)

    buyer: Mapped["User"] = relationship()
    store: Mapped["Store"] = relationship()
    items: Mapped[List["OrderItem"]] = relationship(back_populates='order', cascade='all, delete')
    deliveries: Mapped[List["RiderDelivery"]] = relationship(back_populates='order', cascade='all, delete')

    @property
    def grand_total(self) -> float:
        """Total amount including shipping fee (product price + shipping)."""
        return float(self.total_amount or 0.0) + float(self.shipping_fee or 0.0)


@dataclass
class PaymentTransaction(Base):
    __tablename__ = 'payment_transactions'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    amount: Mapped[float] = mapped_column(Float, default=0.0)
    platform_fee: Mapped[float] = mapped_column(Float, default=0.0)
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus, values_callable=_enum_values), default=PaymentStatus.HELD)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    order_id: Mapped[int] = mapped_column(ForeignKey('orders.id', ondelete='CASCADE'))
    seller_id: Mapped[int] = mapped_column(
        ForeignKey('seller_profiles.id', ondelete='SET NULL'),
        nullable=True,
    )

    order: Mapped["Order"] = relationship()
    seller: Mapped["Seller"] = relationship()


@dataclass
class RefundRequest(Base):
    __tablename__ = "refund_requests"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    reason: Mapped[str] = mapped_column(TEXT, nullable=True)
    status: Mapped[RefundStatus] = mapped_column(
        Enum(RefundStatus, values_callable=_enum_values),
        default=RefundStatus.REQUESTED,
    )
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"))
    buyer_id: Mapped[int] = mapped_column(ForeignKey("user.id", ondelete="SET NULL"), nullable=True)
    seller_id: Mapped[int] = mapped_column(ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True)
    payment_transaction_id: Mapped[int] = mapped_column(
        ForeignKey("payment_transactions.id", ondelete="SET NULL"),
        nullable=True,
    )
    buyer_evidence_note: Mapped[str] = mapped_column(TEXT, nullable=True)
    seller_response_note: Mapped[str] = mapped_column(TEXT, nullable=True)
    admin_note: Mapped[str] = mapped_column(TEXT, nullable=True)
    evidence_paths_json: Mapped[str] = mapped_column(TEXT, nullable=True)
    disputed_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    evidence_requested_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    frozen_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    is_transaction_frozen: Mapped[bool] = mapped_column(Boolean, default=False)

    order: Mapped["Order"] = relationship()
    buyer: Mapped["User"] = relationship()
    seller: Mapped["Seller"] = relationship()
    payment_transaction: Mapped["PaymentTransaction"] = relationship()


@dataclass
class OrderItem(Base):
    __tablename__ = 'order_items'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey('orders.id', ondelete='CASCADE'))
    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='SET NULL'), nullable=True)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[float] = mapped_column(Float, default=0.0)
    discount_amount: Mapped[float] = mapped_column(Float, default=0.0, nullable=True)
    variation: Mapped[str] = mapped_column(TEXT, nullable=True)

    order: Mapped["Order"] = relationship(back_populates='items')
    product: Mapped["Product"] = relationship()


class ReviewVisibility:
    VISIBLE = "visible"
    HIDDEN = "hidden"
    ARCHIVED = "archived"


@dataclass
class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    rating: Mapped[int] = mapped_column(Integer, default=5)
    review_format: Mapped[str] = mapped_column(String(32), default="default", nullable=False)
    ratings_json: Mapped[str] = mapped_column(TEXT, nullable=True)
    delivery_satisfaction: Mapped[int] = mapped_column(Integer, nullable=True)
    delivery_pills_json: Mapped[str] = mapped_column(TEXT, nullable=True)
    comment: Mapped[str] = mapped_column(TEXT, nullable=True)
    images_json: Mapped[str] = mapped_column(TEXT, nullable=True)
    seller_reply: Mapped[str] = mapped_column(TEXT, nullable=True)
    seller_reply_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    visibility: Mapped[str] = mapped_column(
        String(20), default=ReviewVisibility.VISIBLE, nullable=False
    )
    deleted_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    order_item_id: Mapped[int] = mapped_column(
        ForeignKey('order_items.id', ondelete='CASCADE'), unique=True
    )
    buyer_id: Mapped[int] = mapped_column(
        ForeignKey('user.id', ondelete='SET NULL'), nullable=True
    )
    product_id: Mapped[int] = mapped_column(
        ForeignKey('products.id', ondelete='SET NULL'), nullable=True
    )

    order_item: Mapped["OrderItem"] = relationship()
    buyer: Mapped["User"] = relationship()
    product: Mapped["Product"] = relationship()


# =============================================================================
# SHOP SETTINGS MODELS
# =============================================================================

@dataclass
class ShippingSettings(Base):
    """Shipping fees per location (region/province/city) with standardized rates."""
    __tablename__ = 'shipping_settings'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    region_code: Mapped[str] = mapped_column(nullable=True)
    region_name: Mapped[str]
    province_code: Mapped[str] = mapped_column(nullable=True)
    province_name: Mapped[str]
    city_code: Mapped[str] = mapped_column(nullable=True)
    city_name: Mapped[str]
    shipping_fee: Mapped[float] = mapped_column(default=0.0)
    is_active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'))
    store: Mapped["Store"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'regionCode': self.region_code,
            'regionName': self.region_name,
            'provinceCode': self.province_code,
            'provinceName': self.province_name,
            'cityCode': self.city_code,
            'cityName': self.city_name,
            'shippingFee': self.shipping_fee,
            'isActive': self.is_active,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class CommissionSettings(Base):
    """Admin commission settings."""
    __tablename__ = 'commission_settings'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    commission_rate: Mapped[float] = mapped_column(default=0.10)  # 10% default
    applies_to_product_price_only: Mapped[bool] = mapped_column(default=True)
    is_active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    def to_json(self):
        return {
            'id': self.id,
            'commissionRate': self.commission_rate,
            'appliesToProductPriceOnly': self.applies_to_product_price_only,
            'isActive': self.is_active,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class RiderEarnings(Base):
    """Rider earnings and fee distribution tracking."""
    __tablename__ = 'rider_earnings'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    delivery_id: Mapped[int] = mapped_column(ForeignKey('rider_deliveries.id', ondelete='CASCADE'))
    rider_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    shipping_fee_total: Mapped[float] = mapped_column(default=0.0)
    rider_share_percentage: Mapped[float] = mapped_column(default=0.80)  # 80% to rider
    admin_share_percentage: Mapped[float] = mapped_column(default=0.10)  # 10% to admin
    seller_share_percentage: Mapped[float] = mapped_column(default=0.10)  # 10% to seller
    rider_earnings: Mapped[float] = mapped_column(default=0.0)
    admin_earnings: Mapped[float] = mapped_column(default=0.0)
    seller_earnings: Mapped[float] = mapped_column(default=0.0)
    is_paid: Mapped[bool] = mapped_column(default=False)
    paid_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    delivery: Mapped["RiderDelivery"] = relationship()
    rider: Mapped["User"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'deliveryId': self.delivery_id,
            'riderId': self.rider_id,
            'shippingFeeTotal': self.shipping_fee_total,
            'riderSharePercentage': self.rider_share_percentage,
            'adminSharePercentage': self.admin_share_percentage,
            'sellerSharePercentage': self.seller_share_percentage,
            'riderEarnings': self.rider_earnings,
            'adminEarnings': self.admin_earnings,
            'sellerEarnings': self.seller_earnings,
            'isPaid': self.is_paid,
            'paidAt': self.paid_at.isoformat() if self.paid_at else None,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class PaymentSettings(Base):
    """Payment method settings (COD toggle)."""
    __tablename__ = 'payment_settings'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    cod_enabled: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'), unique=True)
    store: Mapped["Store"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'codEnabled': self.cod_enabled,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class OrderSettings(Base):
    """Order cancellation and return/refund settings."""
    __tablename__ = 'order_settings'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    allow_cancellation: Mapped[bool] = mapped_column(default=True)
    max_cancellation_hours: Mapped[int] = mapped_column(default=24)
    allow_returns: Mapped[bool] = mapped_column(default=True)
    return_period_days: Mapped[int] = mapped_column(default=7)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'), unique=True)
    store: Mapped["Store"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'allowCancellation': self.allow_cancellation,
            'maxCancellationHours': self.max_cancellation_hours,
            'allowReturns': self.allow_returns,
            'returnPeriodDays': self.return_period_days,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class ShopCustomization(Base):
    """Shop visual customization (colors, theme, announcement)."""
    __tablename__ = 'shop_customization'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    announcement: Mapped[str] = mapped_column(TEXT, nullable=True)
    primary_color: Mapped[str] = mapped_column(default='#3b82f6')
    theme_mode: Mapped[str] = mapped_column(default='light')
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'), unique=True)
    store: Mapped["Store"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'announcement': self.announcement,
            'primaryColor': self.primary_color,
            'themeMode': self.theme_mode,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class ChatSettings(Base):
    """Auto-reply chat settings."""
    __tablename__ = 'chat_settings'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    auto_reply_enabled: Mapped[bool] = mapped_column(default=False)
    auto_reply_message: Mapped[str] = mapped_column(TEXT, default='Thank you for your message! We will get back to you shortly.')
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(
        nullable=True,
        onupdate=lambda: datetime.datetime.now(),
    )

    store_id: Mapped[int] = mapped_column(ForeignKey('stores.id', ondelete='CASCADE'), unique=True)
    store: Mapped["Store"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'autoReplyEnabled': self.auto_reply_enabled,
            'autoReplyMessage': self.auto_reply_message,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


class ConversationKind(enum.Enum):
    BUYER_SELLER = "buyer_seller"
    SELLER_ADMIN = "seller_admin"
    ADMIN_BUYER = "admin_buyer"
    RIDER_SELLER = "rider_seller"


class ChatMessageType(enum.Enum):
    TEXT = "text"
    IMAGE = "image"
    FILE = "file"
    PRODUCT = "product"
    ORDER = "order"
    SYSTEM = "system"


@dataclass
class Conversation(Base):
    """Chat thread between marketplace participants."""
    __tablename__ = "conversations"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    kind: Mapped[ConversationKind] = mapped_column(
        Enum(ConversationKind, values_callable=_enum_values),
        nullable=False,
    )
    store_id: Mapped[int] = mapped_column(
        ForeignKey("stores.id", ondelete="SET NULL"), nullable=True
    )
    order_id: Mapped[int] = mapped_column(
        ForeignKey("orders.id", ondelete="SET NULL"), nullable=True
    )
    buyer_user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="SET NULL"), nullable=True
    )
    last_message_at: Mapped[datetime.datetime] = mapped_column(
        default=lambda: datetime.datetime.now()
    )
    last_message_preview: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime.datetime] = mapped_column(
        default=lambda: datetime.datetime.now()
    )

    store: Mapped["Store"] = relationship()
    order: Mapped["Order"] = relationship()
    participants: Mapped[List["ConversationParticipant"]] = relationship(
        back_populates="conversation", cascade="all, delete-orphan"
    )
    messages: Mapped[List["ChatMessage"]] = relationship(
        back_populates="conversation", cascade="all, delete-orphan"
    )


@dataclass
class ConversationParticipant(Base):
    __tablename__ = "conversation_participants"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"), nullable=False
    )
    participant_role: Mapped[str] = mapped_column(String(32), nullable=False)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    last_read_at: Mapped[datetime.datetime] = mapped_column(nullable=True)
    unread_count: Mapped[int] = mapped_column(Integer, default=0)

    conversation: Mapped["Conversation"] = relationship(back_populates="participants")
    user: Mapped["User"] = relationship()


@dataclass
class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    sender_user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="SET NULL"), nullable=True
    )
    body: Mapped[str] = mapped_column(TEXT, default="")
    message_type: Mapped[ChatMessageType] = mapped_column(
        Enum(ChatMessageType, values_callable=_enum_values),
        default=ChatMessageType.TEXT,
    )
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(
        default=lambda: datetime.datetime.now()
    )

    conversation: Mapped["Conversation"] = relationship(back_populates="messages")
    sender: Mapped["User"] = relationship()


@dataclass
class UserPresence(Base):
    __tablename__ = "user_presence"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("user.id", ondelete="CASCADE"), primary_key=True
    )
    last_seen_at: Mapped[datetime.datetime] = mapped_column(
        default=lambda: datetime.datetime.now()
    )
    is_online: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped["User"] = relationship()


class UserAddress(Base):
    """User delivery addresses with coordinates"""
    __tablename__ = 'user_addresses'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'))
    label: Mapped[str] = mapped_column(String(100), default='Address')
    street_address: Mapped[str] = mapped_column(String(500), nullable=False)
    barangay_name: Mapped[str] = mapped_column(String(100), nullable=True)
    municipality_name: Mapped[str] = mapped_column(String(100), nullable=False)
    province_name: Mapped[str] = mapped_column(String(100), nullable=False)
    region_name: Mapped[str] = mapped_column(String(100), nullable=False)
    postal_code: Mapped[str] = mapped_column(String(20), nullable=True)
    region_code: Mapped[str] = mapped_column(String(20), nullable=True)
    province_code: Mapped[str] = mapped_column(String(20), nullable=True)
    municipality_code: Mapped[str] = mapped_column(String(20), nullable=True)
    barangay_code: Mapped[str] = mapped_column(String(20), nullable=True)
    latitude: Mapped[float] = mapped_column(Numeric(10, 8), nullable=True, default=0.0)
    longitude: Mapped[float] = mapped_column(Numeric(11, 8), nullable=True, default=0.0)
    is_default: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship()

    def to_json(self):
        return {
            'id': self.id,
            'userId': self.user_id,
            'label': self.label,
            'streetAddress': self.street_address,
            'barangayName': self.barangay_name,
            'municipalityName': self.municipality_name,
            'provinceName': self.province_name,
            'regionName': self.region_name,
            'postalCode': self.postal_code,
            'regionCode': self.region_code,
            'provinceCode': self.province_code,
            'municipalityCode': self.municipality_code,
            'barangayCode': self.barangay_code,
            'latitude': float(self.latitude) if self.latitude else None,
            'longitude': float(self.longitude) if self.longitude else None,
            'isDefault': self.is_default,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
        }


class DistanceCache(Base):
    """Cache for calculated distances between coordinates"""
    __tablename__ = 'distance_cache'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    origin_lat: Mapped[float] = mapped_column(Numeric(10, 8), nullable=False)
    origin_lng: Mapped[float] = mapped_column(Numeric(11, 8), nullable=False)
    dest_lat: Mapped[float] = mapped_column(Numeric(10, 8), nullable=False)
    dest_lng: Mapped[float] = mapped_column(Numeric(11, 8), nullable=False)
    distance_km: Mapped[float] = mapped_column(Numeric(8, 3), nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())

    def to_json(self):
        return {
            'id': self.id,
            'originLat': float(self.origin_lat),
            'originLng': float(self.origin_lng),
            'destLat': float(self.dest_lat),
            'destLng': float(self.dest_lng),
            'distanceKm': float(self.distance_km),
            'createdAt': self.created_at.isoformat() if self.created_at else None,
        }


@dataclass
class Cart(Base):
    """Shopping cart for users"""
    __tablename__ = 'carts'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('user.id', ondelete='CASCADE'), unique=True)
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    user: Mapped["User"] = relationship()
    items: Mapped[List["CartItem"]] = relationship(back_populates="cart", cascade='all, delete')

    def to_json(self):
        return {
            'id': self.id,
            'userId': self.user_id,
            'items': [item.to_json() for item in self.items],
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class CartItem(Base):
    """Individual items in a shopping cart"""
    __tablename__ = 'cart_items'

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    cart_id: Mapped[int] = mapped_column(ForeignKey('carts.id', ondelete='CASCADE'))
    product_id: Mapped[int] = mapped_column(ForeignKey('products.id', ondelete='CASCADE'))
    variation_id: Mapped[int] = mapped_column(ForeignKey('product_variations.id', ondelete='CASCADE'))
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    price_at_add: Mapped[float] = mapped_column(Float, nullable=True)  # Price when added to cart
    created_at: Mapped[datetime.datetime] = mapped_column(default=lambda: datetime.datetime.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(nullable=True, onupdate=lambda: datetime.datetime.now())

    cart: Mapped["Cart"] = relationship(back_populates="items")
    product: Mapped["Product"] = relationship()
    variation: Mapped["ProductVariation"] = relationship()

    def to_json(self):
        # Return raw paths — URL resolution happens at route level
        image_url = self.product.image_url if self.product else None

        images = []
        if self.product and self.product.media:
            for media in self.product.media:
                images.append(media.path)

        # If no media images but has image_url, use that
        if not images and image_url:
            images = [image_url]

        # Store id + display name for buyer UI (cart grouping, store profile links)
        seller_id = None
        seller_name = 'Unknown Seller'
        if self.product and self.product.store:
            store = self.product.store
            seller_id = store.id
            seller_name = store.store_name or 'Unknown Seller'
            if store.seller and store.seller.registration and store.seller.registration.shop_name:
                seller_name = store.seller.registration.shop_name

        return {
            'id': self.id,
            'cartId': self.cart_id,
            'productId': self.product_id,
            'variationId': self.variation_id,
            'quantity': self.quantity,
            'priceAtAdd': self.price_at_add,
            'sellerId': seller_id,
            'sellerName': seller_name,
            'product': {
                'id': self.product.id,
                'name': self.product.name,
                'price': self.product.price,
                'salePrice': self.product.sale_price,
                'imageUrl': image_url or '/placeholder.svg?height=80&width=80&query=fashion',
                'images': images if images else ['/placeholder.svg?height=80&width=80&query=fashion'],
            } if self.product else None,
            'variation': {
                'id': self.variation.id,
                'size': self.variation.size,
                'color': self.variation.color,
                'sku': self.variation.sku,
                'price': self.variation.price,
            } if self.variation else None,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None,
        }


@dataclass
class PasswordResetCode(Base):
    """One-time 6-digit PIN for password reset (email or SMS)."""

    __tablename__ = "password_reset_code"

    id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), index=True)
    code_hash: Mapped[str] = mapped_column(String(255))
    channel: Mapped[str] = mapped_column(String(16), default="email")
    expires_at: Mapped[datetime.datetime] = mapped_column(DATETIME)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime.datetime] = mapped_column(
        default=lambda: datetime.datetime.now(datetime.timezone.utc)
    )

    user: Mapped["User"] = relationship()
