import { eventsRepo } from "../db/EventsRepository";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { riskEngine } from "./RiskEngineService";
import { plannerEngine } from "./PlannerEngine";
import { assessLateness, assessBattery } from "./RiskEngine";
import { GraphAdapter } from "./GraphAdapter";
import { routingService } from "./RoutingService";
import { geocodingService, GeocodingService } from "./GeocodingService";
import { CalendarEvent } from "../../../shared/context_snapshot";
import { routineRepo } from "../db/RoutineRepository";
import { userEventsRepo } from "../db/UserEventsRepository";

export interface DayPulseBlock {
    eventId: string;
    title: string;
    startTime: string;
    endTime: string;
    type: 'event' | 'routine' | 'act';
    category?: 'sleep' | 'study' | 'commute' | 'buffer' | 'charging';
    locationText?: string;
    etaMinutes?: number;
    batteryAtStart?: number;
    days?: number[];
    startLocation?: {
        lat?: number | null;
        lon?: number | null;
        name?: string | null;
    } | null;
    risks: {
        type: 'lateness' | 'battery' | 'overload' | 'overlap' | 'personality';
        level: 'low' | 'medium' | 'high';
        score: number;
        explanation?: string;
    }[];
    isProposed?: boolean;
    isDeleted?: boolean;
    suggestion?: {
        title: string;
        actionId: string;
    };
}

export interface DayPulse {
    userId: string;
    date: string;
    blocks: DayPulseBlock[];
    isProposed?: boolean;
}

export class DayPulseService {
    async getDailyTimeline(userId: string, dateStr: string): Promise<DayPulse> {
        console.log(`[DayPulseService] Fetching timeline for ${userId} on ${dateStr}`);
        const date = new Date(dateStr);
        const context = await contextSnapshotRepo.findLatestByUser(userId);
        const personality = await GraphAdapter.getUserPersonality(userId);
        
        // 1. Fetch system events & manual events
        let events = await eventsRepo.getForDay(userId, date);
        const manualEvents = await userEventsRepo.getManualEvents(userId);
        events = [...events, ...manualEvents];
 
        // 2. Apply overrides
        const overrides = await userEventsRepo.getOverrides(userId);
        events = events.map(event => {
            const override = overrides.find(o => o.eventId === event.id);
            if (override) {
                return { ...event, ...override.updates };
            }
            return event;
        }).filter(event => {
            const override = overrides.find(o => o.eventId === event.id);
            return !override?.isDeleted;
        });

        const blocks: DayPulseBlock[] = [];

        // 3. Add Routine Blocks
        const routines = await routineRepo.getForDay(userId, date);
        for (const routine of routines) {
            try {
                let sH, sM, eH, eM;
                if (routine.startTime.includes(':')) {
                    [sH, sM] = routine.startTime.split(':').map(Number);
                } else {
                    const d = new Date(routine.startTime);
                    sH = d.getHours();
                    sM = d.getMinutes();
                }

                if (routine.endTime.includes(':')) {
                    [eH, eM] = routine.endTime.split(':').map(Number);
                } else {
                    const d = new Date(routine.endTime);
                    eH = d.getHours();
                    eM = d.getMinutes();
                }

                if (isNaN(sH) || isNaN(sM) || isNaN(eH) || isNaN(eM)) continue;

                const start = new Date(date);
                start.setUTCHours(sH - 5, sM - 30, 0, 0);

                const end = new Date(date);
                end.setUTCHours(eH - 5, eM - 30, 0, 0);
                
                if (end < start && routine.category === 'sleep') {
                    end.setUTCDate(end.getUTCDate() + 1);
                }

                const block: DayPulseBlock = {
                    eventId: routine.id,
                    title: routine.title,
                    startTime: start.toISOString(),
                    endTime: end.toISOString(),
                    type: 'routine',
                    category: routine.category,
                    startLocation: routine.startLocation,
                    locationText: routine.destinationLocation?.name ?? undefined,
                    etaMinutes: routine.eta ?? undefined,
                    risks: []
                };

                const override = overrides.find(o => o.eventId === routine.id);
                if (override) {
                    if (override.isDeleted) continue;
                    Object.assign(block, override.updates);
                }

                blocks.push(block);
            } catch (e) {
                console.error(`[DayPulseService] Error routine ${routine.id}:`, e);
            }
        }

        // 4. Add Event Blocks
        for (const event of events) {
            let etaMinutes: number | undefined;
            if (context) {
                let startLat = event.start_location?.lat;
                let startLon = event.start_location?.lon;
                
                if ((!startLat || !startLon) && event.start_location?.name) {
                    const geoStart = await geocodingService.geocode(event.start_location.name);
                    if (geoStart) {
                        startLat = geoStart.lat;
                        startLon = geoStart.lon;
                    }
                }
                
                startLat = startLat ?? (context.location.lat ?? undefined);
                startLon = startLon ?? (context.location.lon ?? undefined);

                let eventLat = event.location?.lat;
                let eventLon = event.location?.lon;
                const locationQuery = event.location_text?.trim();
                const isVirtualLocation = locationQuery && /online|zoom|meet|teams|call|virtual|remote|none|n\/a|tbd/i.test(locationQuery);

                if ((!eventLat || !eventLon) && locationQuery && !isVirtualLocation) {
                    const geoDest = await geocodingService.geocode(locationQuery);
                    if (geoDest) {
                        eventLat = geoDest.lat;
                        eventLon = geoDest.lon;
                    }
                }

                if (startLat && startLon && eventLat && eventLon) {
                    try {
                        const route = await routingService.getRoute({ lat: startLat, lon: startLon }, { lat: eventLat, lon: eventLon });
                        etaMinutes = Math.ceil(route.durationSeconds / 60);
                    } catch (e) {}
                }
            }

            blocks.push({
                eventId: event.id || `event_${(event.title as any).hashCode}`,
                title: event.title,
                startTime: event.start_time,
                endTime: event.end_time,
                type: (event.location?.lat || event.location_text) ? 'event' : 'act',
                locationText: event.location_text ?? undefined,
                etaMinutes,
                category: (event as any).category,
                startLocation: event.start_location,
                risks: []
            });
        }

        // 5. SORT AND SIMULATE SEQUENTIALLY
        const sortedBlocks = blocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime());
        
        if (context) {
            let predictedBattery = context.battery.level * 100;
            let currentTime = new Date(context.timestamp);
            const drainRate = 8; // % per hour
            const chargeRate = 25; // % per hour

            for (const block of sortedBlocks) {
                const blockStart = new Date(block.startTime);
                const blockEnd = new Date(block.endTime);

                // Drain until block starts
                if (blockStart > currentTime) {
                    const idleHours = (blockStart.getTime() - currentTime.getTime()) / 3600000;
                    predictedBattery -= (idleHours * drainRate);
                }

                block.batteryAtStart = Math.max(0, Math.min(100, predictedBattery));
                
                // Simulate Risks with predicted battery
                block.risks = await this.simulateRisksForEvent(userId, block, context, personality, block.etaMinutes, block.batteryAtStart);
                
                // Add Suggestion
                if (block.risks.length > 0) {
                    const topRisk = block.risks.sort((a, b) => b.score - a.score)[0];
                    const actions = await plannerEngine.getActionsForRisk(userId, topRisk.type as any, block.eventId);
                    if (actions.length > 0) {
                        block.suggestion = { title: actions[0].title, actionId: actions[0].id };
                    }
                }

                // Update battery during the block
                const durationHours = (blockEnd.getTime() - blockStart.getTime()) / 3600000;
                const isChargingBlock = block.title.toLowerCase().includes("charging") || block.category === 'charging' || block.category === 'charge';
                
                if (isChargingBlock) {
                    predictedBattery += (durationHours * chargeRate);
                } else {
                    predictedBattery -= (durationHours * drainRate);
                }
                
                predictedBattery = Math.max(0, Math.min(100, predictedBattery));
                currentTime = blockEnd;
            }
        }

        // 6. Detect Clashes (Overlaps)
        for (let i = 0; i < sortedBlocks.length - 1; i++) {
            const current = sortedBlocks[i];
            const next = sortedBlocks[i + 1];
            const currentEnd = new Date(current.endTime);
            const nextStart = new Date(next.startTime);

            if (currentEnd > nextStart) {
                const overlapMins = Math.round((currentEnd.getTime() - nextStart.getTime()) / 60000);
                if (overlapMins > 0) {
                    const riskLevel = overlapMins > 30 ? 'high' : (overlapMins > 10 ? 'medium' : 'low');
                    const score = Math.min(1, overlapMins / 60);
                    current.risks.push({ type: 'overload', level: riskLevel, score: score, explanation: `Timing clash: Overlaps with "${next.title}" by ${overlapMins} mins.` });
                    next.risks.push({ type: 'overload', level: riskLevel, score: score, explanation: `Timing clash: Overlaps with "${current.title}" by ${overlapMins} mins.` });
                }
            }
        }

        return { userId, date: dateStr, blocks: sortedBlocks };
    }

    async optimizeTimeline(userId: string, dateStr: string): Promise<DayPulse> {
        const timeline = await this.getDailyTimeline(userId, dateStr);
        const optimizedBlocks = [...timeline.blocks];

        for (let i = 0; i < optimizedBlocks.length; i++) {
            const block = optimizedBlocks[i];
            if (block.type === 'event' && block.risks.some(r => r.type === 'lateness' && r.level === 'high')) {
                const originalStart = new Date(block.startTime);
                const originalEnd = new Date(block.endTime);
                const newStart = new Date(originalStart.getTime() + 30 * 60000);
                const newEnd = new Date(originalEnd.getTime() + 30 * 60000);

                const collision = optimizedBlocks.some((other, index) => {
                    if (index === i) return false;
                    const oStart = new Date(other.startTime);
                    const oEnd = new Date(other.endTime);
                    return (newStart < oEnd && newEnd > oStart);
                });

                if (!collision) {
                    block.startTime = newStart.toISOString();
                    block.endTime = newEnd.toISOString();
                    block.isProposed = true;
                    block.risks = block.risks.filter(r => r.type !== 'lateness');
                    block.suggestion = { title: "Optimized: Shifted 30m later to ensure on-time arrival.", actionId: "OPTIMIZED_SHIFT" };
                }
            }
        }

        return { userId, date: dateStr, isProposed: optimizedBlocks.some(b => b.isProposed), blocks: optimizedBlocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime()) };
    }

    private async simulateRisksForEvent(userId: string, block: any, context: any, personality: any, etaMinutes?: number, predictedBattery?: number): Promise<DayPulseBlock['risks']> {
        const risks: DayPulseBlock['risks'] = [];
        if (!context) return [];

        const now = new Date(context.timestamp);
        const eventStart = new Date(block.startTime);
        const minutesToStart = (eventStart.getTime() - now.getTime()) / 60000;
        const isTier1 = minutesToStart > -30 && minutesToStart < 180; // Relevant window

        // 1. Battery Risk
        const batteryLevel = predictedBattery ?? (context.battery.level * 100);
        const hasLocation = !!(block.locationText);

        if (batteryLevel < 25 || (!hasLocation && batteryLevel < 40)) {
            const riskLevel = batteryLevel < 15 ? 'high' : (batteryLevel < 25 ? 'medium' : 'low');
            risks.push({
                type: 'battery',
                level: riskLevel,
                score: Math.min(1, (40 - batteryLevel) / 40),
                explanation: `Predicted battery: ${Math.max(0, Math.min(100, batteryLevel)).toFixed(0)}% at start.`
            });
        }

        if (isTier1) {
            if (etaMinutes !== undefined) {
                const lateness = assessLateness(minutesToStart, etaMinutes, 5, block.title, undefined, [], personality);
                if (lateness.score > 0.3) {
                    risks.push({
                        type: 'lateness',
                        level: lateness.score > 0.7 ? 'high' : (lateness.score > 0.4 ? 'medium' : 'low'),
                        score: lateness.score,
                        explanation: `ETA: ${etaMinutes} mins. Window is tight.`
                    });
                }
            }
        }

        return risks;
    }

    async shiftEventsFollowing(userId: string, startTime: Date | string, dateStr: string): Promise<void> {
        const threshold = new Date(startTime);
        const timeline = await this.getDailyTimeline(userId, dateStr);
        let currentBoundary = threshold;
        const sortedBlocks = timeline.blocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime());
        
        for (const block of sortedBlocks) {
            const blockStart = new Date(block.startTime);
            const blockEnd = new Date(block.endTime);
            if (block.title.includes("Charging Stop")) continue;
            if (blockStart < currentBoundary && blockEnd > threshold) {
                const duration = blockEnd.getTime() - blockStart.getTime();
                const newStart = new Date(currentBoundary.getTime() + 2 * 60000);
                const newEnd = new Date(newStart.getTime() + duration);
                await userEventsRepo.addOverride(userId, { eventId: block.eventId, updates: { start_time: newStart.toISOString(), end_time: newEnd.toISOString() } });
                currentBoundary = newEnd;
            } else if (blockStart >= currentBoundary) {
                currentBoundary = blockEnd;
            }
        }
    }
}

if (!(String.prototype as any).hashCode) {
    (String.prototype as any).hashCode = function() {
        var hash = 0, i, chr;
        if (this.length === 0) return hash;
        for (i = 0; i < this.length; i++) {
            chr = this.charCodeAt(i);
            hash = ((hash << 5) - hash) + chr;
            hash |= 0;
        }
        return hash;
    };
}

export const dayPulseService = new DayPulseService();
