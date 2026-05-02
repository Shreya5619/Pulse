import { Router, Request, Response } from "express";
import { memoryIngestor } from "../services/lifecanvas/MemoryIngestor";
import { summarizerEngine } from "../services/lifecanvas/SummarizerEngine";
import { lifeGraphBuilder } from "../services/lifecanvas/LifeGraphBuilder";

const router = Router();

router.post("/ingest", async (req: Request, res: Response) => {
    try {
        const { userId, audioTranscript, timestamp } = req.body;
        if (!userId || !audioTranscript) {
            return res.status(400).json({ ok: false, error: "Missing userId or audioTranscript" });
        }

        const time = timestamp || new Date().toISOString();
        await memoryIngestor.ingest(userId, audioTranscript, time);

        res.json({ ok: true, data: { status: "ingested" } });
    } catch (err) {
        console.error("Ingest error:", err);
        res.status(500).json({ ok: false, error: "Internal server error" });
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
        const userId = req.query.userId as string;
        const graph = await lifeGraphBuilder.getLifeTree(userId);
        res.json({ ok: true, data: graph });
    } catch (err) {
        res.status(500).json({ ok: false, error: "Internal server error" });
    }
});

export default router;
