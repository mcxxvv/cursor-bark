from __future__ import annotations

import argparse
import signal
import subprocess
import sys
import time
from pathlib import Path

from cursor_bark import __version__
from cursor_bark.bark import send_notification
from cursor_bark.config import (
    APP_SUPPORT_DIR,
    CONFIG_PATH,
    AppConfig,
    open_config_in_editor,
    project_label,
)
from cursor_bark.events import AgentEvent
from cursor_bark.notify_macos import notify_macos
from cursor_bark.server import HookHTTPServer, build_notification
from cursor_bark.watcher import TranscriptWatcher


class CursorBarkDaemon:
    def __init__(self) -> None:
        self.config = AppConfig.load()
        self._server = HookHTTPServer(self.handle_event)
        self._watcher = TranscriptWatcher(self.handle_event)
        self._recent_keys: dict[str, float] = {}
        self._running = False

    def start(self) -> None:
        if not self.config.enabled:
            print("Cursor Bark is disabled in config.")
            return

        host = self.config.monitor.listen_host
        port = self.config.monitor.listen_port
        self._server.start(host, port)
        address = self._server.address
        print(f"Cursor Bark {__version__} listening on http://{address[0]}:{address[1]}")

        if self.config.monitor.watch_transcripts:
            self._watcher.start()
            print("Watching Cursor agent transcripts.")

        self._running = True
        signal.signal(signal.SIGINT, self._shutdown)
        signal.signal(signal.SIGTERM, self._shutdown)

        while self._running:
            time.sleep(1)
            refreshed = AppConfig.load()
            if refreshed.monitor.listen_port != self.config.monitor.listen_port:
                self.config = refreshed
                self.restart()

    def restart(self) -> None:
        self._server.stop()
        self._watcher.stop()
        self.config = AppConfig.load()
        host = self.config.monitor.listen_host
        port = self.config.monitor.listen_port
        self._server.start(host, port)
        if self.config.monitor.watch_transcripts:
            self._watcher.start()

    def _shutdown(self, *_args) -> None:
        self._running = False
        self._server.stop()
        self._watcher.stop()

    def handle_event(self, event: AgentEvent) -> None:
        self.config = AppConfig.load()
        if not self.config.is_ready():
            return

        if event.is_subagent and not self.config.monitor.notify_subagents:
            return

        status = event.status.lower()
        if status in {"failed", "error", "cancelled"} and not self.config.monitor.notify_on_error:
            return

        dedupe_key = "|".join(
            filter(
                None,
                [
                    event.event_type,
                    event.project_path or "",
                    event.conversation_id or "",
                    event.summary[:80],
                ],
            )
        )
        now = time.time()
        last = self._recent_keys.get(dedupe_key, 0)
        if now - last < 8:
            return
        self._recent_keys[dedupe_key] = now

        title, subtitle, body = build_notification(self.config, event)
        url = f"cursor://file/{event.project_path}" if event.project_path else ""

        result = send_notification(
            self.config,
            title=title,
            subtitle=subtitle,
            body=body,
            url=url,
        )

        log_path = APP_SUPPORT_DIR / "hook.log"
        APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(
                f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] "
                f"{event.event_type} {project_label(event.project_path)} "
                f"ok={result.ok} {result.message[:120]}\n"
            )

        if result.ok:
            notify_macos(title, subtitle, body)


def cmd_run(_: argparse.Namespace) -> None:
    CursorBarkDaemon().start()


def cmd_test(_: argparse.Namespace) -> None:
    config = AppConfig.load()
    result = send_notification(
        config,
        title="Cursor Bark 测试",
        subtitle="配置正常",
        body="如果你看到这条推送，说明 Bark 已连接成功。",
    )
    if result.ok:
        notify_macos("Cursor Bark", "测试成功", "Bark 推送已发送")
        print("ok")
    else:
        print(f"failed: {result.message}", file=sys.stderr)
        sys.exit(1)


def cmd_config(_: argparse.Namespace) -> None:
    open_config_in_editor()
    print(CONFIG_PATH)


def cmd_install_hooks(_: argparse.Namespace) -> None:
    script = Path(__file__).resolve().parents[1] / "scripts" / "install_hooks.sh"
    subprocess.run(["/bin/bash", str(script)], check=True)


def cmd_health(_: argparse.Namespace) -> None:
    config = AppConfig.load()
    import urllib.request

    url = f"http://{config.monitor.listen_host}:{config.monitor.listen_port}/health"
    try:
        with urllib.request.urlopen(url, timeout=2) as response:
            print(response.read().decode("utf-8"))
    except Exception as exc:
        print(f"unhealthy: {exc}", file=sys.stderr)
        sys.exit(1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="cursor-bark")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("run", help="Start background daemon").set_defaults(func=cmd_run)
    sub.add_parser("test", help="Send a Bark test notification").set_defaults(func=cmd_test)
    sub.add_parser("config", help="Open config file").set_defaults(func=cmd_config)
    sub.add_parser("install-hooks", help="Install Cursor user hooks").set_defaults(func=cmd_install_hooks)
    sub.add_parser("health", help="Check local daemon health").set_defaults(func=cmd_health)
    return parser


def main(argv: list[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
