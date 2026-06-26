import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

export interface ComposerMetaEntry {
  id: string;
  title: string;
  subtitle: string;
  projectPath?: string;
  workspaceID: string;
  mode: string;
  isOpen: boolean;
  lastUpdatedMs?: number;
}

export interface ComposerSnapshotResult {
  entries: ComposerMetaEntry[];
  ok: boolean;
  error?: string;
}

const SQLITE3 = fs.existsSync("/usr/bin/sqlite3") ? "/usr/bin/sqlite3" : "sqlite3";

function sqliteValue(dbPath: string, key: string): string | undefined {
  if (!fs.existsSync(dbPath)) {
    return undefined;
  }
  try {
    const escapedKey = key.replace(/'/g, "''");
    const sql = `SELECT value FROM ItemTable WHERE key='${escapedKey}' LIMIT 1;`;
    const output = execFileSync(SQLITE3, [dbPath, sql], {
      encoding: "utf8",
      timeout: 5000,
      maxBuffer: 32 * 1024 * 1024,
    });
    const trimmed = output.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  } catch {
    return undefined;
  }
}

function parseDateMs(json: Record<string, unknown>, key: string): number | undefined {
  const value = json[key];
  return typeof value === "number" ? value : undefined;
}

function decodeProjectPath(uri: Record<string, unknown> | undefined): string | undefined {
  if (!uri) {
    return undefined;
  }
  if (typeof uri.fsPath === "string" && uri.fsPath.length > 0) {
    return uri.fsPath;
  }
  if (typeof uri.path === "string" && uri.path.length > 0) {
    return uri.path;
  }
  return undefined;
}

export function loadComposerSnapshot(): ComposerSnapshotResult {
  try {
    const cursorUserDir = path.join(
      os.homedir(),
      "Library",
      "Application Support",
      "Cursor",
      "User"
    );

    const openIDs = loadOpenComposerIDs(cursorUserDir);
    const headers = loadComposerHeaders(cursorUserDir);

    const entries: ComposerMetaEntry[] = headers.map((header) => ({
      ...header,
      isOpen: openIDs.has(header.id),
    }));

    for (const id of openIDs) {
      if (!entries.some((entry) => entry.id === id)) {
        entries.push({
          id,
          title: `对话 ${id.slice(0, 8)}`,
          subtitle: "",
          workspaceID: "",
          mode: "agent",
          isOpen: true,
        });
      }
    }

    const sorted = entries.sort((a, b) => (b.lastUpdatedMs ?? 0) - (a.lastUpdatedMs ?? 0));
    return { entries: sorted, ok: sorted.length > 0 || openIDs.size > 0 };
  } catch (error) {
    return {
      entries: [],
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

function loadComposerHeaders(cursorUserDir: string): Omit<ComposerMetaEntry, "isOpen">[] {
  const dbPath = path.join(cursorUserDir, "globalStorage", "state.vscdb");
  const jsonText = sqliteValue(dbPath, "composer.composerHeaders");
  if (!jsonText) {
    return [];
  }

  try {
    const parsed = JSON.parse(jsonText) as { allComposers?: Record<string, unknown>[] };
    const entries: Omit<ComposerMetaEntry, "isOpen">[] = [];

    for (const item of parsed.allComposers ?? []) {
      const id = item.composerId;
      if (typeof id !== "string") {
        continue;
      }
      if (item.isArchived === true || item.isDraft === true) {
        continue;
      }

      const workspace = item.workspaceIdentifier as Record<string, unknown> | undefined;
      const uri = workspace?.uri as Record<string, unknown> | undefined;
      entries.push({
        id,
        title:
          typeof item.name === "string" && item.name.trim().length > 0
            ? item.name.trim()
            : `对话 ${id.slice(0, 8)}`,
        subtitle: typeof item.subtitle === "string" ? item.subtitle : "",
        projectPath: decodeProjectPath(uri),
        workspaceID: typeof workspace?.id === "string" ? workspace.id : "",
        mode: typeof item.unifiedMode === "string" ? item.unifiedMode : "agent",
        lastUpdatedMs: parseDateMs(item, "lastUpdatedAt"),
      });
    }

    return entries;
  } catch {
    return [];
  }
}

function loadOpenComposerIDs(cursorUserDir: string): Set<string> {
  const ids = new Set<string>();
  const storageRoot = path.join(cursorUserDir, "workspaceStorage");
  if (!fs.existsSync(storageRoot)) {
    return ids;
  }

  for (const entry of fs.readdirSync(storageRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) {
      continue;
    }
    const dbPath = path.join(storageRoot, entry.name, "state.vscdb");
    const jsonText = sqliteValue(dbPath, "composer.composerData");
    if (!jsonText) {
      continue;
    }

    try {
      const parsed = JSON.parse(jsonText) as {
        selectedComposerIds?: string[];
        lastFocusedComposerIds?: string[];
      };
      for (const id of parsed.selectedComposerIds ?? []) {
        ids.add(id);
      }
      for (const id of parsed.lastFocusedComposerIds ?? []) {
        ids.add(id);
      }
    } catch {
      // ignore malformed workspace db
    }
  }

  return ids;
}
