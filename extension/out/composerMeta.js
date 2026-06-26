"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadComposerSnapshot = loadComposerSnapshot;
const child_process_1 = require("child_process");
const fs = __importStar(require("fs"));
const os = __importStar(require("os"));
const path = __importStar(require("path"));
const SQLITE3 = fs.existsSync("/usr/bin/sqlite3") ? "/usr/bin/sqlite3" : "sqlite3";
function sqliteValue(dbPath, key) {
    if (!fs.existsSync(dbPath)) {
        return undefined;
    }
    try {
        const escapedKey = key.replace(/'/g, "''");
        const sql = `SELECT value FROM ItemTable WHERE key='${escapedKey}' LIMIT 1;`;
        const output = (0, child_process_1.execFileSync)(SQLITE3, [dbPath, sql], {
            encoding: "utf8",
            timeout: 5000,
            maxBuffer: 32 * 1024 * 1024,
        });
        const trimmed = output.trim();
        return trimmed.length > 0 ? trimmed : undefined;
    }
    catch {
        return undefined;
    }
}
function parseDateMs(json, key) {
    const value = json[key];
    return typeof value === "number" ? value : undefined;
}
function decodeProjectPath(uri) {
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
function loadComposerSnapshot() {
    try {
        const cursorUserDir = path.join(os.homedir(), "Library", "Application Support", "Cursor", "User");
        const openIDs = loadOpenComposerIDs(cursorUserDir);
        const headers = loadComposerHeaders(cursorUserDir);
        const entries = headers.map((header) => ({
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
    }
    catch (error) {
        return {
            entries: [],
            ok: false,
            error: error instanceof Error ? error.message : String(error),
        };
    }
}
function loadComposerHeaders(cursorUserDir) {
    const dbPath = path.join(cursorUserDir, "globalStorage", "state.vscdb");
    const jsonText = sqliteValue(dbPath, "composer.composerHeaders");
    if (!jsonText) {
        return [];
    }
    try {
        const parsed = JSON.parse(jsonText);
        const entries = [];
        for (const item of parsed.allComposers ?? []) {
            const id = item.composerId;
            if (typeof id !== "string") {
                continue;
            }
            if (item.isArchived === true || item.isDraft === true) {
                continue;
            }
            const workspace = item.workspaceIdentifier;
            const uri = workspace?.uri;
            entries.push({
                id,
                title: typeof item.name === "string" && item.name.trim().length > 0
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
    }
    catch {
        return [];
    }
}
function loadOpenComposerIDs(cursorUserDir) {
    const ids = new Set();
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
            const parsed = JSON.parse(jsonText);
            for (const id of parsed.selectedComposerIds ?? []) {
                ids.add(id);
            }
            for (const id of parsed.lastFocusedComposerIds ?? []) {
                ids.add(id);
            }
        }
        catch {
            // ignore malformed workspace db
        }
    }
    return ids;
}
//# sourceMappingURL=composerMeta.js.map