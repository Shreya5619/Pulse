import { Router, Request, Response } from "express";
import { graphBuilder } from "../services/GraphBuilder";
import { riskEngine } from "../services/RiskEngineService";
import { riskSnapshotRepo } from "../db/RiskSnapshotRepository";

const router = Router();

/**
 * GET /api/graph/summary
 * Returns latest GraphSummary for the current user.
 * Reads from cache or rebuilds if missing.
 */
router.get("/summary", async (req: Request, res: Response) => {
    try {
        const userId = (
            req.header("X-User-Id") || 
            req.query.userId || 
            req.query["X-User-Id"] || 
            "lifecanvas_studios"
        ) as string;

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
        const userId = (
            typeof req.header("X-User-Id") === "string" ? req.header("X-User-Id") :
                typeof req.query.userId === "string" ? req.query.userId :
                    typeof req.query["X-User-Id"] === "string" ? req.query["X-User-Id"] :
                        "lifecanvas_studios"
        ) as string;

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
 * GET /api/graph/risk
 * Compute and return a live RiskSnapshot for the user.
 * The snapshot is also persisted to Postgres for historical queries.
 */
router.get("/risk", async (req: Request, res: Response) => {
    try {
        const userId = (
            req.header("X-User-Id") || 
            req.query.userId || 
            req.query["X-User-Id"] || 
            "lifecanvas_studios"
        ) as string;

        console.log(`[GraphRoute] GET /risk hit for user: ${userId}`);

        const snapshot = await riskEngine.computeForUser(userId);
        res.json({ ok: true, data: snapshot });
    } catch (error: any) {
        console.error("[Pulse] Risk computation error:", error);
        res.status(500).json({ ok: false, error: "Failed to compute risk snapshot", message: error.message });
    }
});

/**
 * GET /api/graph/risk/history
 * Query stored risk snapshots by time window.
 *
 * Query params:
 *   userId  – user identifier (default: lifecanvas_studios)
 *   from    – ISO 8601 start time (default: 24h ago)
 *   to      – ISO 8601 end time   (default: now)
 */
router.get("/risk/history", async (req: Request, res: Response) => {
    try {
        const userId = (
            req.header("X-User-Id") || 
            req.query.userId || 
            req.query["X-User-Id"] || 
            "lifecanvas_studios"
        ) as string;

        const now = new Date();
        const from = req.query.from ? new Date(req.query.from as string) : new Date(now.getTime() - 24 * 60 * 60 * 1000);
        const to = req.query.to ? new Date(req.query.to as string) : now;

        const snapshots = await riskSnapshotRepo.findRange(userId, from, to);
        res.json({
            ok: true,
            data: {
                userId,
                from: from.toISOString(),
                to: to.toISOString(),
                count: snapshots.length,
                snapshots
            }
        });
    } catch (error: any) {
        console.error("[Pulse] Risk history error:", error);
        res.status(500).json({ ok: false, error: "Failed to query risk history", message: error.message });
    }
});

/**
 * GET /api/graph/explain/:nodeId
 * Returns a subgraph explanation for a specific node.
 */
router.get("/explain/:nodeId", async (req: Request, res: Response) => {
    try {
        const userId = String(req.header("X-User-Id") || req.query.userId || req.query["X-User-Id"] || "lifecanvas_studios");
        const { nodeId } = req.params;

        const explanation = graphBuilder.getExplanation(userId, nodeId as string);
        if (!explanation) {
            return res.status(404).json({ ok: false, error: "Node or graph not found" });
        }

        res.json({
            ok: true,
            data: explanation
        });
    } catch (error: any) {
        console.error("[Pulse] Graph explanation error:", error);
        res.status(500).json({ ok: false, error: "Failed to generate graph explanation", message: error.message });
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

