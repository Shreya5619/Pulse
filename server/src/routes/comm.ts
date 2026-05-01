import { Router, Request, Response } from "express";
import { communicationService } from "../services/CommunicationService";

const router = Router();

router.post("/prepare", async (req: Request, res: Response) => {
  const { userId, actionId, role } = req.body;
  
  if (!userId || !actionId) {
    return res.status(400).json({ ok: false, error: "Missing userId or actionId" });
  }

  try {
    const result = await communicationService.prepare(userId, actionId, role);
    res.json({ ok: true, data: result });
  } catch (error: any) {
    console.error("[CommRoute] Prepare failed:", error);
    res.status(500).json({ ok: false, error: error.message });
  }
});

router.post("/send", async (req: Request, res: Response) => {
  const { userId, actionId } = req.body;
  
  console.log(`[CommRoute] Dummy send for user ${userId}, action ${actionId}`);
  
  // Log to "DB" (console for now as requested)
  res.json({ ok: true, data: { status: "SENT" } });
});

export default router;
