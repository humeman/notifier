from datetime import datetime, timedelta, timezone

from src.fcm import SendResult
from src.models import MAX_DESCRIPTION_BYTES, Alert, Level
from tests.conftest import APP_KEY


def notify(call, key="homelab-key", **body):
    body.setdefault("title", "Service jellyfin.service has failed")
    return call("POST", "/v1/notify", key=key, json=body)


class TestNotify:
    def test_system_comes_from_the_key(self, call, cfg):
        body, status = notify(call, key="backups-key")
        assert status == 200
        assert body["system"] == "backups"
        assert cfg.store.get_alert(body["id"]).system == "backups"

    def test_defaults_to_info(self, call):
        body, _ = notify(call)
        assert body["level"] == "info"

    def test_level_is_case_insensitive(self, call):
        body, status = notify(call, level="ERROR")
        assert status == 200
        assert body["level"] == "error"

    def test_stores_description(self, call, cfg):
        body, _ = notify(call, level="error", description="Traceback ...")
        stored = cfg.store.get_alert(body["id"])
        assert stored.level is Level.ERROR
        assert stored.description == "Traceback ..."

    def test_rejects_unknown_key(self, call, cfg):
        _, status = notify(call, key="nope")
        assert status == 401
        assert cfg.store.alerts == {}

    def test_rejects_missing_key(self, call):
        _, status = notify(call, key=None)
        assert status == 401

    def test_app_key_cannot_send(self, call):
        _, status = notify(call, key=APP_KEY)
        assert status == 401

    def test_rejects_system_field(self, call):
        body, status = notify(call, system="spoofed")
        assert status == 400
        assert body["details"][0]["field"] == "system"

    def test_rejects_bad_level(self, call):
        _, status = notify(call, level="critical")
        assert status == 400

    def test_rejects_blank_title(self, call):
        _, status = notify(call, title="   ")
        assert status == 400

    def test_rejects_oversized_description(self, call):
        _, status = notify(call, description="x" * (MAX_DESCRIPTION_BYTES + 1))
        assert status == 400

    def test_rejects_non_json(self, call):
        _, status = call("POST", "/v1/notify", key="homelab-key", data="hi")
        assert status == 400

    def test_pushes_to_every_device_without_description(self, call, cfg):
        cfg.store.add_device("tok-a")
        cfg.store.add_device("tok-b")
        body, _ = notify(call, level="warning", description="secret log")

        assert body["devices"] == 2
        assert body["delivered"] == 2
        assert {t for t, _ in cfg.sender.sent} == {"tok-a", "tok-b"}
        data = cfg.sender.sent[0][1]
        assert data == {
            "id": body["id"],
            "system": "homelab",
            "level": "warning",
            "title": "Service jellyfin.service has failed",
        }

    def test_drops_unregistered_tokens(self, call, cfg):
        cfg.store.add_device("live")
        cfg.store.add_device("dead")
        cfg.sender.results["dead"] = SendResult.UNREGISTERED
        body, _ = notify(call)

        assert body["delivered"] == 1
        assert cfg.store.device_tokens() == ["live"]

    def test_push_failure_still_records_alert(self, call, cfg):
        cfg.store.add_device("tok")
        cfg.sender.results["tok"] = SendResult.FAILED
        body, status = notify(call)

        assert status == 200
        assert body["delivered"] == 0
        assert cfg.store.get_alert(body["id"]) is not None
        assert cfg.store.device_tokens() == ["tok"]

    def test_get_not_allowed(self, call):
        _, status = call("GET", "/v1/notify", key="homelab-key")
        assert status == 405


class TestAppEndpoints:
    def _seed(self, cfg, n):
        base = datetime(2026, 10, 24, 12, tzinfo=timezone.utc)
        for i in range(n):
            cfg.store.add_alert(Alert(
                id=f"a{i}", system="homelab", level=Level.INFO, title=f"alert {i}",
                description="details" if i % 2 else None,
                received_at=base + timedelta(minutes=i),
            ))

    def test_requires_app_key(self, call):
        for method, path in [
            ("GET", "/v1/alerts"),
            ("GET", "/v1/alerts/a0"),
            ("POST", "/v1/alerts/a0/read"),
        ]:
            assert call(method, path, key="homelab-key")[1] == 401
            assert call(method, path)[1] == 401
        assert call("POST", "/v1/devices", key="homelab-key", json={"token": "t"})[1] == 401

    def test_list_is_newest_first_without_descriptions(self, call, cfg):
        self._seed(cfg, 3)
        body, status = call("GET", "/v1/alerts", key=APP_KEY)

        assert status == 200
        assert [a["id"] for a in body["alerts"]] == ["a2", "a1", "a0"]
        assert all("description" not in a for a in body["alerts"])
        assert [a["has_description"] for a in body["alerts"]] == [False, True, False]
        assert body["next_before"] is None

    def test_list_paginates(self, call, cfg):
        self._seed(cfg, 5)
        first, _ = call("GET", "/v1/alerts", key=APP_KEY, query={"limit": 2})
        assert [a["id"] for a in first["alerts"]] == ["a4", "a3"]

        second, _ = call(
            "GET", "/v1/alerts", key=APP_KEY,
            query={"limit": 2, "before": first["next_before"]},
        )
        assert [a["id"] for a in second["alerts"]] == ["a2", "a1"]

    def test_list_rejects_bad_params(self, call):
        assert call("GET", "/v1/alerts", key=APP_KEY, query={"limit": "x"})[1] == 400
        assert call("GET", "/v1/alerts", key=APP_KEY, query={"before": "yesterday"})[1] == 400

    def test_get_includes_description(self, call, cfg):
        self._seed(cfg, 2)
        body, status = call("GET", "/v1/alerts/a1", key=APP_KEY)
        assert status == 200
        assert body["description"] == "details"

    def test_get_missing(self, call):
        assert call("GET", "/v1/alerts/nope", key=APP_KEY)[1] == 404

    def test_mark_read(self, call, cfg):
        self._seed(cfg, 1)
        assert call("POST", "/v1/alerts/a0/read", key=APP_KEY)[1] == 200
        assert cfg.store.get_alert("a0").read is True
        assert call("POST", "/v1/alerts/nope/read", key=APP_KEY)[1] == 404

    def test_register_device_is_idempotent(self, call, cfg):
        for _ in range(2):
            body, status = call("POST", "/v1/devices", key=APP_KEY, json={"token": "fcm-tok"})
            assert status == 200
        assert cfg.store.device_tokens() == ["fcm-tok"]

    def test_unknown_path(self, call):
        assert call("GET", "/v1/nope", key=APP_KEY)[1] == 404
