import { Router, Request, Response } from "express";
import { chatAgentService } from "../services/ChatAgentService";

const router = Router();

/**
 * POST /api/chat/message
 * {
 *   "message": "string",
 *   "history": []
 * }
 */
router.post("/message", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || req.body.userId || "user1";
        const { message, history } = req.body;

        if (!message) {
            return res.status(400).json({ ok: false, error: "Missing 'message' in request body." });
        }

        console.log(`[Chat Route] Incoming message from ${userId}`);
        const result = await chatAgentService.handleMessage(userId, message, history || []);

        res.json({
            ok: true,
            data: result
        });
    } catch (error: any) {
        console.error("[Chat Route] Error:", error);
        res.status(500).json({
            ok: false,
            error: "Internal server error",
            details: error.message
        });
    }
});

export default router;
