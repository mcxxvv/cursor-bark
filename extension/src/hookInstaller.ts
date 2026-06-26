import * as fs from "fs";
import * as os from "os";
import * as path from "path";

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

export function installBridgeHooks(port: number): string {
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

function buildRelayScript(port: number): string {
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

function readHooksConfig(hooksFile: string): { version: number; hooks: Record<string, unknown[]> } {
  if (!fs.existsSync(hooksFile)) {
    return { version: 1, hooks: {} };
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(hooksFile, "utf8")) as {
      version?: number;
      hooks?: Record<string, unknown[]>;
    };
    return {
      version: parsed.version ?? 1,
      hooks: parsed.hooks ?? {},
    };
  } catch {
    return { version: 1, hooks: {} };
  }
}

function isManagedHook(entry: unknown): boolean {
  if (!entry || typeof entry !== "object") {
    return false;
  }
  const command = (entry as { command?: unknown }).command;
  return command === HOOK_COMMAND;
}
