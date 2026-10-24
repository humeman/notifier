from src.fcm import _is_unregistered


def test_unregistered_error_code():
    body = {"error": {"code": 404, "status": "NOT_FOUND", "details": [
        {"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", "errorCode": "UNREGISTERED"},
    ]}}
    assert _is_unregistered(404, body)


def test_invalid_token_argument():
    body = {"error": {"code": 400, "message": "The registration token is not a valid FCM registration token",
                      "details": [{"errorCode": "INVALID_ARGUMENT"}]}}
    assert _is_unregistered(400, body)


def test_other_errors_keep_the_token():
    assert not _is_unregistered(500, {"error": {"details": [{"errorCode": "INTERNAL"}]}})
    assert not _is_unregistered(400, {"error": {"message": "Invalid data payload",
                                                "details": [{"errorCode": "INVALID_ARGUMENT"}]}})
    assert not _is_unregistered(429, {})
