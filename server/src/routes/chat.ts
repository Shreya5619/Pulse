import { Router, Request, Response } from "express";
import { chatAgentService } from "../services/ChatAgentService";
import { upload } from "../utils/multer";
import { transcribeAudio } from "../utils/llm";
import * as fs from 'fs';

const router = Router();

router.post("/transcribe", upload.single("audio"), async (req: Request, res: Response) => {
    try {
        const file = (req as any).file;
        if (!file) {
            return res.status(400).json({ ok: false, error: "No audio file provided." });
        }

        const transcription = await transcribeAudio(file.path);

        // Clean up the file after transcription
        fs.unlinkSync(file.path);

        res.json({
            ok: true,
            data: { text: transcription }
        });
    } catch (error: any) {
        console.error("[Chat Route] Transcription error:", error);
        res.status(500).json({
            ok: false,
            error: "Transcription failed",
            details: error.message
        });
    }
});

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
        const { message, history, currentTime } = req.body;

        if (!message) {
            return res.status(400).json({ ok: false, error: "Missing 'message' in request body." });
        }

        console.log(`[Chat Route] Incoming message from ${userId}`);
        const result = await chatAgentService.handleMessage(userId, message, history || [], currentTime);

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
