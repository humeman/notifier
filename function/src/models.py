from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator

# Firestore documents cap out at 1 MiB; this leaves room for everything else.
MAX_DESCRIPTION_BYTES = 256 * 1024


class Level(StrEnum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"


class NotifyRequest(BaseModel):
    """Body of POST /v1/notify, as sent by a system.

    Unknown fields are rejected rather than ignored -- in particular `system`,
    which is always derived from the caller's key.
    """

    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=200)
    level: Level = Level.INFO
    description: str | None = None

    @field_validator("level", mode="before")
    @classmethod
    def _lowercase_level(cls, value: object) -> object:
        return value.lower() if isinstance(value, str) else value

    @field_validator("title")
    @classmethod
    def _strip_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("title must not be blank")
        return value

    @field_validator("description")
    @classmethod
    def _limit_description(cls, value: str | None) -> str | None:
        if value is not None and len(value.encode("utf-8")) > MAX_DESCRIPTION_BYTES:
            raise ValueError(f"description must be at most {MAX_DESCRIPTION_BYTES} bytes")
        return value or None


class RegisterDeviceRequest(BaseModel):
    """Body of POST /v1/devices, sent by the app with its FCM token."""

    model_config = ConfigDict(extra="forbid")

    token: str = Field(min_length=1, max_length=4096)


class Alert(BaseModel):
    id: str
    system: str
    level: Level
    title: str
    description: str | None = None
    received_at: datetime
    read: bool = False

    def summary(self) -> dict:
        """List-view shape: everything but the (possibly large) description."""
        data = self.model_dump(mode="json", exclude={"description"})
        data["has_description"] = self.description is not None
        return data

    def detail(self) -> dict:
        return self.model_dump(mode="json")

    def push_data(self) -> dict[str, str]:
        """The FCM data payload. Deliberately excludes the description: it can
        be large and sensitive, so the app fetches it over HTTPS on open."""
        return {
            "id": self.id,
            "system": self.system,
            "level": self.level.value,
            "title": self.title,
        }
