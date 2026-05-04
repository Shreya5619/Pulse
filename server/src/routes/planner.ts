import { Router, Request, Response } from "express";
import { plannerEngine } from "../services/PlannerEngine";

const router = Router();

router.get("/decision", async (req: Request, res: Response) => {
  try {
    const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string;
    const scenarioId = req.query.scenarioId as string || "RECOMMENDED";
    
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId or deviceId" });
    }
    const decision = await plannerEngine.decideForUser(userId, scenarioId);
    res.json({ ok: true, data: decision });
  } catch (err) {
    console.error("[Planner] /planner/decision error:", err);
    res.status(500).json({ ok: false, error: "Planner failed" });
  }
});

/**
 * GET /api/planner/decision/:scenarioId
 * Alias for fetching a decision for a specific scenario (e.g. /decision/DO_NOTHING)
 */
router.get("/decision/:scenarioId", async (req: Request, res: Response) => {
  try {
    const { scenarioId } = req.params;
    const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string;
    
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId or deviceId" });
    }
    const decision = await plannerEngine.decideForUser(userId, scenarioId);
    res.json({ ok: true, data: decision });
  } catch (err) {
    console.error("[Planner] /planner/decision/:scenarioId error:", err);
    res.status(500).json({ ok: false, error: "Planner failed" });
  }
});

/**
 * GET /api/planner/scenario/:scenarioId
 * Alias to support the /scenario/A pattern requested by the user
 */
router.get("/scenario/:scenarioId", async (req: Request, res: Response) => {
  try {
    const { scenarioId } = req.params;
    // Map human friendly aliases
    let mappedId = scenarioId;
    if (scenarioId === 'A') mappedId = 'DO_NOTHING';
    if (scenarioId === 'B') mappedId = 'RECOMMENDED';
    if (scenarioId === 'C') mappedId = 'ALTERNATE';

    const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string;
    
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId or deviceId" });
    }
    const decision = await plannerEngine.decideForUser(userId, mappedId);
    res.json({ ok: true, data: decision });
  } catch (err) {
    console.error("[Planner] /planner/scenario/:scenarioId error:", err);
    res.status(500).json({ ok: false, error: "Planner failed" });
  }
});

import { plannerRepo } from "../db/PlannerRepository";

/**
 * GET /api/planner/latest
 * Fetch the most recent recommendation made for a user.
 */
router.get("/latest", async (req: Request, res: Response) => {
  try {
    const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId or deviceId" });
    }
    const latest = await plannerRepo.findLatestByUser(userId);
    if (!latest) {
      return res.status(404).json({ ok: false, error: "No recommendations found for this user" });
    }
    res.json({ ok: true, data: latest });
  } catch (err) {
    console.error("[Planner] /planner/latest error:", err);
    res.status(500).json({ ok: false, error: "Failed to fetch latest recommendation" });
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

import { memoryStore } from "../services/MemoryStore";

/**
 * POST /api/planner/scenario/select
 * Persist the user's chosen future scenario to memory.
 */
router.post("/scenario/select", async (req: Request, res: Response) => {
  try {
    const { userId, deviceId, scenarioId } = req.body;
    const finalUserId = userId || deviceId;

    if (!finalUserId || !scenarioId) {
      return res.status(400).json({ ok: false, error: "Missing userId or scenarioId" });
    }

    console.log(`[Planner] User ${finalUserId} selected scenario: ${scenarioId}`);
    
    await memoryStore.save(finalUserId, {
      status: { active_scenario: scenarioId }
    }, "user_selection");

    res.json({ ok: true, message: `Scenario ${scenarioId} selected.` });
  } catch (err) {
    console.error("[Planner] /planner/scenario/select error:", err);
    res.status(500).json({ ok: false, error: "Failed to select scenario" });
  }
});

export default router;
