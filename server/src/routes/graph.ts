import { Router, Request, Response } from "express";
import { graphBuilder } from "../services/GraphBuilder";

const router = Router();

/**
 * GET /api/graph/summary
 * Returns latest GraphSummary for the current user.
 * Reads from cache or rebuilds if missing.
 */
router.get("/summary", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || "lifecanvas_studios";
        
        let graph = graphBuilder.getCachedGraph(userId);
        if (!graph) {
            console.log(`[GraphRoute] Cache miss for ${userId}, building...`);
            graph = await graphBuilder.buildForUser(userId);
        }

        res.json({
            ok: true,
            data: graph.summary
        });
    } catch (error: any) {
        console.error("[Pulse] Graph summary error:", error);
        res.status(500).json({ ok: false, error: "Failed to generate graph summary", message: error.message });
    }
});

/**
 * GET /api/graph/full
 * Returns { nodes, edges, summary } for debugging and inspection.
 */
router.get("/full", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || "lifecanvas_studios";
        
        let graph = graphBuilder.getCachedGraph(userId);
        if (!graph) {
            graph = await graphBuilder.buildForUser(userId);
        }

        res.json({
            ok: true,
            data: graph
        });
    } catch (error: any) {
        console.error("[Pulse] Graph full generation error:", error);
        res.status(500).json({ ok: false, error: "Failed to generate full graph", message: error.message });
    }
});

/**
 * GET /api/graph
 * Fallback to full graph.
 */
router.get("/", async (req: Request, res: Response) => {
    res.redirect("/api/graph/full");
});

export default router;
