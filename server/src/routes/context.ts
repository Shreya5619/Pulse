import { Router, Request, Response } from "express";
import { normalizeContext } from "../normalization/contextNormalizer";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";

const router = Router();


/**
 * POST /api/context-snapshots
 * Ingest raw sensor data from mobile device.
 */
router.post("/snapshots", async (req: Request, res: Response) => {
    try {
        const rawPayload = req.body;
        const deviceId = req.header("X-Device-Id") || "unknown";
        const userId = req.header("X-User-Id") || "unknown";

        // 1. Normalize
        const normalized = normalizeContext({
            ...rawPayload,
            user_id: userId,
            device_id: deviceId, // if needed
        });

        // 2. Persist to DB
        await contextSnapshotRepo.save(normalized);


        // 4. TODO: Enqueue for risk engine
        // enqueueRiskAssessment(normalized);

        // 5. Response (Echo Mode enabled for dev)
        res.status(201).json({
            snapshot_id: normalized.id,
            accepted_at: new Date().toISOString(),
            minutes_to_next_event: normalized.derived?.minutes_to_next_event ?? null,
            has_next_event: normalized.derived?.has_next_event ?? false,
            echo: normalized, // Added for mobile app verification
        });

    } catch (error: any) {
        console.error("[Pulse] Snapshot ingest error:", error);
        res.status(400).json({
            ok: false,
            error: "Normalization failed",
            details: error.errors || error.message,
        });
    }
});

/**
 * GET /api/context-snapshots/latest
 * Fetch the most recent snapshot for a user.
 */
router.get("/snapshots/latest", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || "unknown";
        const latest = await contextSnapshotRepo.findLatestByUser(userId);

        if (!latest) {
            return res.status(404).json({
                ok: false,
                error: "No snapshots found for this user",
            });
        }

        res.json({
            ok: true,
            data: latest,
        });
    } catch (error: any) {
        res.status(500).json({ ok: false, error: "Database error" });
    }
});


export default router;
