import dotenv from "dotenv";
import express, { Request, Response } from "express";
import cors from "cors";
import { createServer } from "http";
import { WebSocketServer, WebSocket } from "ws";
import fs from "fs";
import path from "path";

// Agent Imports
import { contextAgent } from "../../agents/context";
import { riskAgent } from "../../agents/risk";
import { plannerAgent } from "../../agents/planner";
import { guardianAgent } from "../../agents/guardian";
import { heartbeatAgent } from "../../agents/heartbeat";

import contextRouter from "./routes/context";
import memoryRouter from "./routes/memory";
import graphRouter from "./routes/graph";
import routingRouter from "./routes/routing";
import futuresRouter from "./routes/futures";
import { graphBuilder } from "./services/GraphBuilder";
import { memoryAgent } from "./services/MemoryAgent";
import { riskEngine } from "./services/RiskEngineService";
import { futuresEngine } from "./services/FuturesEngine";
import { heartbeatOrchestrator } from "./services/HeartbeatOrchestrator";
import { workspaceService } from "./services/WorkspaceService";
import plannerRouter from "./routes/planner";
import { runAgentPulseFlow } from "./services/PulseOrchestrator";
import twinRouter from "./routes/twin";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const app = express();
app.use(cors());
app.use(express.json());

app.use("/api", contextRouter);
app.use("/api/memory", memoryRouter);
app.use("/api/graph", graphRouter);
app.use("/api/routing", routingRouter);
app.use("/api/planner", plannerRouter);
app.use("/api", futuresRouter);
import commRouter from "./routes/comm";
app.use("/api/comm", commRouter);
import routeRouter from "./routes/route";
app.use("/api/route", routeRouter);
app.use("/api/twin", twinRouter);
import dayPulseRouter from "./routes/dayPulse";
app.use("/api", dayPulseRouter);
import guardianRouter from "./routes/guardian";
app.use("/api/guardian", guardianRouter);
import chatRouter from "./routes/chat";
app.use("/api/chat", chatRouter);


const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

const PORT = Number(process.env.PULSE_HTTP_PORT || 8080);
const HOST = process.env.PULSE_HTTP_HOST || "0.0.0.0";

const rootDir = path.resolve(__dirname, "..", "..");
const dataDir = path.join(rootDir, "data");
const openclawDir = path.join(dataDir, "openclaw");

// State Management
let isPulseRunning = false;
let lastInterventionText = "";

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

export function broadcast(message: unknown) {
    const payload = JSON.stringify(message);
    for (const client of wss.clients) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    }
}

// Moved to PulseOrchestrator

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
    const scenarioPath = path.join(dataDir, "demo-scenario.json");
    if (!fs.existsSync(scenarioPath)) {
        return res.status(500).json({ ok: false, error: "Missing demo scenario file" });
    }
    const scenario = readJson(scenarioPath) as any;
    const userId = scenario.context?.userId || "user1";

    if (isPulseRunning) {
        return res.status(429).json({
            ok: false,
            error: "A run is already in progress."
        });
    }

    res.json({
        ok: true,
        data: {
            message: "Pulse orchestrated flow started",
            userId
        }
    });

    try {
        await runAgentPulseFlow(scenario.context, broadcast);
    } catch (error) {
        console.error("[Pulse] demo error:", error);
    }
});

app.post("/heartbeat/manual", async (req: Request, res: Response) => {
    const userId = req.body?.userId || "user1";
    console.log(`[Pulse] Manual heartbeat requested for ${userId}`);

    if (isPulseRunning) {
        return res.json({
            ok: true,
            data: {
                status: "skipped",
                reason: "Pulse run already in progress"
            }
        });
    }

    res.json({
        ok: true,
        data: {
            status: "HEARTBEAT_OK",
            timestamp: new Date().toISOString()
        }
    });

    // Run the flow in background
    runAgentPulseFlow({ userId }, broadcast).catch(error => {
        console.error("[Pulse] Manual heartbeat error:", error);
    });
});

app.get("/demo/events", (_req: Request, res: Response) => {
    try {
        const eventsPath = path.join(dataDir, "demo-events.json");
        if (!fs.existsSync(eventsPath)) {
            return res.status(404).json({
                ok: false,
                error: "Missing data/demo-events.json. Run seed script first."
            });
        }
        const events = readJson(eventsPath);
        res.json({
            ok: true,
            data: events
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not read demo events"
        });
    }
});

app.get("/config/openclaw-files", (_req: Request, res: Response) => {
    try {
        const config = workspaceService.getConfig();
        res.json({
            ok: true,
            data: config
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not read OpenClaw config files"
        });
    }
});

wss.on("connection", (ws, req) => {
    console.log(`[Pulse] WS client connected from ${req.socket.remoteAddress}`);

    sendJson(ws, {
        type: "connection.ready",
        eventId: "conn_" + Date.now(),
        timestamp: new Date().toISOString(),
        data: {
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

const HEARTBEAT_TICK_MS = 5000;
let tickSequence = 1;

// Background auto-tick every 5 seconds (lightweight: uses cached graph)
setInterval(() => {
    // For each user in the cache, broadcast their tick
    for (const [userId, cached] of graphBuilder.getCacheEntries()) {
        const topRisks = cached?.summary?.risks || [];
        const topScore = topRisks.length > 0 ? Math.max(...topRisks.map(r => r.score)) : 0;

        broadcast({
            type: "heartbeat.tick",
            userId,
            eventId: `tick_auto_${Date.now()}_${userId}`,
            timestamp: new Date().toISOString(),
            data: {
                sequence: tickSequence++,
                state: topScore >= 0.4 ? "risk_forming" : "nominal",
                score: parseFloat(topScore.toFixed(2)),
                source: "graph_cache",
                risksNext90Min: cached?.summary?.totalRisksNext90Min ?? 0
            }
        });
    }
}, HEARTBEAT_TICK_MS);

httpServer.listen(PORT, HOST, () => {
    console.log(`[Pulse] Server running on http://${HOST}:${PORT}`);
    console.log(`[Pulse] WebSocket available at ws://${HOST}:${PORT}/ws`);
});