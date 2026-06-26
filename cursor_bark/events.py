from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any


@dataclass
class AgentEvent:
    source: str
    event_type: str
    project_path: str | None
    workspace_roots: list[str]
    status: str
    summary: str
    conversation_id: str | None
    subagent_type: str | None
    raw: dict[str, Any]

    @property
    def is_subagent(self) -> bool:
        return self.event_type in {"subagentStop", "subagentComplete"}


def _first_str(data: dict[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _workspace_roots(data: dict[str, Any]) -> list[str]:
    roots: list[str] = []
    for key in ("workspace_roots", "workspaceRoots", "roots"):
        value = data.get(key)
        if isinstance(value, list):
            roots.extend(str(item).strip() for item in value if str(item).strip())
    single = _first_str(data, "workspace_root", "workspaceRoot", "project_path", "projectPath", "cwd")
    if single and single not in roots:
        roots.insert(0, single)
    return roots


def _extract_summary(data: dict[str, Any]) -> str:
    for key in (
        "final_message",
        "finalMessage",
        "assistant_message",
        "assistantMessage",
        "response",
        "message",
        "summary",
        "result",
    ):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return _clean_text(value)
        if isinstance(value, dict):
            nested = value.get("text") or value.get("content")
            if isinstance(nested, str) and nested.strip():
                return _clean_text(nested)
            if isinstance(nested, list):
                parts = []
                for item in nested:
                    if isinstance(item, dict) and item.get("type") == "text":
                        text = item.get("text")
                        if isinstance(text, str) and text.strip():
                            parts.append(text.strip())
                if parts:
                    return _clean_text("\n".join(parts))
    return ""


def _clean_text(text: str) -> str:
    text = re.sub(r"<user_query>\s*", "", text)
    text = re.sub(r"</user_query>", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def parse_hook_payload(payload: dict[str, Any], *, source: str, event_type: str) -> AgentEvent:
    roots = _workspace_roots(payload)
    project_path = roots[0] if roots else None
    status = _first_str(payload, "status", "run_status", "runStatus") or "completed"
    summary = _extract_summary(payload)
    return AgentEvent(
        source=source,
        event_type=event_type,
        project_path=project_path,
        workspace_roots=roots,
        status=status,
        summary=summary,
        conversation_id=_first_str(payload, "conversation_id", "conversationId", "session_id", "sessionId"),
        subagent_type=_first_str(payload, "subagent_type", "subagentType", "agent_type", "agentType"),
        raw=payload,
    )


def parse_transcript_line(line: str) -> AgentEvent | None:
    try:
        record = json.loads(line)
    except json.JSONDecodeError:
        return None

    if record.get("role") != "assistant":
        return None

    message = record.get("message") or {}
    content = message.get("content")
    if not isinstance(content, list):
        return None

    text_parts: list[str] = []
    has_tool_use = False
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "tool_use":
            has_tool_use = True
        if block.get("type") == "text":
            text = block.get("text")
            if isinstance(text, str) and text.strip():
                text_parts.append(text.strip())

    if has_tool_use or not text_parts:
        return None

    summary = _clean_text("\n".join(text_parts))
    return AgentEvent(
        source="transcript",
        event_type="assistantReply",
        project_path=None,
        workspace_roots=[],
        status="completed",
        summary=summary,
        conversation_id=None,
        subagent_type=None,
        raw=record,
    )
