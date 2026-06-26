from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass

from cursor_bark.config import AppConfig


@dataclass
class BarkResult:
    ok: bool
    message: str
    status_code: int | None = None


def _base_url(config: AppConfig) -> str:
    return config.bark.server_url.rstrip("/")


def send_notification(
    config: AppConfig,
    *,
    title: str,
    body: str,
    subtitle: str = "",
    url: str = "",
    dry_run: bool = False,
) -> BarkResult:
    if not config.bark.device_key.strip():
        return BarkResult(ok=False, message="未配置 Bark Device Key")

    payload = {
        "device_key": config.bark.device_key.strip(),
        "title": title,
        "body": body,
    }
    if subtitle:
        payload["subtitle"] = subtitle
    if config.bark.group:
        payload["group"] = config.bark.group
    if config.bark.level:
        payload["level"] = config.bark.level
    if config.bark.sound:
        payload["sound"] = config.bark.sound
    if config.bark.icon:
        payload["icon"] = config.bark.icon
    if url:
        payload["url"] = url

    if dry_run:
        return BarkResult(ok=True, message=json.dumps(payload, ensure_ascii=False))

    endpoint = f"{_base_url(config)}/push"
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            raw = response.read().decode("utf-8", errors="replace")
            return BarkResult(
                ok=200 <= response.status < 300,
                message=raw,
                status_code=response.status,
            )
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        return BarkResult(
            ok=False,
            message=detail or str(exc),
            status_code=exc.code,
        )
    except urllib.error.URLError as exc:
        return BarkResult(ok=False, message=str(exc.reason or exc))
