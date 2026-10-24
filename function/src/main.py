import json
import logging
import re

import flask
import functions_framework

from . import config, handlers

logging.basicConfig(level=logging.INFO)

_ALERT = re.compile(r"^v1/alerts/([A-Za-z0-9_-]{1,64})$")
_ALERT_READ = re.compile(r"^v1/alerts/([A-Za-z0-9_-]{1,64})/read$")


@functions_framework.http
def handle_request(request: flask.Request):
    cfg = config.get()
    body, status = route(request, cfg)
    return json.dumps(body), status, {"Content-Type": "application/json"}


def route(request: flask.Request, cfg: config.Config) -> handlers.Response:
    endpoint = request.path.strip("/")
    method = request.method
    keys = cfg.get_keys()

    if endpoint == "v1/notify":
        if method != "POST":
            return _method_not_allowed()
        return handlers.notify(request, keys, cfg.store, cfg.sender)

    if endpoint == "v1/alerts":
        if method != "GET":
            return _method_not_allowed()
        return handlers.list_alerts(request, keys, cfg.store)

    if match := _ALERT.match(endpoint):
        if method != "GET":
            return _method_not_allowed()
        return handlers.get_alert(request, keys, cfg.store, match.group(1))

    if match := _ALERT_READ.match(endpoint):
        if method != "POST":
            return _method_not_allowed()
        return handlers.mark_read(request, keys, cfg.store, match.group(1))

    if endpoint == "v1/devices":
        if method != "POST":
            return _method_not_allowed()
        return handlers.register_device(request, keys, cfg.store)

    return {"error": "not found"}, 404


def _method_not_allowed() -> handlers.Response:
    return {"error": "method not allowed"}, 405
