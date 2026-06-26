import * as http from "http";
import { BridgeSnapshot, StatusTracker } from "./statusTracker";

export class StatusServer {
  private server?: http.Server;
  private readonly tracker: StatusTracker;
  private port = 8766;
  private host = "127.0.0.1";

  constructor(tracker: StatusTracker) {
    this.tracker = tracker;
  }

  get listeningPort(): number {
    return this.port;
  }

  get listeningHost(): string {
    return this.host;
  }

  async start(host: string, port: number): Promise<"started" | "attached"> {
    await this.stop();
    this.port = port;
    this.host = host;

    try {
      await this.listen(host, port);
      return "started";
    } catch (error) {
      if (isAddrInUse(error) && (await probeBridge(host, port))) {
        return "attached";
      }
      throw error;
    }
  }

  async stop(): Promise<void> {
    const current = this.server;
    this.server = undefined;
    if (!current) {
      return;
    }

    await new Promise<void>((resolve) => {
      current.close(() => resolve());
      if (typeof (current as http.Server & { closeAllConnections?: () => void }).closeAllConnections === "function") {
        (current as http.Server & { closeAllConnections: () => void }).closeAllConnections();
      }
    });
  }

  private listen(host: string, port: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const server = http.createServer((req, res) => {
        this.handleRequest(req, res);
      });

      const onError = (error: Error) => {
        server.removeListener("listening", onListening);
        reject(error);
      };
      const onListening = () => {
        server.removeListener("error", onError);
        this.server = server;
        resolve();
      };

      server.once("error", onError);
      server.once("listening", onListening);
      server.listen({ port, host, exclusive: false });
    });
  }

  private handleRequest(req: http.IncomingMessage, res: http.ServerResponse): void {
    const url = req.url ?? "/";
    const method = req.method ?? "GET";

    if (method === "GET" && url.startsWith("/health")) {
      this.writeJson(res, 200, { ok: true, service: "cursor-bark-bridge", port: this.port });
      return;
    }

    if (method === "GET" && url.startsWith("/snapshot")) {
      const snapshot = this.tracker.consumeSnapshot(this.port);
      this.writeJson(res, 200, snapshot);
      return;
    }

    if (method === "POST" && (url.startsWith("/event") || url.startsWith("/hook"))) {
      this.readBody(req)
        .then((body) => {
          const payload = JSON.parse(body) as Record<string, unknown>;
          this.tracker.handleHookPayload(payload);
          this.writeJson(res, 200, { ok: true });
        })
        .catch(() => {
          this.writeJson(res, 400, { ok: false, error: "invalid json" });
        });
      return;
    }

    this.writeJson(res, 404, { ok: false, error: "not found" });
  }

  private readBody(req: http.IncomingMessage): Promise<string> {
    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];
      req.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
      req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
      req.on("error", reject);
    });
  }

  private writeJson(res: http.ServerResponse, status: number, body: BridgeSnapshot | Record<string, unknown>): void {
    const payload = JSON.stringify(body);
    res.writeHead(status, {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Length": Buffer.byteLength(payload),
      Connection: "close",
    });
    res.end(payload);
  }
}

function isAddrInUse(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as NodeJS.ErrnoException).code === "EADDRINUSE"
  );
}

export async function probeBridge(host: string, port: number): Promise<boolean> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 1500);
  try {
    const response = await fetch(`http://${host}:${port}/health`, { signal: controller.signal });
    if (!response.ok) {
      return false;
    }
    const body = (await response.json()) as { ok?: boolean; service?: string };
    return body.ok === true && body.service === "cursor-bark-bridge";
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchBridgeSnapshot(host: string, port: number): Promise<BridgeSnapshot | undefined> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 3000);
  try {
    const response = await fetch(`http://${host}:${port}/snapshot`, { signal: controller.signal });
    if (!response.ok) {
      return undefined;
    }
    return (await response.json()) as BridgeSnapshot;
  } catch {
    return undefined;
  } finally {
    clearTimeout(timer);
  }
}
