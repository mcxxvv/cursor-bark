from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path

APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "CursorBark"
CONFIG_PATH = APP_SUPPORT_DIR / "config.json"
STATE_PATH = APP_SUPPORT_DIR / "state.json"


@dataclass
class BarkSettings:
    device_key: str = ""
    server_url: str = "https://api.day.app"
    group: str = "Cursor"
    level: str = "timeSensitive"
    sound: str = ""
    icon: str = ""


@dataclass
class MonitorSettings:
    listen_host: str = "127.0.0.1"
    listen_port: int = 8765
    watch_transcripts: bool = True
    notify_subagents: bool = True
    notify_on_error: bool = False
    include_summary: bool = True
    summary_max_chars: int = 180


@dataclass
class AppConfig:
    bark: BarkSettings = field(default_factory=BarkSettings)
    monitor: MonitorSettings = field(default_factory=MonitorSettings)
    enabled: bool = True

    @classmethod
    def load(cls) -> AppConfig:
        APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
        if not CONFIG_PATH.exists():
            config = cls()
            config.save()
            return config

        data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        bark = BarkSettings(**data.get("bark", {}))
        monitor = MonitorSettings(**data.get("monitor", {}))
        return cls(
            bark=bark,
            monitor=monitor,
            enabled=data.get("enabled", True),
        )

    def save(self) -> None:
        APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
        payload = {
            "enabled": self.enabled,
            "bark": asdict(self.bark),
            "monitor": asdict(self.monitor),
        }
        CONFIG_PATH.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    def is_ready(self) -> bool:
        return bool(self.enabled and self.bark.device_key.strip())


def load_state() -> dict:
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_state(state: dict) -> None:
    APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(
        json.dumps(state, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def project_label(project_path: str | None) -> str:
    if not project_path:
        return "Cursor"
    return Path(project_path).name or project_path


def open_config_in_editor() -> None:
    config = AppConfig.load()
    config.save()
    os.system(f'open "{CONFIG_PATH}"')
