import { Router, Request, Response } from "express";
import { memoryAgent } from "../services/MemoryAgent";

const router = Router();

/**
 * GET /api/memory/summary
 * Returns the current memory state for the user.
 */
router.get("/summary", async (req: Request, res: Response) => {
  const userId = (req.query.userId as string) || "user_123";
  
  try {
    const summary = await memoryAgent.getMemorySummary(userId);
    res.json({
      ok: true,
      data: summary
    });
  } catch (error) {
    console.error("[MemoryRoute] Failed to fetch memory summary:", error);
    res.status(500).json({
      ok: false,
      error: "Internal server error while fetching memory summary"
    });
  }
});

/**
 * POST /api/memory/trigger
 * Manually trigger a summarization run.
 */
router.post("/trigger", async (req: Request, res: Response) => {
  const userId = req.body.userId || "user_123";
  
  try {
    await memoryAgent.runSummary(userId);
    res.json({
      ok: true,
      message: "Memory summarization triggered successfully"
    });
  } catch (error) {
    res.status(500).json({ ok: false, error: "Failed to trigger summarization" });
  }
});

export default router;
