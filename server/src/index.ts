import dotenv from "dotenv";
import express, { Request, Response } from "express";
import cors from "cors";
import { createServer } from "http";
import { WebSocketServer, WebSocket } from "ws";
import fs from "fs";
import path from "path";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

const PORT = Number(process.env.PULSE_HTTP_PORT || 8080);
const HOST = process.env.PULSE_HTTP_HOST || "0.0.0.0";

const rootDir = path.resolve(__dirname, "..", "..");
const dataDir = path.join(rootDir, "data");
const openclawDir = path.join(dataDir, "openclaw");

type JsonObject = Record<string, unknown>;

function readJson(filePath: string): JsonObject | JsonObject[] {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function readText(filePath: string): string {
    return fs.readFileSync(filePath, "utf8");
}

function sendJson(ws: WebSocket, message: unknown) {
    if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(message));
    }
}

function broadcast(message: unknown) {
    const payload = JSON.stringify(message);
    for (const client of wss.clients) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    }
}

async function replayDemoFlow() {
    const eventsPath = path.join(dataDir, "demo-events.json");
    if (!fs.existsSync(eventsPath)) {
        throw new Error("Missing data/demo-events.json. Run seed script first.");
    }

    const events = readJson(eventsPath) as JsonObject[];
    for (const event of events) {
        broadcast(event);
        await new Promise((resolve) => setTimeout(resolve, 1200));
    }
}

app.get("/health", (_req: Request, res: Response) => {
    res.json({
        ok: true,
        data: {
            service: "pulse-server",
            version: "0.0.1",
            uptimeSeconds: Math.round(process.uptime())
        }
    });
});

app.get("/demo/state", (_req: Request, res: Response) => {
    const userPath = path.join(dataDir, "demo-user.json");
    const scenarioPath = path.join(dataDir, "demo-scenario.json");

    if (!fs.existsSync(userPath) || !fs.existsSync(scenarioPath)) {
        return res.status(500).json({
            ok: false,
            error: "Missing demo seed files. Run the seed script first."
        });
    }

    const user = readJson(userPath);
    const scenario = readJson(scenarioPath) as JsonObject;

    res.json({
        ok: true,
        data: {
            userId: (user as JsonObject).id,
            profile: user,
            context: scenario.context
        }
    });
});

app.post("/demo/trigger", async (_req: Request, res: Response) => {
    res.json({
        ok: true,
        data: {
            message: "Pulse demo scenario started"
        }
    });

    try {
        await replayDemoFlow();
    } catch (error) {
        console.error("[Pulse] replay error:", error);
    }
});

app.get("/config/openclaw-files", (_req: Request, res: Response) => {
    try {
        const soul = readText(path.join(openclawDir, "SOUL.md"));
        const agents = readText(path.join(openclawDir, "agents.md"));
        const user = readText(path.join(openclawDir, "user.md"));
        const heartbeat = readText(path.join(openclawDir, "heartbeat.md"));

        res.json({
            ok: true,
            data: {
                soul,
                agents,
                user,
                heartbeat
            }
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not read Pulse config files"
        });
    }
});

wss.on("connection", (ws, req) => {
    console.log(`[Pulse] WS client connected from ${req.socket.remoteAddress}`);

    sendJson(ws, {
        type: "connection.ready",
        ts: new Date().toISOString(),
        payload: {
            message: "Connected to Pulse WebSocket"
        }
    });

    ws.on("message", (data) => {
        const text = data.toString();
        console.log("[Pulse] WS message:", text);
    });

    ws.on("close", () => {
        console.log("[Pulse] WS client disconnected");
    });

    ws.on("error", (err) => {
        console.error("[Pulse] WS error:", err);
    });
});

httpServer.listen(PORT, HOST, () => {
    console.log(`[Pulse] Server running on http://${HOST}:${PORT}`);
    console.log(`[Pulse] WebSocket available at ws://${HOST}:${PORT}/ws`);
});