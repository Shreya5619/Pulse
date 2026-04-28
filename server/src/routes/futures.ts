import { Router } from "express";
import { futuresEngine } from "../services/FuturesEngine";

const router = Router();

router.get("/futures", async (req, res) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId" });
    }

    const result = await futuresEngine.computeForUser(userId);
    res.json({ ok: true, data: result });
  } catch (err) {
    console.error("[Futures] /futures error:", err);
    res.status(500).json({ ok: false, error: "Futures engine failed" });
  }
});

export default router;
