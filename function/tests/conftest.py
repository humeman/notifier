import hashlib
import json
from types import SimpleNamespace

import flask
import pytest

from src.auth import Keys
from src.fcm import SendResult
from src.main import route
from src.store import MemoryStore

SYSTEM_KEYS = {"homelab-key": "homelab", "backups-key": "backups"}
APP_KEY = "app-key"


def _sha(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


class ScriptedSender:
    """Records sends; returns per-token results from `results` (default SENT)."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, dict]] = []
        self.results: dict[str, SendResult] = {}

    def send(self, token, data):
        self.sent.append((token, data))
        return self.results.get(token, SendResult.SENT)


@pytest.fixture
def keys():
    return Keys(json.dumps({
        "systems": {_sha(k): name for k, name in SYSTEM_KEYS.items()},
        "app": _sha(APP_KEY),
    }))


@pytest.fixture
def cfg(keys):
    return SimpleNamespace(store=MemoryStore(), sender=ScriptedSender(), get_keys=lambda: keys)


@pytest.fixture
def call(cfg):
    """call(method, path, key=None, json=None, query=None) -> (body, status)"""
    app = flask.Flask(__name__)

    def _call(method, path, key=None, json=None, query=None, data=None):
        headers = {"Authorization": f"Bearer {key}"} if key else {}
        with app.test_request_context(
            path, method=method, headers=headers, json=json, query_string=query, data=data
        ):
            return route(flask.request, cfg)

    return _call
