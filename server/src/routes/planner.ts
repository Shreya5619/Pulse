import { Router, Request, Response } from "express";
import { plannerEngine } from "../services/PlannerEngine";

const router = Router();

router.get("/decision", async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId" });
    }
    const decision = await plannerEngine.decideForUser(userId);
    res.json({ ok: true, data: decision });
  } catch (err) {
    console.error("[Planner] /planner/decision error:", err);
    res.status(500).json({ ok: false, error: "Planner failed" });
  }
});

export default router;
