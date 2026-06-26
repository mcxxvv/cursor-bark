from __future__ import annotations

import subprocess


def notify_macos(title: str, subtitle: str, body: str) -> None:
    safe_title = title.replace('"', '\\"')
    safe_subtitle = subtitle.replace('"', '\\"')
    safe_body = body.replace('"', '\\"')
    script = (
        f'display notification "{safe_body}" '
        f'with title "{safe_title}" subtitle "{safe_subtitle}"'
    )
    subprocess.run(["osascript", "-e", script], check=False)
