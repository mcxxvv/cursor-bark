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
exports.StatusServer = void 0;
exports.probeBridge = probeBridge;
exports.fetchBridgeSnapshot = fetchBridgeSnapshot;
const http = __importStar(require("http"));
class StatusServer {
    server;
    tracker;
    port = 8766;
    host = "127.0.0.1";
    constructor(tracker) {
        this.tracker = tracker;
    }
    get listeningPort() {
        return this.port;
    }
    get listeningHost() {
        return this.host;
    }
    async start(host, port) {
        await this.stop();
        this.port = port;
        this.host = host;
        try {
            await this.listen(host, port);
            return "started";
        }
        catch (error) {
            if (isAddrInUse(error) && (await probeBridge(host, port))) {
                return "attached";
            }
            throw error;
        }
    }
    async stop() {
        const current = this.server;
        this.server = undefined;
        if (!current) {
            return;
        }
        await new Promise((resolve) => {
            current.close(() => resolve());
            if (typeof current.closeAllConnections === "function") {
                current.closeAllConnections();
            }
        });
    }
    listen(host, port) {
        return new Promise((resolve, reject) => {
            const server = http.createServer((req, res) => {
                this.handleRequest(req, res);
            });
            const onError = (error) => {
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
    handleRequest(req, res) {
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
                const payload = JSON.parse(body);
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
    readBody(req) {
        return new Promise((resolve, reject) => {
            const chunks = [];
            req.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
            req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
            req.on("error", reject);
        });
    }
    writeJson(res, status, body) {
        const payload = JSON.stringify(body);
        res.writeHead(status, {
            "Content-Type": "application/json; charset=utf-8",
            "Content-Length": Buffer.byteLength(payload),
            Connection: "close",
        });
        res.end(payload);
    }
}
exports.StatusServer = StatusServer;
function isAddrInUse(error) {
    return (typeof error === "object" &&
        error !== null &&
        "code" in error &&
        error.code === "EADDRINUSE");
}
async function probeBridge(host, port) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 1500);
    try {
        const response = await fetch(`http://${host}:${port}/health`, { signal: controller.signal });
        if (!response.ok) {
            return false;
        }
        const body = (await response.json());
        return body.ok === true && body.service === "cursor-bark-bridge";
    }
    catch {
        return false;
    }
    finally {
        clearTimeout(timer);
    }
}
async function fetchBridgeSnapshot(host, port) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3000);
    try {
        const response = await fetch(`http://${host}:${port}/snapshot`, { signal: controller.signal });
        if (!response.ok) {
            return undefined;
        }
        return (await response.json());
    }
    catch {
        return undefined;
    }
    finally {
        clearTimeout(timer);
    }
}
//# sourceMappingURL=statusServer.js.map