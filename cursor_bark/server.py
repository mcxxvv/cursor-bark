from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Callable

from cursor_bark.config import AppConfig, project_label
from cursor_bark.events import AgentEvent, parse_hook_payload

EventHandler = Callable[[AgentEvent], None]


class HookHTTPServer:
    def __init__(self, on_event: EventHandler) -> None:
        self._on_event = on_event
        self._server: ThreadingHTTPServer | None = None
        self._thread: threading.Thread | None = None

    def start(self, host: str, port: int) -> None:
        handler_cls = self._build_handler()
        self._server = ThreadingHTTPServer((host, port), handler_cls)
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._server = None
        self._thread = None

    @property
    def address(self) -> tuple[str, int] | None:
        if self._server is None:
            return None
        host, port = self._server.server_address[:2]
        return str(host), int(port)

    def _build_handler(self):
        on_event = self._on_event

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, format: str, *args) -> None:  # noqa: A003
                return

            def _send_json(self, status: int, payload: dict) -> None:
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self) -> None:  # noqa: N802
                if self.path == "/health":
                    self._send_json(200, {"ok": True, "service": "cursor-bark"})
                    return
                self._send_json(404, {"ok": False, "error": "not found"})

            def do_POST(self) -> None:  # noqa: N802
                if self.path not in {"/hook", "/event"}:
                    self._send_json(404, {"ok": False, "error": "not found"})
                    return

                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length).decode("utf-8", errors="replace")
                try:
                    payload = json.loads(raw) if raw else {}
                except json.JSONDecodeError:
                    self._send_json(400, {"ok": False, "error": "invalid json"})
                    return

                event_type = str(payload.pop("_event", payload.get("event_type", "stop")))
                source = str(payload.pop("_source", payload.get("source", "hook")))
                event = parse_hook_payload(payload, source=source, event_type=event_type)
                on_event(event)
                self._send_json(200, {"ok": True})

        return Handler


def build_notification(config: AppConfig, event: AgentEvent) -> tuple[str, str, str]:
    project = project_label(event.project_path)
    if event.is_subagent:
        title = f"Cursor 子任务完成 · {project}"
        subtitle = event.subagent_type or "subagent"
    else:
        title = f"Cursor 任务完成 · {project}"
        subtitle = event.status

    body_parts: list[str] = []
    if config.monitor.include_summary and event.summary:
        summary = event.summary
        if len(summary) > config.monitor.summary_max_chars:
            summary = summary[: config.monitor.summary_max_chars - 1] + "…"
        body_parts.append(summary)
    else:
        body_parts.append("Agent 已完成当前任务，可以回到 Cursor 查看结果。")

    if event.conversation_id:
        body_parts.append(f"会话: {event.conversation_id[:8]}")

    return title, subtitle, "\n".join(body_parts)
