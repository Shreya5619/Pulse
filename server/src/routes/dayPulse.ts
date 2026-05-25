import { Router, Request, Response } from "express";
import { dayPulseService } from "../services/DayPulseService";
import { userEventsRepo } from "../db/UserEventsRepository";
import { routineRepo } from "../db/RoutineRepository";
import { routingService } from "../services/RoutingService";
import { geocodingService } from "../services/GeocodingService";
import { runAgentPulseFlow } from "../services/PulseOrchestrator";
import { broadcast } from "../index";

const router = Router();

function toRoutineClockTime(value: string | undefined): string | undefined {
    if (!value) return undefined;

    const parsed = new Date(value);
    if (isNaN(parsed.getTime())) return undefined;

    const istMillis = parsed.getTime() + (5.5 * 60 * 60 * 1000);
    const istDate = new Date(istMillis);
    return `${String(istDate.getUTCHours()).padStart(2, '0')}:${String(istDate.getUTCMinutes()).padStart(2, '0')}`;
}

router.get("/day-pulse", async (req: Request, res: Response) => {
    try {
        const userId = req.header("X-User-Id") || req.query.userId as string || req.query.deviceId as string || "user1";
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

async function resolveLocationAndEta(startLocation: any, locationText: string | undefined, destinationLocation?: any) {
    let startLat = startLocation?.lat;
    let startLon = startLocation?.lon;
    
    if ((!startLat || !startLon) && startLocation?.name) {
        const geoStart = await geocodingService.geocode(startLocation.name);
        if (geoStart) {
            startLat = geoStart.lat;
            startLon = geoStart.lon;
        }
    }

    let destLat = destinationLocation?.lat;
    let destLon = destinationLocation?.lon;
    if ((!destLat || !destLon) && locationText) {
        const geoDest = await geocodingService.geocode(locationText);
        if (geoDest) {
            destLat = geoDest.lat;
            destLon = geoDest.lon;
        }
    }

    let eta = null;
    if (startLat && startLon && destLat && destLon) {
        try {
            const route = await routingService.getRoute(
                { lat: startLat, lon: startLon },
                { lat: destLat, lon: destLon }
            );
            eta = Math.ceil(route.durationSeconds / 60);
        } catch (e) {
            console.error("[DayPulseRoute] ETA calculation failed:", e);
        }
    }

    return {
        startLocation: startLat ? { lat: startLat, lon: startLon, name: startLocation?.name } : startLocation,
        destinationLocation: destLat ? { lat: destLat, lon: destLon, name: locationText || destinationLocation?.name } : (locationText ? { name: locationText } : null),
        eta
    };
}

router.post("/day-pulse/modify", async (req: Request, res: Response) => {
    try {
        const { userId: bodyUserId, deviceId, eventId, updates, isRecurring, days, date: reqDate } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "user1";
        console.log(`[DayPulseRoute] Proposing modification for event ${eventId} for user ${userId}`);

        const date = reqDate || new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        
        // Apply modification in memory
        const block = timeline.blocks.find(b => b.eventId === eventId);
        if (block) {
            if (isRecurring && (block.type === 'routine' || eventId.startsWith('routine_'))) {
                const startTime = toRoutineClockTime(updates.startTime || updates.start_time) || block.startTime;
                const endTime = toRoutineClockTime(updates.endTime || updates.end_time) || block.endTime;

                await routineRepo.updateRoutine(userId, eventId, {
                    title: updates.title || block.title,
                    startTime,
                    endTime,
                    category: updates.category || block.category || 'buffer',
                    days: Array.isArray(days) ? days : (Array.isArray(updates.days) ? updates.days : block.days || []),
                    startLocation: updates.start_location || updates.startLocation || block.startLocation,
                    destinationLocation: updates.destination_location || updates.destinationLocation,
                    eta: block.etaMinutes,
                } as any);

                const refreshed = await dayPulseService.getDailyTimeline(userId, date);
                res.json({
                    ok: true,
                    data: { ...refreshed, isProposed: false },
                    message: "Recurring routine updated."
                });
                return;
            }

            Object.assign(block, updates);
            block.isProposed = true;
            // Re-resolve location and ETA in memory
            const { startLocation, destinationLocation, eta } = await resolveLocationAndEta(
                updates.start_location || updates.startLocation || block.startLocation, 
                updates.location_text || updates.locationText || block.locationText,
                updates.destination_location || updates.destinationLocation
            );
            block.locationText = updates.location_text || updates.locationText || block.locationText;
            block.etaMinutes = eta || block.etaMinutes;
            block.startTime = updates.startTime || updates.start_time || block.startTime;
            block.endTime = updates.endTime || updates.end_time || block.endTime;
        }

        res.json({
            ok: true,
            data: { ...timeline, isProposed: true },
            message: "Modification proposed. Review and save permanently."
        });
    } catch (error) {
        res.status(500).json({ ok: false, error: "Could not propose modification" });
    }
});

router.post("/day-pulse/add", async (req: Request, res: Response) => {
    try {
        const { userId: bodyUserId, deviceId, event, category, date: reqDate, isRecurring, days } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "user1";
        
        const date = reqDate || new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);

        const { startLocation, destinationLocation, eta } = await resolveLocationAndEta(
            event.start_location || event.startLocation, 
            event.location_text || event.locationText,
            event.destination_location || event.destinationLocation
        );

        if (isRecurring && Array.isArray(days) && days.length > 0) {
            await routineRepo.addRoutine(userId, {
                title: event.title,
                startTime: toRoutineClockTime(event.start_time || event.startTime) || '09:00',
                endTime: toRoutineClockTime(event.end_time || event.endTime) || '10:00',
                category: category || 'buffer',
                days,
                startLocation: startLocation || event.start_location || event.startLocation || null,
                destinationLocation: destinationLocation || event.destination_location || event.destinationLocation || null,
                eta: eta ?? null,
            });

            const refreshed = await dayPulseService.getDailyTimeline(userId, date);
            res.json({
                ok: true,
                data: { ...refreshed, isProposed: false },
                message: "Recurring routine saved."
            });
            return;
        }

        const newBlock: any = {
            eventId: event.id || `manual_${Date.now()}`,
            title: event.title,
            startTime: event.start_time,
            endTime: event.end_time,
            type: 'act',
            locationText: event.location_text || event.locationText,
            etaMinutes: eta,
            category: category || 'buffer',
            isProposed: true,
            risks: []
        };

        timeline.blocks.push(newBlock);
        timeline.blocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime());

        res.json({
            ok: true,
            data: { ...timeline, isProposed: true },
            message: "Event added as proposal."
        });
    } catch (error) {
        res.status(500).json({ ok: false, error: "Could not propose add" });
    }
});

router.post("/day-pulse/delete", async (req: Request, res: Response) => {
    try {
        const { userId: bodyUserId, deviceId, eventId, date: reqDate } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "user1";
        
        const date = reqDate || new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        
        const block = timeline.blocks.find(b => b.eventId === eventId);
        if (block) {
            block.isDeleted = true;
            block.isProposed = true;
        }

        res.json({
            ok: true,
            data: { ...timeline, isProposed: true },
            message: "Deletion proposed."
        });
    } catch (error) {
        res.status(500).json({ ok: false, error: "Could not propose delete" });
    }
});

router.post("/day-pulse/persist", async (req: Request, res: Response) => {
    try {
        const { userId: bodyUserId, deviceId, blocks } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "user1";
        
        console.log(`[DayPulseRoute] Persisting all changes for user ${userId}`);

        for (const block of blocks) {
            if (block.isProposed) {
                if (block.isDeleted) {
                    // Permanently delete or add override
                    await userEventsRepo.deleteManualEvent(userId, block.eventId);
                    await userEventsRepo.addOverride(userId, { userId, eventId: block.eventId, updates: {}, isDeleted: true });
                } else if (block.eventId.startsWith('manual_') || block.eventId.startsWith('charge_')) {
                    // Add new manual event
                    await userEventsRepo.addManualEvent(userId, {
                        id: block.eventId,
                        title: block.title,
                        start_time: block.startTime,
                        end_time: block.endTime,
                        location_text: block.locationText,
                        location: null,
                        importance: 'medium'
                    } as any);
                } else {
                    // Add override for existing event or routine
                    await userEventsRepo.addOverride(userId, {
                        userId,
                        eventId: block.eventId,
                        updates: {
                            title: block.title,
                            start_time: block.startTime,
                            end_time: block.endTime,
                            location_text: block.locationText
                        }
                    });
                }
            }
        }

        const date = req.body.date || new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);
        
        res.json({
            ok: true,
            data: timeline,
            message: "All changes saved permanently."
        });

        runAgentPulseFlow({ userId }, broadcast).catch(err => {
            console.error("[DayPulseRoute] Error triggering flow after persist:", err);
        });
    } catch (error) {
        console.error("[DayPulseRoute] Persist error:", error);
        res.status(500).json({ ok: false, error: "Could not save changes" });
    }
});

router.post("/pulse/action", async (req: Request, res: Response) => {
    try {
        const { userId: bodyUserId, deviceId, action } = req.body;
        const userId = req.header("X-User-Id") || bodyUserId || deviceId || "user1";
        const actionId = action.id;

        console.log(`[DayPulseRoute] Action dispatched: user=${userId}, actionId=${actionId}`);

        if (actionId.includes("ACTION_RECOMMEND_CHARGING_STOP")) {
            const date = new Date().toISOString().split('T')[0];
            const timeline = await dayPulseService.getDailyTimeline(userId, date);
            
            const targetEventId = action.appliesToEventId;
            const targetBlock = timeline.blocks.find(b => b.eventId === targetEventId) || 
                                timeline.blocks.find(b => new Date(b.startTime) > new Date());

            if (targetBlock) {
                const sortedBlocks = timeline.blocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime());
                const targetIndex = sortedBlocks.findIndex(b => b.eventId === targetBlock.eventId);
                
                let chargingStart: Date;
                let chargingEnd: Date;
                const duration = 20 * 60000; // 20 mins for a decent charge

                // Intelligent placement logic
                if (targetIndex > 0) {
                    const prevBlock = sortedBlocks[targetIndex - 1];
                    const gap = new Date(targetBlock.startTime).getTime() - new Date(prevBlock.endTime).getTime();
                    
                    if (gap >= duration) {
                        // Case A: There is a natural gap. Place it right in the middle.
                        console.log(`[DayPulseRoute] Found gap of ${Math.round(gap/60000)}m. Using it.`);
                        chargingStart = new Date(new Date(prevBlock.endTime).getTime() + (gap - duration) / 2);
                        chargingEnd = new Date(chargingStart.getTime() + duration);
                    } else if (prevBlock.category === 'buffer' || prevBlock.category === 'sleep') {
                        // Case B: Overlap with a low-priority buffer or sleep
                        console.log(`[DayPulseRoute] No gap, but prev event is ${prevBlock.category}. Squeezing in.`);
                        chargingStart = new Date(new Date(targetBlock.startTime).getTime() - duration);
                        chargingEnd = new Date(targetBlock.startTime);
                    } else {
                        // Case C: Tight schedule. Place before target and push everything.
                        console.log(`[DayPulseRoute] Tight schedule. Forcing stop before ${targetBlock.title}.`);
                        chargingStart = new Date(new Date(targetBlock.startTime).getTime() - duration);
                        chargingEnd = new Date(targetBlock.startTime);
                    }
                } else {
                    chargingStart = new Date(new Date(targetBlock.startTime).getTime() - duration);
                    chargingEnd = new Date(targetBlock.startTime);
                }

                console.log(`[DayPulseRoute] Intelligent charging stop for ${userId}: ${chargingStart.toLocaleTimeString()} - ${chargingEnd.toLocaleTimeString()}`);
                
                await userEventsRepo.addManualEvent(userId, {
                    id: `charge_${Date.now()}`,
                    title: "Charging Stop (Auto-Optimized)",
                    start_time: chargingStart.toISOString(),
                    end_time: chargingEnd.toISOString(),
                    category: 'buffer',
                    location_text: "Optimized Charging Point"
                } as any);

                // Apply cascading shifts to ensure no conflicts remain
                await dayPulseService.shiftEventsFollowing(userId, chargingEnd, date);
            }
        }

        const date = (req.body.date as string) || new Date().toISOString().split('T')[0];
        const timeline = await dayPulseService.getDailyTimeline(userId, date);

        res.json({
            ok: true,
            data: timeline,
            message: "Action processed and schedule updated."
        });
    } catch (error) {
        console.error("[DayPulseRoute] Error processing action:", error);
        res.status(500).json({
            ok: false,
            error: "Could not process pulse action"
        });
    }
});

export default router;
