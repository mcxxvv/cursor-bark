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
exports.installBridgeHooks = installBridgeHooks;
const fs = __importStar(require("fs"));
const os = __importStar(require("os"));
const path = __importStar(require("path"));
const HOOK_COMMAND = "./hooks/cursor-bark-bridge-relay.sh";
const MANAGED_EVENTS = [
    "beforeSubmitPrompt",
    "preToolUse",
    "postToolUse",
    "subagentStart",
    "subagentStop",
    "afterAgentResponse",
    "stop",
];
function installBridgeHooks(port) {
    const cursorDir = path.join(os.homedir(), ".cursor");
    const hooksDir = path.join(cursorDir, "hooks");
    fs.mkdirSync(hooksDir, { recursive: true });
    const relayScript = path.join(hooksDir, "cursor-bark-bridge-relay.sh");
    fs.writeFileSync(relayScript, buildRelayScript(port), { mode: 0o755 });
    const hooksFile = path.join(cursorDir, "hooks.json");
    const config = readHooksConfig(hooksFile);
    const commandEntry = { command: HOOK_COMMAND };
    for (const eventName of MANAGED_EVENTS) {
        const current = Array.isArray(config.hooks[eventName]) ? config.hooks[eventName] : [];
        const filtered = current.filter((entry) => !isManagedHook(entry));
        config.hooks[eventName] = [commandEntry, ...filtered];
    }
    fs.writeFileSync(hooksFile, `${JSON.stringify(config, null, 2)}\n`, "utf8");
    return hooksFile;
}
function buildRelayScript(port) {
    return `#!/bin/bash
set -euo pipefail

INPUT="$(cat)"
PORT="${port}"
HOST="127.0.0.1"

curl -sS -o /dev/null -w "" \\
  -X POST "http://\${HOST}:\${PORT}/event" \\
  -H "Content-Type: application/json; charset=utf-8" \\
  --data-binary "$INPUT" \\
  --connect-timeout 1 \\
  --max-time 3 || true

echo '{}'
exit 0
`;
}
function readHooksConfig(hooksFile) {
    if (!fs.existsSync(hooksFile)) {
        return { version: 1, hooks: {} };
    }
    try {
        const parsed = JSON.parse(fs.readFileSync(hooksFile, "utf8"));
        return {
            version: parsed.version ?? 1,
            hooks: parsed.hooks ?? {},
        };
    }
    catch {
        return { version: 1, hooks: {} };
    }
}
function isManagedHook(entry) {
    if (!entry || typeof entry !== "object") {
        return false;
    }
    const command = entry.command;
    return command === HOOK_COMMAND;
}
//# sourceMappingURL=hookInstaller.js.map