import { Router, Request, Response } from "express";
import { dayPulseService } from "../services/DayPulseService";
import { userEventsRepo } from "../db/UserEventsRepository";
import { routineRepo } from "../db/RoutineRepository";

const router = Router();

router.get("/day-pulse", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string || "demo-user";
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
        const { userId: bodyUserId, deviceId, eventId, updates, isRecurring, days } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "demo-user";
        console.log(`[DayPulseRoute] Modifying event ${eventId} for user ${userId}:`, updates);
        
        if (isRecurring && days) {
            // Ensure times are in HH:mm for the routine repository
            const routineUpdates: any = { ...updates, days };
            if (updates.startTime) {
                if (updates.startTime.includes('T')) {
                    routineUpdates.startTime = updates.startTime.split('T')[1].substring(0, 5);
                } else {
                    routineUpdates.startTime = updates.startTime;
                }
            }
            if (updates.endTime) {
                if (updates.endTime.includes('T')) {
                    routineUpdates.endTime = updates.endTime.split('T')[1].substring(0, 5);
                } else {
                    routineUpdates.endTime = updates.endTime;
                }
            }

            // Check if this is an existing routine or a new conversion
            const routines = await routineRepo.getForUser(userId);
            const existingRoutine = routines.find(r => r.id === eventId);

            if (existingRoutine) {
                console.log(`[DayPulseRoute] Updating existing routine ${eventId}`);
                await routineRepo.updateRoutine(userId, eventId, routineUpdates);
            } else {
                console.log(`[DayPulseRoute] Converting manual event ${eventId} to new routine`);
                await routineRepo.addRoutine(userId, {
                    title: updates.title || "New Routine",
                    startTime: routineUpdates.startTime || "09:00",
                    endTime: routineUpdates.endTime || "10:00",
                    category: updates.category || 'buffer',
                    days: days
                });
                // Also mark the original manual event as deleted/overridden so it doesn't double up
                await userEventsRepo.addOverride(userId, { userId, eventId, updates: {}, isDeleted: true });
            }
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
        const { userId: bodyUserId, deviceId, event, isRecurring, days, category } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "demo-user";
        console.log(`[DayPulseRoute] Adding manual event for user ${userId}:`, event.title);
        if (isRecurring && days) {
            // Extract HH:mm from ISO strings if they are ISO strings
            let startStr = event.start_time;
            let endStr = event.end_time;
            
            if (startStr.includes('T')) {
                startStr = startStr.split('T')[1].substring(0, 5);
            }
            if (endStr.includes('T')) {
                endStr = endStr.split('T')[1].substring(0, 5);
            }
            
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
        const { userId: bodyUserId, deviceId, date } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "demo-user";
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
        const { userId: bodyUserId, deviceId, eventId, isRoutine } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "demo-user";
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
