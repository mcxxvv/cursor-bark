from __future__ import annotations

import time
from pathlib import Path

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from cursor_bark.config import load_state, save_state
from cursor_bark.events import AgentEvent, parse_transcript_line

CURSOR_PROJECTS_DIR = Path.home() / ".cursor" / "projects"


class TranscriptWatcher:
    def __init__(self, on_event) -> None:
        self._on_event = on_event
        self._observer: Observer | None = None
        self._poll_timer: object | None = None
        self._state = load_state()
        self._seen: dict[str, int] = {
            str(key): int(value)
            for key, value in self._state.setdefault("seen_transcript_events", {}).items()
        }
        self._last_notified_line: dict[str, int] = {
            str(key): int(value)
            for key, value in self._state.setdefault("last_notified_line_index", {}).items()
        }

    def start(self) -> None:
        if self._observer is not None:
            return
        CURSOR_PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
        self._bootstrap_existing_files()
        handler = _TranscriptHandler(self._handle_file)
        self._observer = Observer()
        self._observer.schedule(handler, str(CURSOR_PROJECTS_DIR), recursive=True)
        self._observer.start()

        import threading

        def poll_loop() -> None:
            while self._observer is not None:
                for path in CURSOR_PROJECTS_DIR.rglob("*.jsonl"):
                    self._handle_file(path)
                time.sleep(2)

        self._poll_timer = threading.Thread(target=poll_loop, daemon=True)
        self._poll_timer.start()

    def stop(self) -> None:
        if self._observer is None:
            return
        self._observer.stop()
        self._observer.join(timeout=2)
        self._observer = None
        save_state(self._state)

    def _bootstrap_existing_files(self) -> None:
        for path in CURSOR_PROJECTS_DIR.rglob("*.jsonl"):
            key = str(path)
            lines = self._read_lines(path)
            self._seen[key] = path.stat().st_size if path.exists() else 0
            self._last_notified_line[key] = self._last_non_empty_line_index(lines)
        self._state["seen_transcript_events"] = self._seen
        self._state["last_notified_line_index"] = self._last_notified_line
        save_state(self._state)

    def _handle_file(self, path: Path) -> None:
        if path.suffix != ".jsonl" or not path.exists():
            return

        key = str(path)
        size = path.stat().st_size
        previous_size = int(self._seen.get(key, 0))
        if size < previous_size:
            self._seen[key] = 0
            self._last_notified_line[key] = -1

        lines = self._read_lines(path)
        last_index = self._last_non_empty_line_index(lines)
        if last_index is None:
            self._seen[key] = size
            return

        already_notified = int(self._last_notified_line.get(key, -1))
        if last_index <= already_notified:
            self._seen[key] = size
            return

        event = parse_transcript_line(lines[last_index])
        if event is None:
            self._seen[key] = size
            return

        event.project_path = self._project_path_from_transcript(path)
        event.conversation_id = self._conversation_id_from_transcript(path)
        self._last_notified_line[key] = last_index
        self._seen[key] = size
        self._state["seen_transcript_events"] = self._seen
        self._state["last_notified_line_index"] = self._last_notified_line
        save_state(self._state)
        self._on_event(event)

    @staticmethod
    def _read_lines(path: Path) -> list[str]:
        try:
            return path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            return []

    @staticmethod
    def _last_non_empty_line_index(lines: list[str]) -> int | None:
        for index in range(len(lines) - 1, -1, -1):
            if lines[index].strip():
                return index
        return None

    @staticmethod
    def _project_path_from_transcript(path: Path) -> str | None:
        parts = path.parts
        try:
            projects_index = parts.index("projects")
        except ValueError:
            return None
        if projects_index + 1 >= len(parts):
            return None
        encoded = parts[projects_index + 1]
        return _decode_cursor_project_path(encoded)

    @staticmethod
    def _conversation_id_from_transcript(path: Path) -> str | None:
        parts = path.parts
        try:
            transcripts_index = parts.index("agent-transcripts")
        except ValueError:
            return None
        if transcripts_index + 1 >= len(parts):
            return None
        return parts[transcripts_index + 1]


class _TranscriptHandler(FileSystemEventHandler):
    def __init__(self, callback) -> None:
        super().__init__()
        self._callback = callback
        self._last_run: dict[str, float] = {}

    def on_modified(self, event) -> None:
        if event.is_directory:
            return
        path = Path(event.src_path)
        now = time.time()
        last = self._last_run.get(str(path), 0)
        if now - last < 0.4:
            return
        self._last_run[str(path)] = now
        self._callback(path)

    def on_created(self, event) -> None:
        self.on_modified(event)


def _decode_cursor_project_path(encoded: str) -> str:
    if encoded.startswith("Users-"):
        rest = encoded[len("Users-") :]
        return "/" + rest.replace("-", "/")
    return encoded.replace("-", "/")
