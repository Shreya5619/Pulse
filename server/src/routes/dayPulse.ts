import { Router, Request, Response } from "express";
import { dayPulseService } from "../services/DayPulseService";
import { userEventsRepo } from "../db/UserEventsRepository";

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
        
        await userEventsRepo.addOverride(userId, { userId, eventId, updates });
        
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

router.post("/day-pulse/add", async (req: Request, res: Response) => {
    try {
        const { userId, event } = req.body;
        console.log(`[DayPulseRoute] Adding manual event for user ${userId}:`, event.title);
        
        await userEventsRepo.addManualEvent(userId, event);
        
        const date = new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        
        res.json({
            ok: true,
            data: timeline,
            message: "Event added to your pulse."
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not add event"
        });
    }
});

router.post("/day-pulse/optimize", async (req: Request, res: Response) => {
    try {
        const { userId, date } = req.body;
        const targetDate = date || new Date().toISOString().split('T')[0];
        
        const timeline = await dayPulseService.optimizeTimeline(userId, targetDate);
        
        res.json({
            ok: true,
            data: timeline,
            message: "Pulse optimized to minimize risks."
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not optimize pulse"
        });
    }
});

export default router;
