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
import plannerRouter from "./routes/planner";

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

function broadcast(message: unknown) {
    const payload = JSON.stringify(message);
    for (const client of wss.clients) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    }
}

async function runAgentPulseFlow(initialContext: any) {
    isPulseRunning = true;
    try {
        console.log("[Pulse] Starting deterministic agent flow orchestration...");

        // 1. Heartbeat
        await heartbeatAgent(initialContext.userId);
        broadcast({
            type: "heartbeat.tick",
            eventId: `tick_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: { userId: initialContext.userId, sequence: 1 }
        });
        await new Promise(r => setTimeout(r, 1000));

        // 2. Context Agent
        await contextAgent(initialContext);
        broadcast({
            type: "context.updated",
            eventId: `ctx_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: initialContext
        });
        await new Promise(r => setTimeout(r, 1000));

        // 3. Risk Agent — live snapshot from graph + memory
        const riskSnapshot = await riskAgent(initialContext);
        broadcast({
            type: "risk.updated",
            eventId: `risk_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: riskSnapshot
        });
        await new Promise(r => setTimeout(r, 1000));

        // 3.1 Futures Engine — heuristic simulations
        const futures = await futuresEngine.computeForUser(initialContext.userId);
        broadcast({
            type: "futures.updated",
            eventId: `fut_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: futures
        });
        await new Promise(r => setTimeout(r, 1000));

        // 3.5 Build Graph (Day 6)
        const graph = await graphBuilder.buildForUser(initialContext.userId);
        const appCount = graph.nodes.filter(n => n.type === "APPOINTMENT").length;
        const placeCount = graph.nodes.filter(n => n.type === "PLACE").length;
        const msgCount = graph.nodes.filter(n => n.type === "MESSAGE_OBLIGATION").length;
        console.log(`[Pulse] Graph built: ${appCount} appointments, ${placeCount} places, 1 battery node, ${msgCount} message obligations, totalRisksNext90Min=${graph.summary.totalRisksNext90Min}.`);

        // 3.6 Memory Agent check (triggers DailySummarizer if threshold met)
        await memoryAgent.onHeartbeat(initialContext.userId);

        // 4. Planner Agent
        const decision = await plannerAgent(initialContext);
        if (decision.chosen) {
            broadcast({
                type: "planner.suggested",
                eventId: `plan_${Date.now()}`,
                timestamp: new Date().toISOString(),
                data: decision
            });
        }
        await new Promise(r => setTimeout(r, 1000));

        // 5. Guardian Agent
        const guardianDecision = await guardianAgent(decision.chosen);
        broadcast({
            type: "guardian.decided",
            eventId: `guard_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: {
                userId: initialContext.userId,
                actionId: decision.chosen?.id,
                timestamp: new Date().toISOString(),
                mode: guardianDecision.mode,
                rationale: guardianDecision.rationale
            }
        });
        await new Promise(r => setTimeout(r, 1000));

        // 6. Final Intervention
        if (decision.chosen && guardianDecision.approved) {
            lastInterventionText = decision.chosen.title;
            broadcast({
                type: "intervention.created",
                eventId: `int_${Date.now()}`,
                timestamp: new Date().toISOString(),
                data: {
                    userId: initialContext.userId,
                    actionId: decision.chosen.id,
                    timestamp: new Date().toISOString(),
                    headline: decision.chosen.title,
                    body: decision.chosen.description,
                    ctaLabel: "Accept",
                    secondaryCtaLabel: "Dismiss"
                }
            });
        }

        console.log("[Pulse] Agent flow orchestration completed.");
        return { alert: lastInterventionText };
    } finally {
        isPulseRunning = false;
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
    if (isPulseRunning) {
        return res.status(429).json({
            ok: false,
            error: "A demo run is already in progress. Trigger skipped."
        });
    }

    res.json({
        ok: true,
        data: {
            message: "Pulse demo scenario started"
        }
    });

    try {
        const scenarioPath = path.join(dataDir, "demo-scenario.json");
        const scenario = readJson(scenarioPath) as JsonObject;
        await runAgentPulseFlow(scenario.context);
    } catch (error) {
        console.error("[Pulse] demo error:", error);
    }
});

app.post("/heartbeat/manual", async (req: Request, res: Response) => {
    console.log("[Pulse] Manual heartbeat wake requested.");

    if (isPulseRunning) {
        return res.json({
            ok: true,
            data: {
                status: "skipped",
                reason: "Pulse run already in progress"
            }
        });
    }

    // Capture the result of the flow
    try {
        const scenarioPath = path.join(dataDir, "demo-scenario.json");
        const scenario = readJson(scenarioPath) as JsonObject;

        // Return immediate ACK
        res.json({
            ok: true,
            data: {
                status: "HEARTBEAT_OK",
                timestamp: new Date().toISOString()
            }
        });

        // Run the flow in background
        const result = await runAgentPulseFlow(scenario.context);
        if (result && result.alert) {
            console.log(`[Pulse] Manual run produced alert: ${result.alert}`);
        }
    } catch (error) {
        console.error("[Pulse] Manual heartbeat error:", error);
        if (!res.headersSent) {
            res.status(500).json({ ok: false, error: "Internal server error during heartbeat" });
        }
    }
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
    // Derive a live risk score from the cached graph if available
    const cached = graphBuilder.getCachedGraph("lifecanvas_studios");
    const topRisks = cached?.summary?.risks || [];
    const topScore = topRisks.length > 0 ? Math.max(...topRisks.map(r => r.score)) : 0;

    broadcast({
        type: "heartbeat.tick",
        eventId: `tick_auto_${Date.now()}`,
        timestamp: new Date().toISOString(),
        data: {
            sequence: tickSequence++,
            state: topScore >= 0.4 ? "risk_forming" : "nominal",
            score: parseFloat(topScore.toFixed(2)),
            source: "graph_cache",
            risksNext90Min: cached?.summary?.totalRisksNext90Min ?? 0
        }
    });
}, HEARTBEAT_TICK_MS);

httpServer.listen(PORT, HOST, () => {
    console.log(`[Pulse] Server running on http://${HOST}:${PORT}`);
    console.log(`[Pulse] WebSocket available at ws://${HOST}:${PORT}/ws`);
});