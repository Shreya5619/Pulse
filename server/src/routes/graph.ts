import { Router, Request, Response } from "express";
import { graphBuilder } from "../services/GraphBuilder";

const router = Router();

/**
 * GET /api/graph
 * Returns the current risk graph for the user.
 */
router.get("/", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || "lifecanvas_studios"; // Default for dev
        const graph = await graphBuilder.buildForUser(userId);

        res.json({
            ok: true,
            data: graph
        });
    } catch (error: any) {
        console.error("[Pulse] Graph generation error:", error);
        res.status(500).json({ ok: false, error: "Graph generation failed", message: error.message });
    }
});

export default router;
