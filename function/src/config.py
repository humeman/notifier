import os
import time

from .auth import Keys
from .fcm import FcmSender, LogSender, Sender
from .store import FirestoreStore, MemoryStore, Store


class Config:
    """Environment-driven wiring. Set by `task deploy`; see function/Taskfile.yml.

    NOTIFIER_LOCAL=1 swaps every cloud dependency for an in-process stand-in
    (memory store, logging sender, keys from NOTIFIER_KEYS_JSON) so the
    function runs under `task run` with no GCP access. Never set it in a deploy.
    """

    def __init__(self) -> None:
        self.local = os.getenv("NOTIFIER_LOCAL") == "1"
        self.retention_days = int(os.getenv("RETENTION_DAYS") or "90")
        self._cache_lifetime = int(os.getenv("CACHE_LIFETIME") or "300")

        if self.local:
            self.project_id = os.getenv("PROJECT_ID") or "local"
            self._keys_json = self._throw_if_null(
                os.getenv("NOTIFIER_KEYS_JSON"), "NOTIFIER_KEYS_JSON"
            )
            self.store: Store = MemoryStore()
            self.sender: Sender = LogSender()
        else:
            self.project_id = self._throw_if_null(os.getenv("PROJECT_ID"), "PROJECT_ID")
            self._keys_secret_name = self._throw_if_null(
                os.getenv("KEYS_SECRET_NAME"), "KEYS_SECRET_NAME"
            )
            self.store = FirestoreStore(
                self.project_id,
                self.retention_days,
                database=os.getenv("FIRESTORE_DATABASE") or "(default)",
            )
            self.sender = FcmSender(self.project_id)

        self._keys_cache: Keys | None = None
        self._keys_refreshed_at: float = 0

    def _throw_if_null(self, val: str | None, env_name: str) -> str:
        if val is None:
            raise ValueError(f"{env_name} must be set")
        return val

    def get_keys(self) -> Keys:
        """Cached for CACHE_LIFETIME seconds, so a rotated or added key takes
        effect within a few minutes without a redeploy."""
        now = time.time()
        if self._keys_cache is None or now - self._keys_refreshed_at > self._cache_lifetime:
            raw = self._keys_json if self.local else self._get_secret(self._keys_secret_name)
            self._keys_cache = Keys(raw)
            self._keys_refreshed_at = now
        return self._keys_cache

    def _get_secret(self, name: str) -> str:
        # Imported lazily: local runs and tests never need the client.
        from google.cloud.secretmanager import (
            AccessSecretVersionRequest,
            SecretManagerServiceClient,
        )

        request = AccessSecretVersionRequest(
            name=f"projects/{self.project_id}/secrets/{name}/versions/latest"
        )
        return (
            SecretManagerServiceClient()
            .access_secret_version(request=request)
            .payload.data.decode("utf-8")
        )


_config: Config | None = None


def get() -> Config:
    global _config
    if _config is None:
        _config = Config()
    return _config
