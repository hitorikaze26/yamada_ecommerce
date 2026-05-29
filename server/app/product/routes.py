import datetime
import os
import json
import math

from . import (
    products as products_bp,
    db,
    Product,
    Store,
    Category,
    ProductCategory,
    ProductVariation,
    seller_required,
    is_store_accepted
)
from app.models import ProductMedia, ProductModerationStatus, product_can_seller_edit, product_is_public
from flask import (
    jsonify,
    abort,
    request,
    current_app,
)
from flask_jwt_extended import (
    jwt_required,
    current_user
)
from sqlalchemy import select, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload
from werkzeug.utils import secure_filename

CATEGORY_ID_TO_NAME = {
    "dress-skirts": "Dresses and Skirts",
    "bottoms": "Bottoms",
    "tops-blouses": "tops and blouses",
    "activewear": "activewear and yoga pants",
    "lingerie-sleepwear": "lingerie and sleepwear",
    "jackets-coats": "jackets and coats",
    "accessories-shoes": "shoes and accessories",
}

CATEGORY_ID_FALLBACK_NAMES = {
    "dress-skirts": [
        "Dresses and Skirts",
        "Dress & Skirts",
        "Dresses & Skirts",
        "Dressess and Skirts",
    ],
    "tops-blouses": [
        "tops and blouses",
        "Tops & Blouses",
    ],
    "activewear": [
        "activewear and yoga pants",
        "Activewear & Yoga Pants",
    ],
    "lingerie-sleepwear": [
        "lingerie and sleepwear",
        "Lingerie & Sleepwear",
    ],
    "jackets-coats": [
        "jackets and coats",
        "Jackets & Coats",
    ],
    "accessories-shoes": [
        "shoes and accessories",
        "Accessories & Shoes",
        "Accessories and Shoes",
        "Shoes and Accessories",
        "Shoes & Accessories",
    ],
    "bottoms": [
        "Bottoms",
        "bottoms",
    ],
}

CATEGORY_ALIASES_TO_ID = {
    # IDs
    "dress-skirts": "dress-skirts",
    "bottoms": "bottoms",
    "tops-blouses": "tops-blouses",
    "activewear": "activewear",
    "lingerie-sleepwear": "lingerie-sleepwear",
    "jackets-coats": "jackets-coats",
    "accessories-shoes": "accessories-shoes",

    # Canonical names
    "dresses and skirts": "dress-skirts",
    "dressess and skirts": "dress-skirts",
    "bottoms": "bottoms",
    "tops and blouses": "tops-blouses",
    "activewear and yoga pants": "activewear",
    "lingerie and sleepwear": "lingerie-sleepwear",
    "jackets and coats": "jackets-coats",
    "shoes and accessories": "accessories-shoes",

    # Frontend display labels / legacy variants
    "dress & skirts": "dress-skirts",
    "tops & blouses": "tops-blouses",
    "activewear & yoga pants": "activewear",
    "lingerie & sleepwear": "lingerie-sleepwear",
    "jackets & coats": "jackets-coats",
    "accessories & shoes": "accessories-shoes",
    "accessories and shoes": "accessories-shoes",
}


def _normalize_category_token(value) -> str | None:
    if value is None:
        return None
    token = str(value).strip()
    if not token:
        return None
    return CATEGORY_ALIASES_TO_ID.get(token.lower())


def _extract_category_tokens(raw) -> list[str]:
    """Extract category tokens from mixed payload shapes.

    Supports:
    - single string ID/name
    - comma-separated string
    - JSON string array
    - list/tuple/set values
    - objects like {id: ..., name: ...}
    """
    if raw is None:
        return []

    # JSON string array / object
    if isinstance(raw, str):
        token = raw.strip()
        if not token:
            return []

        if token.startswith('[') or token.startswith('{'):
            try:
                parsed = json.loads(token)
                return _extract_category_tokens(parsed)
            except Exception:
                pass

        # comma-separated fallback
        if ',' in token:
            return [part.strip() for part in token.split(',') if part.strip()]

        return [token]

    if isinstance(raw, dict):
        for key in ("id", "category_id", "slug", "name", "label", "value"):
            if key in raw and raw.get(key):
                return [str(raw.get(key)).strip()]
        return []

    if isinstance(raw, (list, tuple, set)):
        tokens: list[str] = []
        for item in raw:
            tokens.extend(_extract_category_tokens(item))
        return [t for t in tokens if t]

    return [str(raw).strip()]


from app.utils.static_urls import public_static_url as _public_image_url

@products_bp.get('/product/<int:product_id>')
def getProduct(product_id):
    product = db.session.execute(
        select(Product)
        .options(selectinload(Product.media), selectinload(Product.variations))
        .where(Product.id == product_id)
    ).scalar_one_or_none()

    if product is None:
        return jsonify(msg="Product not found"), 404

    try:
        store = db.session.execute(select(Store).where(Store.id == product.store_id)).scalar_one_or_none()

        # Load categories linked to this product via ProductCategory
        categories_rows = db.session.execute(
            select(Category.name)
            .join(ProductCategory, ProductCategory.category_id == Category.id)
            .where(ProductCategory.product_id == product.id)
        ).scalars().all()

        # Build images array from media for easier frontend consumption
        all_images = []
        if product.image_url:
            all_images.append(_public_image_url(product.image_url))
        for m in product.media:
            if m.media_type == 'image' and m.path:
                all_images.append(_public_image_url(m.path))
        # Remove duplicates while preserving order
        seen = set()
        unique_images = []
        for img in all_images:
            if img and img not in seen:
                seen.add(img)
                unique_images.append(img)

        product_data = {
            "id": product.id,
            "name": product.name,
            "subcategory": getattr(product, "subcategory", None),
            "price": product.price,
            "sale_price": product.sale_price,
            "cost_price": product.cost_price,
            "quantity": product.quantity,
            "description": product.description,
            "image_url": _public_image_url(product.image_url),
            "images": unique_images,
            "store_id": product.store_id,
            "rating": product.rating,
            "review_count": product.review_count,
            "seller_name": store.store_name if store else None,
            "seller_logo": None,
            "categories": categories_rows,
            "brand": product.brand,
            "product_condition": product.product_condition,
            "weight_kg": product.weight_kg,
            "material": product.material,
            "care_instructions": product.care_instructions,
            "low_stock_threshold": product.low_stock_threshold,
            "tags_json": product.tags_json,
            "created_at": product.created_at.isoformat() if product.created_at else None,
            "updated_at": product.updated_at.isoformat() if product.updated_at else None,
            "size_chart_json": product.size_chart_json,
            "media": [
                {
                    "id": m.id,
                    "media_type": m.media_type,
                    "path": _public_image_url(m.path),
                    "created_at": m.created_at.isoformat() if m.created_at else None,
                }
                for m in product.media
            ],
            "variations": [
                {
                    "id": v.id,
                    "size": v.size,
                    "color": v.color,
                        "colorHex": getattr(v, 'color_hex', None),
                    "sku": v.sku,
                    "inventory": v.inventory,
                    "price": v.price,
                }
                for v in product.variations
            ],
        }

        return jsonify(product=product_data)
    except Exception:
        return jsonify(msg="Error occurred!"), 500

@products_bp.get('/product/<string:product_name>')
def getProductByName(product_name):
    try:
        products = db.session.execute(
            select(Product)
            .options(selectinload(Product.media))
            .where(Product.name.ilike(f'%{product_name}%'))
        ).scalars().all()

        result = []
        for p in products:
            data = p.to_json()
            data["images"] = [
                _public_image_url(img) or img for img in data.get("images", [])
            ]
            if data.get("media"):
                for m in data["media"]:
                    if m.get("path"):
                        m["path"] = _public_image_url(m["path"]) or m["path"]
            result.append(data)

        return jsonify(products=result)
    except:
        return jsonify(msg="Error occurred!"), 500

@products_bp.get('/')
def listProducts():
    """List products with optional filters for similar-products use cases.

    Query params:
      - seller: store_id to filter by
      - exclude: product id to exclude from results
      - limit: max number of products (default 8)
    """

    seller_id = request.args.get('seller', type=int)
    exclude_id = request.args.get('exclude', type=int)
    limit = request.args.get('limit', type=int) or 8
    category_id_param = request.args.get('category') or request.args.get('categoryId')
    search_query = request.args.get('search') or request.args.get('q')

    try:
      stmt = select(Product).where(
          Product.moderation_status == ProductModerationStatus.ACTIVE,
          Product.is_live.is_(True),
      )
      if seller_id is not None:
          stmt = stmt.where(Product.store_id == seller_id)
      if exclude_id is not None:
          stmt = stmt.where(Product.id != exclude_id)

      if category_id_param:
          category_name = CATEGORY_ID_TO_NAME.get(category_id_param)
          if category_name:
              category_row = db.session.execute(
                  select(Category).where(Category.name == category_name)
              ).scalar_one_or_none()
              if category_row is not None:
                  stmt = stmt.join(
                      ProductCategory,
                      ProductCategory.product_id == Product.id,
                  ).where(ProductCategory.category_id == category_row.id)

      if search_query:
          like = f"%{search_query}%"
          stmt = stmt.where(
              or_(
                  Product.name.ilike(like),
                  Product.description.ilike(like),
                  Product.subcategory.ilike(like),
              )
          )

      # Optional sorting
      sort_param = request.args.get('sort')
      if sort_param == 'newest':
          stmt = stmt.order_by(Product.created_at.desc())
      elif sort_param == 'popular':
          stmt = stmt.order_by(Product.rating.desc(), Product.review_count.desc())

      stmt = stmt.options(
          selectinload(Product.media),
          selectinload(Product.variations),
      ).limit(limit)
      products = db.session.execute(stmt).scalars().all()

      # Preload store names for all products so the frontend can show
      # the shop name (seller_name) on the home page.
      store_ids = {p.store_id for p in products if getattr(p, "store_id", None) is not None}
      stores_map: dict[int, str] = {}
      if store_ids:
          stores_rows = db.session.execute(
              select(Store.id, Store.store_name).where(Store.id.in_(store_ids))
          ).all()
          for row in stores_rows:
              stores_map[row.id] = row.store_name

      # Preload categories for all products to expose a categories[] array
      # per product in the API, used by the home page mapping.
      product_ids = [p.id for p in products]
      categories_by_product: dict[int, list[str]] = {pid: [] for pid in product_ids}
      if product_ids:
          cat_rows = db.session.execute(
              select(ProductCategory.product_id, Category.name)
              .join(Category, ProductCategory.category_id == Category.id)
              .where(ProductCategory.product_id.in_(product_ids))
          ).all()
          for row in cat_rows:
              categories_by_product.setdefault(row.product_id, []).append(row.name)

      data = []
      for p in products:
          # Build images array (same pattern as getProduct)
          all_images = []
          if p.image_url:
              all_images.append(_public_image_url(p.image_url))
          for m in (getattr(p, "media", None) or []):
              if m.media_type == "image" and m.path:
                  all_images.append(_public_image_url(m.path))
          seen = set()
          unique_images = []
          for img in all_images:
              if img and img not in seen:
                  seen.add(img)
                  unique_images.append(img)

          tags_list = []
          if p.tags_json:
              try:
                  parsed = json.loads(p.tags_json) if isinstance(p.tags_json, str) else p.tags_json
                  if isinstance(parsed, list):
                      tags_list = parsed
              except Exception:
                  pass

          data.append({
              "id": p.id,
              "name": p.name,
              "subcategory": getattr(p, "subcategory", None),
              "description": p.description or "",
              "price": p.price,
              "sale_price": p.sale_price,
              "cost_price": p.cost_price,
              "quantity": p.quantity,
              "image_url": _public_image_url(getattr(p, "image_url", None)),
              "images": unique_images,
              "rating": getattr(p, "rating", 0),
              "review_count": getattr(p, "review_count", 0),
              "store_id": getattr(p, "store_id", None),
              "seller_name": stores_map.get(getattr(p, "store_id", None)),
              "categories": categories_by_product.get(p.id, []),
              "brand": p.brand,
              "product_condition": p.product_condition,
              "weight_kg": p.weight_kg,
              "material": p.material,
              "care_instructions": p.care_instructions,
              "tags_json": p.tags_json,
              "tags": tags_list,
              "variations": [
                  {
                      "id": v.id,
                      "size": v.size,
                      "color": v.color,
                      "colorHex": getattr(v, 'color_hex', None),
                      "sku": v.sku,
                      "inventory": v.inventory,
                      "price": v.price,
                  }
                  for v in p.variations
              ],
          })

      return jsonify(products=data)
    except Exception as e:
      return jsonify(msg=str(e)), 500


@products_bp.post('/create')
@jwt_required()
@seller_required()
@is_store_accepted
def createProduct():
    try:
        if current_user is None:
            return jsonify(msg="Authentication required"), 401

        from app.services.punishment_service import PunishmentService, ACTION_PRODUCT_LISTING

        blocked = PunishmentService.enforce(current_user.id, ACTION_PRODUCT_LISTING)
        if blocked:
            return blocked

        store=db.session.execute(select(Store).where(Store.user_id==current_user.id)).scalar_one_or_none()
        if store is None:
            return jsonify(msg="Store not found"), 404

        category_ids: list[str] = []
        allowed_category_ids: list[str] = []

        # Load allowed categories from the seller's original store registration
        if store.seller and store.seller.registration and store.seller.registration.categories_json:
            try:
                parsed = json.loads(store.seller.registration.categories_json)
                if isinstance(parsed, list):
                    allowed_category_ids = [str(c) for c in parsed]
            except Exception:
                allowed_category_ids = []
        if request.is_json:
            data = request.get_json() or {}
            name = data.get('name')
            subcategory = data.get('subcategory')
            price = data.get('price')
            quantity = data.get('quantity')
            description = data.get('description')
            categories_raw = data.get('categories') or data.get('category')
            variations_raw = data.get('variations')

            brand = data.get('brand')
            sale_price = data.get('sale_price')
            cost_price = data.get('cost_price')
            tags_raw = data.get('tags')
            product_condition = data.get('product_condition')
            weight_kg = data.get('weight_kg')
            material = data.get('material')
            care_instructions = data.get('care_instructions')
            size_chart_raw = data.get('size_chart')
            low_stock_threshold_raw = data.get('low_stock_threshold')
        else:
            form = request.form
            name = form.get('name')
            subcategory = form.get('subcategory')
            price = form.get('price')
            quantity = form.get('quantity')
            description = form.get('description')
            categories_raw = form.get('categories') or form.get('category')
            variations_raw = form.get('variations')

            brand = form.get('brand')
            sale_price = form.get('sale_price')
            cost_price = form.get('cost_price')
            tags_raw = form.get('tags')
            product_condition = form.get('product_condition')
            weight_kg = form.get('weight_kg')
            material = form.get('material')
            care_instructions = form.get('care_instructions')
            size_chart_raw = form.get('size_chart')
            low_stock_threshold_raw = form.get('low_stock_threshold')

        category_ids = _extract_category_tokens(categories_raw)
        allowed_category_ids = _extract_category_tokens(allowed_category_ids)

        # Normalize selected categories and seller-allowed categories to canonical IDs
        normalized_selected = [
            norm
            for norm in (_normalize_category_token(c) for c in category_ids)
            if norm
        ]
        normalized_allowed = [
            norm
            for norm in (_normalize_category_token(c) for c in allowed_category_ids)
            if norm
        ]

        # Keep order but dedupe
        category_ids = list(dict.fromkeys(normalized_selected))
        allowed_category_ids = list(dict.fromkeys(normalized_allowed))

        current_app.logger.info(
            "[createProduct] category normalization seller_id=%s selected=%s allowed=%s",
            current_user.id if current_user else None,
            category_ids,
            allowed_category_ids,
        )

        # Filter to categories registered for this seller (informational only — don't hard-block)
        if allowed_category_ids:
            category_ids = [cid for cid in category_ids if cid in allowed_category_ids]

        if not name:
            return jsonify(msg="Product name is required"), 400

        def _parse_float(value, field_name: str, *, required: bool = False, min_value: float | None = None):
            if value is None or (isinstance(value, str) and value.strip() == ""):
                if required:
                    raise ValueError(f"{field_name} is required")
                return None
            try:
                parsed = float(value)
            except (TypeError, ValueError):
                raise ValueError(f"{field_name} must be numeric")
            if not math.isfinite(parsed):
                raise ValueError(f"{field_name} must be a finite number")
            if min_value is not None and parsed < min_value:
                raise ValueError(f"{field_name} must be at least {min_value}")
            return parsed

        def _parse_int(value, field_name: str, *, required: bool = False, min_value: int | None = None):
            if value is None or (isinstance(value, str) and value.strip() == ""):
                if required:
                    raise ValueError(f"{field_name} is required")
                return None
            try:
                parsed = int(value)
            except (TypeError, ValueError):
                raise ValueError(f"{field_name} must be an integer")
            if min_value is not None and parsed < min_value:
                raise ValueError(f"{field_name} must be at least {min_value}")
            return parsed

        price_value = _parse_float(price, "Product price", required=True, min_value=0.0) or 0.0
        quantity_value = _parse_int(quantity, "Quantity", min_value=0) or 0
        sale_price_value = _parse_float(sale_price, "Sale price", min_value=0.0)
        cost_price_value = _parse_float(cost_price, "Cost price", min_value=0.0)
        weight_kg_value = _parse_float(weight_kg, "Weight (kg)", min_value=0.0)
        low_stock_threshold_value = _parse_int(
            low_stock_threshold_raw,
            "Low stock threshold",
            min_value=0,
        )

        tags_json = None
        if tags_raw:
            if isinstance(tags_raw, str):
                tags_list = [t.strip() for t in tags_raw.split(',') if t.strip()]
                tags_json = json.dumps(tags_list)

        size_chart_json = None
        if size_chart_raw:
            try:
                if isinstance(size_chart_raw, str):
                    size_chart_json = size_chart_raw
                else:
                    size_chart_json = json.dumps(size_chart_raw)
            except Exception:
                size_chart_json = None

        product=Product(
            name=name,
            subcategory=subcategory or None,
            price=price_value,
            quantity=quantity_value,
            description=description or "",
            store_id=store.id,
            is_live=True,
            moderation_status=ProductModerationStatus.ACTIVE,
            brand=brand or None,
            sale_price=sale_price_value,
            cost_price=cost_price_value,
            tags_json=tags_json,
            product_condition=product_condition or None,
            weight_kg=weight_kg_value,
            material=material or None,
            size_chart_json=size_chart_json,
            care_instructions=care_instructions or None,
            low_stock_threshold=low_stock_threshold_value,
        )

        db.session.add(product)
        db.session.flush()

        if category_ids:
            resolved_categories = []
            for cat_id in category_ids:
                category_name = CATEGORY_ID_TO_NAME.get(cat_id)
                if not category_name:
                    continue

                candidate_names = CATEGORY_ID_FALLBACK_NAMES.get(cat_id, [category_name])
                category_row = None
                for candidate_name in candidate_names:
                    category_row = db.session.execute(
                        select(Category).where(Category.name.ilike(candidate_name))
                    ).scalar_one_or_none()
                    if category_row is not None:
                        break
                if category_row is None:
                    continue
                resolved_categories.append(category_row)

            if not resolved_categories:
                current_app.logger.warning(
                    "[createProduct] category rows not found; creating product without category link seller_id=%s category_ids=%s",
                    current_user.id if current_user else None,
                    category_ids,
                )

            for category in resolved_categories:
                link = ProductCategory(
                    product_id=product.id,
                    category_id=category.id,
                )
                db.session.add(link)

        # Create product variations (per-size/color inventory)
        variations_data = []
        if variations_raw:
            try:
                # variations may come as already-parsed list (JSON body) or a JSON string (form-data)
                if isinstance(variations_raw, str):
                    variations_data = json.loads(variations_raw)
                else:
                    variations_data = variations_raw
            except Exception:
                variations_data = []

        if variations_data:
            if not isinstance(variations_data, list):
                raise ValueError("Variations payload must be a list")

            seen_skus: set[str] = set()
            for v in variations_data:
                if not isinstance(v, dict):
                    raise ValueError("Each variation must be an object")

                size = str(v.get('size') or '').strip()
                if not size:
                    raise ValueError("Each variation must include size")

                stock = _parse_int(v.get('stock'), "Variant stock", min_value=0) or 0

                sku_raw = str(v.get('sku') or '').strip()
                sku = sku_raw or None
                if sku:
                    if sku in seen_skus:
                        raise ValueError(f"Duplicate SKU detected: {sku}")
                    seen_skus.add(sku)

                colors = v.get('colors') or []

                # Collapse colors into a single comma-separated string for the existing color column
                if isinstance(colors, list):
                    color_value = ', '.join(str(c).strip() for c in colors if c)
                else:
                    color_value = str(colors).strip()

                color_hex = v.get('colorHex') or v.get('color_hex')
                if color_hex and isinstance(color_hex, str):
                    color_hex = color_hex.strip()
                    if not color_hex.startswith('#'):
                        color_hex = None
                    elif len(color_hex) > 7:
                        color_hex = color_hex[:7]
                else:
                    color_hex = None

                variant_price = _parse_float(
                    v.get('price'),
                    "Variant price",
                    min_value=0.0,
                )

                variation = ProductVariation(
                    product=product,
                    size=size,
                    color=color_value,
                    color_hex=color_hex,
                    sku=sku,
                    inventory=stock,
                    price=variant_price,
                )
                db.session.add(variation)

        # Handle optional uploaded images and videos when using multipart/form-data
        if not request.is_json:
            from app.utils.upload import save_upload

            def save_image(file_obj, suffix: str) -> str | None:
                if not file_obj or not file_obj.mimetype.startswith('image/'):
                    return None
                safe_name = secure_filename(file_obj.filename or 'image')
                filename = f"product_{product.id or 'new'}_{suffix}_{safe_name}"
                return save_upload(file_obj, "product_images", filename=filename)

            main_image = request.files.get('main_image')
            additional_images = request.files.getlist('additional_images')

            # Main image
            main_rel = save_image(main_image, 'main') if main_image else None
            if main_rel:
                product.image_url = main_rel
                media = ProductMedia(
                    product=product,
                    media_type='image',
                    path=main_rel,
                )
                db.session.add(media)

            # Additional images
            for idx, img in enumerate(additional_images):
                rel = save_image(img, f'extra{idx}')
                if not rel:
                    continue
                media = ProductMedia(
                    product=product,
                    media_type='image',
                    path=rel,
                )
                db.session.add(media)

            # Videos
            videos = request.files.getlist('videos')
            if videos:
                timestamp = int(datetime.datetime.now().timestamp())
                for index, file in enumerate(videos):
                    if not file:
                        continue

                    if not file.mimetype.startswith('video/'):
                        continue

                    safe_name = secure_filename(file.filename or 'video')
                    filename = f"product_{product.id or 'new'}_{timestamp}_{index}_{safe_name}"
                    relative_path = save_upload(
                        file, "product_videos", filename=filename
                    )
                    media = ProductMedia(
                        product=product,
                        media_type='video',
                        path=relative_path,
                    )
                    db.session.add(media)

        db.session.commit()

        return jsonify(msg="Succesfully created product!"), 201
    except ValueError as exc:
        db.session.rollback()
        return jsonify(msg=str(exc)), 400
    except IntegrityError:
        db.session.rollback()
        current_app.logger.exception("createProduct integrity failure")
        return jsonify(msg="Database constraint failed while creating product"), 409
    except Exception:
        db.session.rollback()
        current_app.logger.exception("createProduct failed")
        return jsonify(msg="Error occurred! Please try again or contact support."), 500
    
@products_bp.post('/deactivate/<int:product_id>')
@jwt_required()
@seller_required()
@is_store_accepted
def deactivateProduct(product_id):
    product = db.session.execute(select(Product).where(Product.id == product_id)).scalar_one_or_none()
    store = db.session.execute(select(Store).where(Store.user_id == current_user.id)).scalar_one_or_none()

    try:
        if product is None or store is None or product.store_id != store.id:
            return jsonify(msg="Unauthorized request!"), 403

        # Mark product as not live / hidden. Fallback to generic visibility flag if present.
        if hasattr(product, "is_live"):
            product.is_live = False
        if hasattr(product, "visibility"):
            product.visibility = False

        product.updated_at = datetime.datetime.now()
        db.session.commit()

        return jsonify(msg="Successfully deactivated product!"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error occurred!"), 500

@products_bp.delete('/delete/<int:product_id>')
@jwt_required()
@seller_required()
@is_store_accepted
def deleteProduct(product_id):
    product=db.session.execute(select(Product).where(Product.id==product_id)).scalar_one_or_none()
    store=db.session.execute(select(Store).where(Store.user_id==current_user.id)).scalar_one_or_none()
    
    try:
        if product.store_id!=store.id:
            return jsonify(msg="Unauthorized request!"), 403

        if not product_can_seller_edit(product):
            return jsonify(msg="This product cannot be deleted while restricted or removed by admin."), 403
        
        db.session.delete(product)
        db.session.commit()

        return jsonify(msg="Successfully deleted product!"), 200
    except:
        db.session.rollback()
        return jsonify(msg="Error occurred!"), 500
    
@products_bp.put('/edit/<int:product_id>')
@jwt_required()
@seller_required()
@is_store_accepted
def updateProduct(product_id):
    product=db.session.execute(select(Product).where(Product.id==product_id)).scalar_one_or_none()
    store=db.session.execute(select(Store).where(Store.user_id==current_user.id)).scalar_one_or_none()

    try:
        if product.store_id!=store.id:
            return jsonify(msg="Unauthorized request!"), 403

        if not product_can_seller_edit(product):
            return jsonify(msg="This product cannot be edited while restricted or removed by admin."), 403

        # Parse input: JSON or multipart/form-data
        if request.is_json:
            data = request.get_json() or {}
        else:
            data = request.form

        def _get(key):
            return data.get(key)

        # Basic fields (backwards compatible)
        name = _get('name')
        price = _get('price')
        quantity = _get('quantity')
        description = _get('description')
        low_stock_threshold = _get('low_stock_threshold')
        cost_price = _get('cost_price')
        size_chart_raw = _get('size_chart')
        subcategory = _get('subcategory')

        if name is not None and name != '':
            product.name = name
        if price is not None:
            product.price = price
        if quantity is not None:
            product.quantity = quantity
        if description is not None and description != '':
            product.description = description
        if cost_price is not None:
            try:
                product.cost_price = float(cost_price)
            except (TypeError, ValueError):
                pass

        if low_stock_threshold is not None:
            try:
                product.low_stock_threshold = int(low_stock_threshold)
            except (TypeError, ValueError):
                product.low_stock_threshold = None

        if subcategory is not None:
            product.subcategory = subcategory

        # Optional size chart update (accept either legacy flat or matrix JSON)
        if size_chart_raw is not None:
            try:
                if isinstance(size_chart_raw, str):
                    product.size_chart_json = size_chart_raw
                else:
                    product.size_chart_json = json.dumps(size_chart_raw)
            except Exception:
                pass

        # Optional variations payload
        variations_raw = _get('variations')
        variations_data = []
        if variations_raw is not None:
            try:
                if isinstance(variations_raw, str):
                    variations_data = json.loads(variations_raw)
                else:
                    variations_data = variations_raw
            except Exception:
                variations_data = []

            for existing in list(product.variations):
                db.session.delete(existing)

            total_stock = 0

            if isinstance(variations_data, list):
                for v in variations_data:
                    try:
                        size = v.get('size')
                        sku = v.get('sku') or ''
                        stock = int(v.get('stock') or 0)
                        colors = v.get('colors') or []

                        if not size:
                            continue

                        if isinstance(colors, list):
                            color_value = ', '.join(str(c).strip() for c in colors if c)
                        else:
                            color_value = str(colors)

                        color_hex = v.get('colorHex') or v.get('color_hex')
                        if color_hex and isinstance(color_hex, str):
                            color_hex = color_hex.strip()
                            if not color_hex.startswith('#'):
                                color_hex = None
                            elif len(color_hex) > 7:
                                color_hex = color_hex[:7]
                        else:
                            color_hex = None

                        variation = ProductVariation(
                            product=product,
                            size=size,
                            color=color_value,
                            color_hex=color_hex,
                            sku=sku,
                            inventory=stock,
                            price=None,
                        )
                        db.session.add(variation)
                        total_stock += stock
                    except Exception:
                        continue

            if quantity is None and variations_data:
                product.quantity = total_stock

        # ── Image/media handling (multipart only) ──
        if not request.is_json:
            from app.utils.upload import save_upload

            # Remove specific media by ID (comma-separated or JSON array from form)
            remove_ids_raw = _get('remove_media_ids')
            if remove_ids_raw:
                try:
                    if isinstance(remove_ids_raw, str):
                        remove_ids = json.loads(remove_ids_raw)
                    else:
                        remove_ids = remove_ids_raw
                    if isinstance(remove_ids, list):
                        for mid in remove_ids:
                            try:
                                mid_int = int(mid)
                                media_row = db.session.execute(
                                    select(ProductMedia).where(
                                        ProductMedia.id == mid_int,
                                        ProductMedia.product_id == product.id,
                                    )
                                ).scalar_one_or_none()
                                if media_row:
                                    from app.utils.supabase_storage import storage
                                    try:
                                        storage.delete(media_row.path)
                                    except Exception:
                                        pass
                                    db.session.delete(media_row)
                            except (ValueError, TypeError):
                                pass
                except Exception:
                    pass

            # Upload new main image (replaces cover)
            main_image = request.files.get('main_image')
            if main_image and main_image.mimetype and main_image.mimetype.startswith('image/'):
                safe_name = secure_filename(main_image.filename or 'image')
                filename = f"product_{product.id}_main_{safe_name}"
                rel = save_upload(main_image, "product_images", filename=filename)
                if rel:
                    # Unmark existing cover media
                    for m in (product.media or []):
                        m.is_cover = False
                    # Set new cover
                    product.image_url = rel
                    media = ProductMedia(
                        product=product,
                        media_type='image',
                        path=rel,
                        is_cover=True,
                    )
                    db.session.add(media)

            # Upload additional gallery images
            additional_images = request.files.getlist('additional_images')
            for idx, img in enumerate(additional_images):
                if not img or not img.mimetype or not img.mimetype.startswith('image/'):
                    continue
                safe_name = secure_filename(img.filename or 'image')
                filename = f"product_{product.id}_extra{idx}_{safe_name}"
                rel = save_upload(img, "product_images", filename=filename)
                if not rel:
                    continue
                media = ProductMedia(
                    product=product,
                    media_type='image',
                    path=rel,
                    is_cover=False,
                )
                db.session.add(media)

            # Upload videos
            videos = request.files.getlist('videos')
            if videos:
                timestamp = int(datetime.datetime.now().timestamp())
                for index, file in enumerate(videos):
                    if not file or not file.mimetype or not file.mimetype.startswith('video/'):
                        continue
                    safe_name = secure_filename(file.filename or 'video')
                    filename = f"product_{product.id}_{timestamp}_{index}_{safe_name}"
                    relative_path = save_upload(file, "product_videos", filename=filename)
                    media = ProductMedia(
                        product=product,
                        media_type='video',
                        path=relative_path,
                        is_cover=False,
                    )
                    db.session.add(media)

        product.updated_at = datetime.datetime.now()
        db.session.commit()

        return jsonify(msg="Succesfully updated product!"), 201
    except:
        db.session.rollback()
        return jsonify(msg="Error occurred!"), 500
