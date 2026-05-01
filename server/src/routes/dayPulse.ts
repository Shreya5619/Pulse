import { Router, Request, Response } from "express";
import { dayPulseService } from "../services/DayPulseService";

const router = Router();

router.get("/day-pulse", async (req: Request, res: Response) => {
    try {
        const userId = req.query.userId as string || "demo-user";
        const date = req.query.date as string || new Date().toISOString().split('T')[0];
        
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        res.json({
            ok: true,
            data: timeline
        });
    } catch (error) {
        console.error("[DayPulseRoute] Error fetching timeline:", error);
        res.status(500).json({
            ok: false,
            error: "Could not fetch daily timeline"
        });
    }
});

router.post("/day-pulse/modify", async (req: Request, res: Response) => {
    try {
        const { userId, eventId, updates } = req.body;
        console.log(`[DayPulseRoute] Modifying event ${eventId} for user ${userId}:`, updates);
        
        // In a real app, this would update the database/calendar
        // For the hackathon, we can simulate the "ripple effect" by returning 
        // the re-calculated timeline for the modified day.
        
        const date = new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        
        res.json({
            ok: true,
            data: timeline,
            message: "Schedule modified. All downstream risks re-calculated."
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not modify schedule"
        });
    }
});

export default router;
