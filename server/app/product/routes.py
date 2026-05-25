import datetime
import os
import json

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
from sqlalchemy.orm import selectinload
from werkzeug.utils import secure_filename

CATEGORY_ID_TO_NAME = {
    "dress-skirts": "Dressess and Skirts",
    "tops-blouses": "tops and blouses",
    "activewear": "activewear and yoga pants",
    "lingerie-sleepwear": "lingerie and sleepwear",
    "jackets-coats": "jackets and coats",
    "accessories-shoes": "shoes and accessories",
}


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
                    "path": m.path,
                    "created_at": m.created_at.isoformat() if m.created_at else None,
                }
                for m in product.media
            ],
            "variations": [
                {
                    "id": v.id,
                    "size": v.size,
                    "color": v.color,
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
    product_name_input = request.args.get(product_name)
    products=db.session.execute(select(Product).where(Product.name.ilike(f'%{product_name_input}%'))).scalars().all()

    try:
        return jsonify(products=products)
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

      stmt = stmt.limit(limit)
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

      data = [
          {
              "id": p.id,
              "name": p.name,
              "subcategory": getattr(p, "subcategory", None),
              "price": p.price,
              "image_url": _public_image_url(getattr(p, "image_url", None)),
              "rating": getattr(p, "rating", 0),
              "review_count": getattr(p, "review_count", 0),
              "store_id": getattr(p, "store_id", None),
              # Alias for frontend field name
              "seller_name": stores_map.get(getattr(p, "store_id", None)),
              "categories": categories_by_product.get(p.id, []),
          }
          for p in products
      ]

      return jsonify(products=data)
    except Exception:
      return jsonify(msg="Error occurred!"), 500


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

        if categories_raw:
            if isinstance(categories_raw, str) and categories_raw.strip().startswith('['):
                try:
                    parsed = json.loads(categories_raw)
                    if isinstance(parsed, list):
                        category_ids = [str(c) for c in parsed]
                    else:
                        category_ids = [str(parsed)]
                except Exception:
                    category_ids = []
            else:
                category_ids = [str(categories_raw)]

        # Enforce that selected categories are restricted to those registered for this seller
        if allowed_category_ids:
            category_ids = [cid for cid in category_ids if cid in allowed_category_ids]

        if not name:
            return jsonify(msg="Product name is required"), 400

        try:
            # Handle both integer and decimal string inputs from the frontend (e.g. "1999" or "1999.00")
            price_value = int(float(price)) if price is not None else 0
        except (TypeError, ValueError):
            price_value = 0

        try:
            quantity_value = int(quantity) if quantity is not None else 0
        except (TypeError, ValueError):
            quantity_value = 0

        try:
            sale_price_value = int(float(sale_price)) if sale_price is not None else None
        except (TypeError, ValueError):
            sale_price_value = None

        try:
            cost_price_value = float(cost_price) if cost_price is not None else 0.0
        except (TypeError, ValueError):
            cost_price_value = 0.0

        try:
            weight_kg_value = float(weight_kg) if weight_kg is not None else None
        except (TypeError, ValueError):
            weight_kg_value = None

        try:
            low_stock_threshold_value = int(low_stock_threshold_raw) if low_stock_threshold_raw is not None else None
        except (TypeError, ValueError):
            low_stock_threshold_value = None

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

        if category_ids:
            resolved_categories = []
            for cat_id in category_ids:
                category_name = CATEGORY_ID_TO_NAME.get(cat_id)
                if not category_name:
                    continue
                category_row = db.session.execute(
                    select(Category).where(Category.name == category_name)
                ).scalar_one_or_none()
                if category_row is None:
                    continue
                resolved_categories.append(category_row)

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
            for v in variations_data:
                try:
                    size = v.get('size')
                    sku = v.get('sku') or ''
                    stock = int(v.get('stock') or 0)
                    colors = v.get('colors') or []

                    if not size:
                        continue

                    # Collapse colors into a single comma-separated string for the existing color column
                    if isinstance(colors, list):
                        color_value = ', '.join(str(c).strip() for c in colors if c)
                    else:
                        color_value = str(colors)

                    variation = ProductVariation(
                        product=product,
                        size=size,
                        color=color_value,
                        sku=sku,
                        inventory=stock,
                        price=None,
                    )
                    db.session.add(variation)
                except Exception:
                    # Skip invalid variation entries but continue creating the product
                    continue

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
    if not request.is_json:
        abort(400)
    
    product=db.session.execute(select(Product).where(Product.id==product_id)).scalar_one_or_none()
    store=db.session.execute(select(Store).where(Store.user_id==current_user.id)).scalar_one_or_none()

    try:
        if product.store_id!=store.id:
            return jsonify(msg="Unauthorized request!"), 403

        if not product_can_seller_edit(product):
            return jsonify(msg="This product cannot be edited while restricted or removed by admin."), 403
        
        data = request.get_json() or {}

        # Basic fields (backwards compatible)
        name = data.get('name')
        price = data.get('price')
        quantity = data.get('quantity')
        description = data.get('description')
        low_stock_threshold = data.get('low_stock_threshold')
        cost_price = data.get('cost_price')
        size_chart_raw = data.get('size_chart')

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

        # Optional size chart update (accept either legacy flat or matrix JSON)
        if size_chart_raw is not None:
            try:
                if isinstance(size_chart_raw, str):
                    # Assume the frontend already sent a JSON string
                    product.size_chart_json = size_chart_raw
                else:
                    product.size_chart_json = json.dumps(size_chart_raw)
            except Exception:
                # Ignore invalid payload and leave existing size_chart_json as-is
                pass

        # Optional variations payload – same shape as in createProduct
        variations_raw = data.get('variations')
        variations_data = []
        if variations_raw is not None:
            try:
                # variations may come as already-parsed list or a JSON string
                if isinstance(variations_raw, str):
                    variations_data = json.loads(variations_raw)
                else:
                    variations_data = variations_raw
            except Exception:
                variations_data = []

            # Replace existing variations with the new set
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

                        # Flatten colors list to a single string (matches createProduct)
                        if isinstance(colors, list):
                            color_value = ', '.join(str(c).strip() for c in colors if c)
                        else:
                            color_value = str(colors)

                        variation = ProductVariation(
                            product=product,
                            size=size,
                            color=color_value,
                            sku=sku,
                            inventory=stock,
                            price=None,
                        )
                        db.session.add(variation)
                        total_stock += stock
                    except Exception:
                        # Skip invalid variation entries but continue updating the product
                        continue

            # If caller did not explicitly send quantity, sync it from total variation stock
            if quantity is None and variations_data:
                product.quantity = total_stock

        product.updated_at = datetime.datetime.now()

        db.session.commit()

        return jsonify(msg="Succesfully updated product!"), 201
    except:
        db.session.rollback()
        return jsonify(msg="Error occurred!"), 500