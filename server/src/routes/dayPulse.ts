import { Router, Request, Response } from "express";
import { dayPulseService } from "../services/DayPulseService";
import { userEventsRepo } from "../db/UserEventsRepository";
import { routineRepo } from "../db/RoutineRepository";

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
        const { userId, eventId, updates, isRecurring, days } = req.body;
        console.log(`[DayPulseRoute] Modifying event ${eventId} for user ${userId}:`, updates);
        
        if (isRecurring && days) {
            // Sync to RoutineRepository if it was a routine or we want to make it recurring
            await routineRepo.updateRoutine(userId, eventId, { ...updates, days });
        } else {
            await userEventsRepo.addOverride(userId, { userId, eventId, updates });
        }
        
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
        const { userId, event, isRecurring, days, category } = req.body;
        console.log(`[DayPulseRoute] Adding manual event for user ${userId}:`, event.title);
        if (isRecurring && days) {
            // Extract HH:mm from ISO strings
            const startStr = new Date(event.start_time).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false });
            const endStr = new Date(event.end_time).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false });
            
            await routineRepo.addRoutine(userId, {
                title: event.title,
                startTime: startStr,
                endTime: endStr,
                category: category || 'buffer',
                days: days
            });
        } else {
            await userEventsRepo.addManualEvent(userId, { ...event, category });
        }
        
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

router.post("/day-pulse/delete", async (req: Request, res: Response) => {
    try {
        const { userId, eventId, isRoutine } = req.body;
        console.log(`[DayPulseRoute] Deleting ${isRoutine ? 'routine' : 'event'} ${eventId} for user ${userId}`);
        
        if (isRoutine) {
            await routineRepo.deleteRoutine(userId, eventId);
        } else {
            // It could be a manual event or an override
            await userEventsRepo.deleteManualEvent(userId, eventId);
            await userEventsRepo.addOverride(userId, { userId, eventId, updates: {}, isDeleted: true });
        }
        
        const date = new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        
        res.json({
            ok: true,
            data: timeline,
            message: "Item removed from your pulse."
        });
    } catch (error) {
        res.status(500).json({
            ok: false,
            error: "Could not delete item"
        });
    }
});

export default router;
