export type ConversationStatus = "idle" | "running";

export interface BridgeEvent {
  id: string;
  eventType: string;
  conversationId: string;
  projectPath?: string;
  workspaceRoots: string[];
  status: string;
  summary: string;
  subagentType?: string;
  timestamp: string;
}

export interface BridgeConversation {
  id: string;
  title: string;
  projectPath?: string;
  workspaceID: string;
  isOpen: boolean;
  status: ConversationStatus;
  subtitle: string;
  mode: string;
  lastUpdated?: string;
}

export interface BridgeSnapshot {
  updatedAt: string;
  bridgeConnected: boolean;
  bridgePort: number;
  conversations: BridgeConversation[];
  events: BridgeEvent[];
}

interface ConversationRecord {
  id: string;
  status: ConversationStatus;
  projectPath?: string;
  workspaceRoots: string[];
  title: string;
  subtitle: string;
  mode: string;
  workspaceID: string;
  isOpen: boolean;
  activeSubagents: number;
  pendingToolUse: number;
  lastSummary: string;
  lastActivityMs: number;
  lastUpdatedMs?: number;
}

function iso(ms: number): string {
  return new Date(ms).toISOString();
}

function projectPathFromRoots(roots: string[] | undefined): string | undefined {
  if (!roots || roots.length === 0) {
    return undefined;
  }
  return roots[0];
}

export class StatusTracker {
  private conversations = new Map<string, ConversationRecord>();
  private pendingEvents: BridgeEvent[] = [];
  private eventCounter = 0;

  handleHookPayload(payload: Record<string, unknown>): void {
    const conversationId = asString(payload.conversation_id);
    if (!conversationId) {
      return;
    }

    const hookName =
      asString(payload.hook_event_name) ??
      asString(payload._event) ??
      asString(payload.event_type) ??
      "unknown";

    const record = this.ensureConversation(conversationId, payload);
    record.lastActivityMs = Date.now();

    const roots = asStringArray(payload.workspace_roots);
    if (roots.length > 0) {
      record.workspaceRoots = roots;
      record.projectPath = projectPathFromRoots(roots);
    }

    switch (hookName) {
      case "beforeSubmitPrompt":
      case "UserPromptSubmit":
      case "sessionStart":
        record.status = "running";
        record.pendingToolUse = 0;
        record.activeSubagents = 0;
        break;
      case "preToolUse":
      case "PreToolUse":
        record.status = "running";
        record.pendingToolUse += 1;
        break;
      case "postToolUse":
      case "PostToolUse":
        record.pendingToolUse = Math.max(0, record.pendingToolUse - 1);
        if (record.pendingToolUse > 0 || record.activeSubagents > 0) {
          record.status = "running";
        }
        break;
      case "postToolUseFailure":
        record.pendingToolUse = Math.max(0, record.pendingToolUse - 1);
        break;
      case "subagentStart":
      case "SubagentStart":
        record.status = "running";
        record.activeSubagents += 1;
        break;
      case "subagentStop":
      case "SubagentStop":
        record.activeSubagents = Math.max(0, record.activeSubagents - 1);
        this.enqueueEvent(record, "subagentStop", payload, asString(payload.subagent_type));
        if (record.pendingToolUse === 0 && record.activeSubagents === 0) {
          record.status = "idle";
        }
        break;
      case "afterAgentResponse":
      case "AfterAgentResponse":
        record.lastSummary = asString(payload.text) ?? record.lastSummary;
        break;
      case "stop":
      case "Stop":
        record.status = "idle";
        record.pendingToolUse = 0;
        record.activeSubagents = 0;
        this.enqueueEvent(record, "stop", payload, asString(payload.status) ?? "completed");
        break;
      default:
        break;
    }
  }

  applyComposerMeta(
    entries: Array<{
      id: string;
      title?: string;
      subtitle?: string;
      projectPath?: string;
      workspaceID?: string;
      mode?: string;
      isOpen?: boolean;
      lastUpdatedMs?: number;
    }>,
    succeeded: boolean
  ): void {
    if (!succeeded || entries.length === 0) {
      return;
    }

    for (const entry of entries) {
      const record = this.ensureConversation(entry.id, {});
      if (entry.title) {
        record.title = entry.title;
      }
      if (entry.subtitle !== undefined) {
        record.subtitle = entry.subtitle;
      }
      if (entry.projectPath) {
        record.projectPath = entry.projectPath;
      }
      if (entry.workspaceID) {
        record.workspaceID = entry.workspaceID;
      }
      if (entry.mode) {
        record.mode = entry.mode;
      }
      if (entry.isOpen !== undefined) {
        record.isOpen = entry.isOpen;
      }
      if (entry.lastUpdatedMs) {
        record.lastUpdatedMs = entry.lastUpdatedMs;
      }
    }
  }

  consumeSnapshot(port: number): BridgeSnapshot {
    const events = this.pendingEvents.splice(0, this.pendingEvents.length);
    return this.buildSnapshot(port, events);
  }

  peekSnapshot(port: number): BridgeSnapshot {
    return this.buildSnapshot(port, [...this.pendingEvents]);
  }

  private buildSnapshot(port: number, events: BridgeEvent[]): BridgeSnapshot {
    const conversations = [...this.conversations.values()]
      .sort((a, b) => b.lastActivityMs - a.lastActivityMs)
      .map((record) => this.toBridgeConversation(record));

    return {
      updatedAt: iso(Date.now()),
      bridgeConnected: true,
      bridgePort: port,
      conversations,
      events,
    };
  }

  private ensureConversation(id: string, payload: Record<string, unknown>): ConversationRecord {
    const existing = this.conversations.get(id);
    if (existing) {
      return existing;
    }

    const roots = asStringArray(payload.workspace_roots);
    const created: ConversationRecord = {
      id,
      status: "idle",
      projectPath: projectPathFromRoots(roots),
      workspaceRoots: roots,
      title: `对话 ${id.slice(0, 8)}`,
      subtitle: "",
      mode: asString(payload.composer_mode) ?? "agent",
      workspaceID: "",
      isOpen: true,
      activeSubagents: 0,
      pendingToolUse: 0,
      lastSummary: "",
      lastActivityMs: Date.now(),
    };
    this.conversations.set(id, created);
    return created;
  }

  private enqueueEvent(
    record: ConversationRecord,
    eventType: string,
    payload: Record<string, unknown>,
    status: string | undefined
  ): void {
    const summary =
      record.lastSummary ||
      asString(payload.text) ||
      asString(payload.final_message) ||
      asString(payload.summary) ||
      "";

    this.pendingEvents.push({
      id: `${Date.now()}-${++this.eventCounter}`,
      eventType,
      conversationId: record.id,
      projectPath: record.projectPath,
      workspaceRoots: record.workspaceRoots,
      status: status ?? "completed",
      summary,
      subagentType: asString(payload.subagent_type),
      timestamp: iso(Date.now()),
    });

    if (this.pendingEvents.length > 100) {
      this.pendingEvents.splice(0, this.pendingEvents.length - 100);
    }
  }

  private toBridgeConversation(record: ConversationRecord): BridgeConversation {
    return {
      id: record.id,
      title: record.title,
      projectPath: record.projectPath,
      workspaceID: record.workspaceID,
      isOpen: record.isOpen,
      status: record.status,
      subtitle: record.subtitle,
      mode: record.mode,
      lastUpdated: record.lastUpdatedMs ? iso(record.lastUpdatedMs) : iso(record.lastActivityMs),
    };
  }
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => (typeof item === "string" ? item.trim() : ""))
    .filter((item) => item.length > 0);
}
