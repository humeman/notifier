import logging
from enum import Enum
from typing import Protocol

import google.auth
from google.auth.transport.requests import AuthorizedSession

log = logging.getLogger(__name__)

SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


class SendResult(Enum):
    SENT = "sent"
    # The token is dead (app uninstalled, token rotated): drop it.
    UNREGISTERED = "unregistered"
    FAILED = "failed"


class Sender(Protocol):
    def send(self, token: str, data: dict[str, str]) -> SendResult: ...


class FcmSender:
    """Sends data-only, high-priority messages through the FCM HTTP v1 API.

    Data-only so the app draws the notification itself (consistent styling,
    per-level channels); high priority so Doze doesn't hold it back.
    """

    def __init__(self, project_id: str, ttl_seconds: int = 86400) -> None:
        credentials, _ = google.auth.default(scopes=[SCOPE])
        self._session = AuthorizedSession(credentials)
        self._url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        self._ttl = f"{ttl_seconds}s"

    def send(self, token: str, data: dict[str, str]) -> SendResult:
        body = {
            "message": {
                "token": token,
                "data": data,
                "android": {"priority": "HIGH", "ttl": self._ttl},
            }
        }
        try:
            res = self._session.post(self._url, json=body, timeout=10)
        except Exception:
            log.exception("FCM request failed")
            return SendResult.FAILED

        if res.ok:
            return SendResult.SENT
        if _is_unregistered(res.status_code, _json(res)):
            log.info("FCM token unregistered; dropping it")
            return SendResult.UNREGISTERED
        log.error("FCM send failed: %s %s", res.status_code, res.text[:500])
        return SendResult.FAILED


class LogSender:
    """Prints instead of sending. Used by `task run`, where there's no FCM."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, dict[str, str]]] = []

    def send(self, token: str, data: dict[str, str]) -> SendResult:
        self.sent.append((token, data))
        log.warning("[local] would push to %s…: %s", token[:12], data)
        return SendResult.SENT


def _is_unregistered(status: int, body: dict) -> bool:
    error = body.get("error", {})
    codes = {
        detail.get("errorCode")
        for detail in error.get("details", [])
        if isinstance(detail, dict)
    }
    if "UNREGISTERED" in codes:
        return True
    # A malformed token comes back as INVALID_ARGUMENT naming the token field.
    return (
        status == 400
        and "INVALID_ARGUMENT" in codes
        and "token" in str(error.get("message", "")).lower()
    )


def _json(res) -> dict:
    try:
        data = res.json()
        return data if isinstance(data, dict) else {}
    except ValueError:
        return {}
