from flask import current_app, has_app_context
from app.models import db, RiderLocation, Order
from app.notifications.realtime import emit_rider_location
import logging

_logger = logging.getLogger(__name__)


class RiderTrackingService:

    @classmethod
    def update_rider_location(cls, rider_id: int, order_id: int | None, latitude: float, longitude: float):
        try:
            record = RiderLocation(
                rider_id=rider_id,
                order_id=order_id,
                latitude=latitude,
                longitude=longitude,
            )
            db.session.add(record)
            db.session.commit()

            if order_id:
                payload = {
                    "riderId": rider_id,
                    "orderId": order_id,
                    "latitude": latitude,
                    "longitude": longitude,
                    "timestamp": record.timestamp.isoformat() if record.timestamp else None,
                }
                emit_rider_location(order_id, payload)

        except Exception as e:
            if has_app_context():
                current_app.logger.error(f"Failed to update rider location: {e}")
            else:
                _logger.error(f"Failed to update rider location: {e}")
            db.session.rollback()

    @classmethod
    def get_latest_location(cls, order_id: int) -> dict | None:
        try:
            location = (
                RiderLocation.query
                .filter_by(order_id=order_id)
                .order_by(RiderLocation.timestamp.desc())
                .first()
            )
            if not location:
                return None
            return {
                "id": location.id,
                "riderId": location.rider_id,
                "orderId": location.order_id,
                "latitude": float(location.latitude),
                "longitude": float(location.longitude),
                "timestamp": location.timestamp.isoformat() if location.timestamp else None,
            }
        except Exception as e:
            if has_app_context():
                current_app.logger.error(f"Failed to get latest rider location: {e}")
            return None

    @classmethod
    def get_location_history(cls, order_id: int, limit: int = 50) -> list[dict]:
        try:
            locations = (
                RiderLocation.query
                .filter_by(order_id=order_id)
                .order_by(RiderLocation.timestamp.desc())
                .limit(limit)
                .all()
            )
            return [
                {
                    "id": loc.id,
                    "riderId": loc.rider_id,
                    "latitude": float(loc.latitude),
                    "longitude": float(loc.longitude),
                    "timestamp": loc.timestamp.isoformat() if loc.timestamp else None,
                }
                for loc in reversed(locations)
            ]
        except Exception as e:
            if has_app_context():
                current_app.logger.error(f"Failed to get rider location history: {e}")
            return []
