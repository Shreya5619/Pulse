import { Router, Request, Response } from "express";
import { plannerEngine } from "../services/PlannerEngine";

const router = Router();

router.get("/decision", async (req: Request, res: Response) => {
  try {
    const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId or deviceId" });
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
    const { userId: queryUserId, deviceId, riskType, nodeId } = req.query;
    const userId = req.header("X-User-Id") || queryUserId || deviceId;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId or deviceId" });
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
  const { userId: bodyUserId, deviceId, actionId, status } = req.body;
  const userId = req.header("X-User-Id") || bodyUserId || deviceId;
  console.log(`[Planner] Action status updated: user=${userId}, action=${actionId}, status=${status}`);
  // In a real app, we'd persist this to an AuditLog or UserActions table
  res.json({ ok: true });
});

export default router;
