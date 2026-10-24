import logging
import secrets
from datetime import datetime, timezone

import flask
from pydantic import ValidationError

from . import auth
from .auth import Keys
from .fcm import Sender, SendResult
from .models import Alert, NotifyRequest, RegisterDeviceRequest
from .store import Store

log = logging.getLogger(__name__)

DEFAULT_PAGE = 50
MAX_PAGE = 100

Response = tuple[dict, int]


def notify(request: flask.Request, keys: Keys, store: Store, sender: Sender) -> Response:
    """POST /v1/notify -- a system sends an alert.

    The alert is stored before any push goes out, so the app can always fetch
    what it's notified about. Push failures don't fail the request: the alert
    is recorded either way, and the counts in the response say how it went.
    """
    system = keys.system_for(auth.bearer(request))
    if system is None:
        return _error("invalid or missing key", 401)

    body, error = _parse(request, NotifyRequest)
    if error:
        return error

    alert = Alert(
        id=secrets.token_hex(10),
        system=system,
        level=body.level,
        title=body.title,
        description=body.description,
        received_at=datetime.now(timezone.utc),
    )
    store.add_alert(alert)

    tokens = store.device_tokens()
    delivered = 0
    for token in tokens:
        result = sender.send(token, alert.push_data())
        if result is SendResult.SENT:
            delivered += 1
        elif result is SendResult.UNREGISTERED:
            store.remove_device(token)

    log.info(
        "alert %s from %s (%s): delivered to %d/%d devices",
        alert.id, system, alert.level.value, delivered, len(tokens),
    )
    return {
        "id": alert.id,
        "system": system,
        "level": alert.level.value,
        "devices": len(tokens),
        "delivered": delivered,
    }, 200


def list_alerts(request: flask.Request, keys: Keys, store: Store) -> Response:
    """GET /v1/alerts?limit=&before= -- newest first, without descriptions.

    Paginate by passing the previous page's `next_before` as `before`.
    """
    if not keys.is_app(auth.bearer(request)):
        return _error("invalid or missing key", 401)

    try:
        limit = int(request.args.get("limit", DEFAULT_PAGE))
    except ValueError:
        return _error("limit must be an integer", 400)
    limit = max(1, min(limit, MAX_PAGE))

    before = None
    if raw := request.args.get("before"):
        try:
            before = datetime.fromisoformat(raw)
        except ValueError:
            return _error("before must be an ISO 8601 timestamp", 400)
        if before.tzinfo is None:
            before = before.replace(tzinfo=timezone.utc)

    alerts = store.list_alerts(limit, before)
    next_before = alerts[-1].received_at.isoformat() if len(alerts) == limit else None
    return {"alerts": [a.summary() for a in alerts], "next_before": next_before}, 200


def get_alert(request: flask.Request, keys: Keys, store: Store, alert_id: str) -> Response:
    """GET /v1/alerts/<id> -- full alert including its description."""
    if not keys.is_app(auth.bearer(request)):
        return _error("invalid or missing key", 401)

    alert = store.get_alert(alert_id)
    if alert is None:
        return _error("not found", 404)
    return alert.detail(), 200


def mark_read(request: flask.Request, keys: Keys, store: Store, alert_id: str) -> Response:
    """POST /v1/alerts/<id>/read"""
    if not keys.is_app(auth.bearer(request)):
        return _error("invalid or missing key", 401)

    if not store.mark_read(alert_id):
        return _error("not found", 404)
    return {"id": alert_id, "read": True}, 200


def register_device(request: flask.Request, keys: Keys, store: Store) -> Response:
    """POST /v1/devices -- the app registers (or refreshes) its FCM token."""
    if not keys.is_app(auth.bearer(request)):
        return _error("invalid or missing key", 401)

    body, error = _parse(request, RegisterDeviceRequest)
    if error:
        return error

    store.add_device(body.token)
    return {"registered": True}, 200


def _parse[T](request: flask.Request, model: type[T]) -> tuple[T | None, Response | None]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return None, _error("body must be a JSON object", 400)
    try:
        return model.model_validate(payload), None
    except ValidationError as e:
        details = [
            {"field": ".".join(str(p) for p in err["loc"]) or None, "error": err["msg"]}
            for err in e.errors()
        ]
        return None, ({"error": "invalid request", "details": details}, 400)


def _error(message: str, status: int) -> Response:
    return {"error": message}, status
