import hashlib
import hmac
import json

import flask


class Keys:
    """Resolves bearer keys to identities.

    Parsed from the keys secret, which Terraform writes as:

        {"systems": {"<sha256 hex of key>": "<system name>", ...},
         "app": "<sha256 hex of the app key>"}

    Only hashes are stored, so reading the secret doesn't reveal any key.
    """

    def __init__(self, raw: str) -> None:
        data = json.loads(raw)
        self._systems: dict[str, str] = {
            digest.lower(): name for digest, name in data.get("systems", {}).items()
        }
        self._app: str | None = (data.get("app") or "").lower() or None

    def system_for(self, key: str | None) -> str | None:
        """The system name a sender key belongs to, or None if unknown."""
        if not key:
            return None
        return self._systems.get(_digest(key))

    def is_app(self, key: str | None) -> bool:
        if not key or self._app is None:
            return False
        return hmac.compare_digest(_digest(key), self._app)


def bearer(request: flask.Request) -> str | None:
    header = request.headers.get("Authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        return None
    return token.strip()


def _digest(key: str) -> str:
    return hashlib.sha256(key.encode("utf-8")).hexdigest()
