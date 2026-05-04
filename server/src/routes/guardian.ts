import { Router, Request, Response } from "express";
import { guardianAgent } from "../../../agents/guardian";

const router = Router();

/**
 * POST /api/guardian/validate
 * Test the Guardian Agent's decision logic in isolation.
 * Body: { action: PlannerAction }
 */
router.post("/validate", async (req: Request, res: Response) => {
    try {
        const action = req.body.action;
        
        if (!action) {
            return res.status(400).json({
                ok: false,
                error: "Missing 'action' in request body."
            });
        }

        console.log(`[Guardian API] Validating action: ${action.title}`);
        const result = await guardianAgent(action);

        res.json({
            ok: true,
            data: result
        });
    } catch (error: any) {
        console.error("[Guardian API] Error:", error);
        res.status(500).json({
            ok: false,
            error: "Internal server error during guardian validation",
            details: error.message
        });
    }
});

export default router;
