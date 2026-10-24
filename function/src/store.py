import hashlib
from datetime import datetime, timedelta, timezone
from typing import Protocol

from google.cloud import firestore

from .models import Alert

ALERTS = "alerts"
DEVICES = "devices"


class Store(Protocol):
    def add_alert(self, alert: Alert) -> None: ...
    def get_alert(self, alert_id: str) -> Alert | None: ...
    def list_alerts(self, limit: int, before: datetime | None) -> list[Alert]: ...
    def mark_read(self, alert_id: str) -> bool: ...
    def device_tokens(self) -> list[str]: ...
    def add_device(self, token: str) -> None: ...
    def remove_device(self, token: str) -> None: ...


class FirestoreStore:
    """Alerts and device tokens in Firestore (Native mode).

    Each alert carries an `expire_at` timestamp; a TTL policy on that field
    (set up in Terraform) deletes alerts once they pass retention.
    """

    def __init__(self, project_id: str, retention_days: int, database: str = "(default)") -> None:
        self._db = firestore.Client(project=project_id, database=database)
        self._retention = timedelta(days=retention_days)

    def add_alert(self, alert: Alert) -> None:
        data = alert.model_dump(exclude={"id"})
        data["level"] = alert.level.value
        data["expire_at"] = alert.received_at + self._retention
        self._db.collection(ALERTS).document(alert.id).set(data)

    def get_alert(self, alert_id: str) -> Alert | None:
        snap = self._db.collection(ALERTS).document(alert_id).get()
        return _to_alert(snap) if snap.exists else None

    def list_alerts(self, limit: int, before: datetime | None) -> list[Alert]:
        query = self._db.collection(ALERTS).order_by(
            "received_at", direction=firestore.Query.DESCENDING
        )
        if before is not None:
            query = query.where(filter=firestore.FieldFilter("received_at", "<", before))
        return [_to_alert(snap) for snap in query.limit(limit).stream()]

    def mark_read(self, alert_id: str) -> bool:
        ref = self._db.collection(ALERTS).document(alert_id)
        if not ref.get().exists:
            return False
        ref.update({"read": True})
        return True

    def device_tokens(self) -> list[str]:
        return [snap.get("token") for snap in self._db.collection(DEVICES).stream()]

    def add_device(self, token: str) -> None:
        now = datetime.now(timezone.utc)
        self._db.collection(DEVICES).document(_device_id(token)).set(
            {"token": token, "updated_at": now}
        )

    def remove_device(self, token: str) -> None:
        self._db.collection(DEVICES).document(_device_id(token)).delete()


class MemoryStore:
    """In-process store for tests and `task run`."""

    def __init__(self) -> None:
        self.alerts: dict[str, Alert] = {}
        self.devices: set[str] = set()

    def add_alert(self, alert: Alert) -> None:
        self.alerts[alert.id] = alert

    def get_alert(self, alert_id: str) -> Alert | None:
        return self.alerts.get(alert_id)

    def list_alerts(self, limit: int, before: datetime | None) -> list[Alert]:
        alerts = sorted(self.alerts.values(), key=lambda a: a.received_at, reverse=True)
        if before is not None:
            alerts = [a for a in alerts if a.received_at < before]
        return alerts[:limit]

    def mark_read(self, alert_id: str) -> bool:
        alert = self.alerts.get(alert_id)
        if alert is None:
            return False
        self.alerts[alert_id] = alert.model_copy(update={"read": True})
        return True

    def device_tokens(self) -> list[str]:
        return sorted(self.devices)

    def add_device(self, token: str) -> None:
        self.devices.add(token)

    def remove_device(self, token: str) -> None:
        self.devices.discard(token)


def _device_id(token: str) -> str:
    # Tokens are long and contain ':' -- hash them into a stable document ID
    # so re-registering the same token is an overwrite, not a duplicate.
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _to_alert(snap: firestore.DocumentSnapshot) -> Alert:
    data = snap.to_dict() or {}
    data.pop("expire_at", None)
    return Alert(id=snap.id, **data)
