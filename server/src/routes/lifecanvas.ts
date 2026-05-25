import { Router, Request, Response } from "express";
import { memoryIngestor } from "../services/lifecanvas/MemoryIngestor";
import { summarizerEngine } from "../services/lifecanvas/SummarizerEngine";
import { lifeGraphBuilder } from "../services/lifecanvas/LifeGraphBuilder";
import pool from "../db/db";

const router = Router();

// Automatically initialize database tables if they do not exist
async function initTables() {
    try {
        console.log("[LifeCanvasRoute] Ensuring database tables are initialized...");
        
        await pool.query(`
            CREATE TABLE IF NOT EXISTS life_canvas_events (
                id SERIAL PRIMARY KEY,
                user_id TEXT NOT NULL,
                type TEXT NOT NULL,
                timestamp TIMESTAMPTZ NOT NULL,
                tags JSONB NOT NULL DEFAULT '[]'::jsonb,
                entities JSONB NOT NULL DEFAULT '{}'::jsonb,
                importance REAL NOT NULL DEFAULT 0.5,
                text_content TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS life_canvas_summaries (
                id SERIAL PRIMARY KEY,
                user_id TEXT NOT NULL,
                layer TEXT NOT NULL,
                period_start TIMESTAMPTZ NOT NULL,
                period_end TIMESTAMPTZ NOT NULL,
                summary TEXT NOT NULL,
                key_events JSONB DEFAULT '[]'::jsonb,
                patterns JSONB DEFAULT '[]'::jsonb,
                emotional_trend TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS life_graph_nodes (
                id SERIAL PRIMARY KEY,
                user_id TEXT NOT NULL,
                type TEXT NOT NULL,
                label TEXT NOT NULL,
                importance REAL NOT NULL DEFAULT 0.5,
                metadata JSONB DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS life_graph_edges (
                id SERIAL PRIMARY KEY,
                user_id TEXT NOT NULL,
                source_id INTEGER NOT NULL,
                target_id INTEGER NOT NULL,
                relation TEXT NOT NULL,
                strength REAL DEFAULT 0.5,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log("[LifeCanvasRoute] Database tables verified & initialized successfully.");
    } catch (e) {
        console.error("[LifeCanvasRoute] Failed to initialize database tables:", e);
    }
}

// Fire table check in the background
initTables();

router.post("/ingest", async (req: Request, res: Response) => {
    try {
        const { userId, audioTranscript, timestamp } = req.body;
        if (!userId || !audioTranscript) {
            return res.status(400).json({ ok: false, error: "Missing userId or audioTranscript" });
        }

        const time = timestamp || new Date().toISOString();
        await memoryIngestor.ingest(userId, audioTranscript, time);

        res.json({ ok: true, data: { status: "ingested" } });
    } catch (err: any) {
        // MemoryIngestor already handles DB fallback internally.
        // Only truly unrecoverable errors (e.g. bad FS permissions) reach here.
        console.error("[LifeCanvasRoute] Ingest failed:", err);
        res.status(500).json({ ok: false, error: err?.message || "Internal server error" });
    }
});

router.post("/summarize", async (req: Request, res: Response) => {
    try {
        const { userId, date } = req.body;
        await summarizerEngine.runDailyCompression(userId, date || new Date().toISOString().split('T')[0]);
        res.json({ ok: true, data: { status: "summarized" } });
    } catch (err) {
        res.status(500).json({ ok: false, error: "Internal server error" });
    }
});

router.get("/graph", async (req: Request, res: Response) => {
    try {
        const userId = (req.query.userId || "demo-user") as string;
        const graph = await lifeGraphBuilder.getLifeTree(userId);
        res.json({ ok: true, data: graph });
    } catch (err) {
        console.error("Graph retrieval error:", err);
        res.status(500).json({ ok: false, error: "Internal server error" });
    }
});

router.get("/config", (req: Request, res: Response) => {
    res.json({
        ok: true,
        data: {
            groqApiKey: process.env.GROQ_API_KEY || ""
        }
    });
});

export default router;
