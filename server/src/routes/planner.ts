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

router.get("/suggested-actions", async (req: Request, res: Response) => {
  try {
    const { userId, riskType, nodeId } = req.query;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId" });
    }
    const actions = await plannerEngine.getActionsForRisk(
      userId as string,
      riskType as string,
      nodeId as string
    );
    res.json({ ok: true, data: actions });
  } catch (err) {
    console.error("[Planner] /planner/suggested-actions error:", err);
    res.status(500).json({ ok: false, error: "Suggested actions failed" });
  }
});

router.post("/interventions/status", async (req: Request, res: Response) => {
  const { userId, actionId, status } = req.body;
  console.log(`[Planner] Action status updated: user=${userId}, action=${actionId}, status=${status}`);
  // In a real app, we'd persist this to an AuditLog or UserActions table
  res.json({ ok: true });
});

export default router;
