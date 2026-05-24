from . import (
    store as store_bp,
    db,
    Product,
    Seller,
    StoreRegistration,
    Store
)
from flask import (
    jsonify,
    abort,
    request
)
from app.decorators import (
    seller_required
)
from flask_jwt_extended import (
    jwt_required,
    current_user
)
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

@store_bp.post('/register')
@jwt_required()
@seller_required()
def applyForStore():
    if not request.is_json:
        abort(400)

    try:
        data=request.get_json()
        seller=db.session.execute(select(Seller).where(Seller.user_id==current_user.id)).scalar_one_or_none()

        storeRegistration=StoreRegistration(
            store_purpose=data['store_purpose'],
            user_id=current_user.id,
            seller_id=seller.id
        )

        db.session.add(storeRegistration)
        db.session.commit()

        return jsonify(msg='Successfully sent a request to register your store!'), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg='Store registration request already exists!'), 400
    except:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500

@store_bp.post('/create-store')
@jwt_required()
@seller_required()
def createStore():
    if not request.is_json:
        abort(400)

    try:
        data=request.get_json()
        seller=db.session.execute(select(Seller).where(Seller.user_id==current_user.id)).scalar_one_or_none()

        store=Store(
            store_name=data['store_name'],
            store_email=data['store_email'],
            description=data['description'],
            country=data['country'],
            address=data['address'],
            store_phone_number=data['store_phone_number'],
            user_id=current_user.id,
            seller_id=seller.id
        )

        db.session.add(store)
        db.session.commit()

        return jsonify(msg='Successfully created a store profile!'), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg='Store profile already exists!'), 400
    except:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500

# @store_bp.get('/products/<int:user_id>')
# @seller_required()
# def getStoreProducts(user_id):
#     products=db.session.execute(select(Product).where(Product.store_id==user_id)).scalars()
    
#     try:
#         return jsonify({
#             "products": [p for p in products]
#         }), 200
#     except:
#         return "Error occurred", 500