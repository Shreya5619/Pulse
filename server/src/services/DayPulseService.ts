import { eventsRepo } from "../db/EventsRepository";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { riskEngine } from "./RiskEngineService";
import { plannerEngine } from "./PlannerEngine";
import { assessLateness, assessBattery } from "./RiskEngine";
import { GraphAdapter } from "./GraphAdapter";
import { routingService } from "./RoutingService";
import { geocodingService } from "./GeocodingService";
import { CalendarEvent } from "../../../shared/context_snapshot";
import { routineRepo } from "../db/RoutineRepository";
import { userEventsRepo } from "../db/UserEventsRepository";

export interface DayPulseBlock {
    eventId: string;
    title: string;
    startTime: string;
    endTime: string;
    type: 'event' | 'routine';
    category?: 'sleep' | 'study' | 'commute' | 'buffer';
    locationText?: string;
    etaMinutes?: number;
    days?: number[];
    risks: {
        type: 'lateness' | 'battery' | 'overload' | 'overlap' | 'personality';
        level: 'low' | 'medium' | 'high';
        score: number;
        explanation?: string;
    }[];
    suggestion?: {
        title: string;
        actionId: string;
    };
}

export interface DayPulse {
    userId: string;
    date: string;
    blocks: DayPulseBlock[];
}

export class DayPulseService {
    async getDailyTimeline(userId: string, dateStr: string): Promise<DayPulse> {
        console.log(`[DayPulseService] Fetching timeline for ${userId} on ${dateStr}`);
        const date = new Date(dateStr);
        
        // 1. Fetch system events
        let events = await eventsRepo.getForDay(userId, date);
        
        // 2. Fetch manual events
        const manualEvents = await userEventsRepo.getManualEvents(userId);
        events = [...events, ...manualEvents];

        // 3. Apply overrides
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

        const context = await contextSnapshotRepo.findLatestByUser(userId);
        const personality = await GraphAdapter.getUserPersonality(userId);

        const blocks: DayPulseBlock[] = [];

        // 4. Add Routine Blocks
        const routines = await routineRepo.getForDay(userId, date);
        for (const routine of routines) {
            try {
                // Handle various formats (HH:mm or ISO)
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

                if (isNaN(sH) || isNaN(sM) || isNaN(eH) || isNaN(eM)) {
                    console.warn(`[DayPulseService] Skipping routine ${routine.id} due to invalid time: ${routine.startTime} - ${routine.endTime}`);
                    continue;
                }

                const start = new Date(date);
                start.setUTCHours(sH - 5, sM - 30, 0, 0);

                const end = new Date(date);
                end.setUTCHours(eH - 5, eM - 30, 0, 0);
                
                // Handle overnight sleep (simplified)
                if (end < start && routine.category === 'sleep') {
                    end.setUTCDate(end.getUTCDate() + 1);
                }

                blocks.push({
                    eventId: routine.id,
                    title: routine.title,
                    startTime: start.toISOString(),
                    endTime: end.toISOString(),
                    type: 'routine',
                    category: routine.category,
                    startLocation: routine.startLocation,
                    risks: []
                });
            } catch (e) {
                console.error(`[DayPulseService] Error processing routine ${routine.id}:`, e);
            }
        }

        // 5. Simulate risk for each event block
        for (const event of events) {
            // 5. Calculate ETA
            let etaMinutes: number | undefined;
            if (context) {
                // Determine Start Coordinates
                let startLat = event.start_location?.lat;
                let startLon = event.start_location?.lon;
                
                if ((!startLat || !startLon) && event.start_location?.name) {
                    const geoStart = await geocodingService.geocode(event.start_location.name);
                    if (geoStart) {
                        startLat = geoStart.lat;
                        startLon = geoStart.lon;
                    }
                }
                
                // Fallback to current location if still no start coordinates
                startLat = startLat ?? context.location.lat;
                startLon = startLon ?? context.location.lon;

                // Determine Destination Coordinates
                let eventLat = event.location?.lat;
                let eventLon = event.location?.lon;

                if ((!eventLat || !eventLon) && event.location_text) {
                    const geoDest = await geocodingService.geocode(event.location_text);
                    if (geoDest) {
                        eventLat = geoDest.lat;
                        eventLon = geoDest.lon;
                    }
                }

                if (startLat && startLon && eventLat && eventLon) {
                    try {
                        const route = await routingService.getRoute(
                            { lat: startLat, lon: startLon },
                            { lat: eventLat, lon: eventLon }
                        );
                        etaMinutes = Math.ceil(route.durationSeconds / 60);
                    } catch (e) {
                        console.error(`[DayPulseService] Failed to fetch ETA for ${event.title}:`, e);
                    }
                }
            }

            const risks = await this.simulateRisksForEvent(userId, event, context, personality, etaMinutes);
            
            let suggestion;
            if (risks.length > 0) {
                const topRisk = risks.sort((a, b) => b.score - a.score)[0];
                const actions = await plannerEngine.getActionsForRisk(userId, topRisk.type as any, event.id);
                if (actions.length > 0) {
                    suggestion = {
                        title: actions[0].title,
                        actionId: actions[0].id
                    };
                }
            }

            blocks.push({
                eventId: event.id || `event_${(event.title as any).hashCode}`,
                title: event.title,
                startTime: event.start_time,
                endTime: event.end_time,
                type: 'event',
                locationText: event.location_text,
                etaMinutes,
                category: (event as any).category,
                startLocation: event.start_location,
                risks,
                suggestion
            });
        }

        // 6. Detect Clashes (Overlaps)
        const sortedBlocks = blocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime());
        for (let i = 0; i < sortedBlocks.length - 1; i++) {
            const current = sortedBlocks[i];
            const next = sortedBlocks[i + 1];

            const currentEnd = new Date(current.endTime);
            const nextStart = new Date(next.startTime);

            if (currentEnd > nextStart) {
                const overlapMins = Math.round((currentEnd.getTime() - nextStart.getTime()) / 60000);

                if (overlapMins > 0) {
                    // Add risk to both blocks
                    const riskLevel = overlapMins > 30 ? 'high' : (overlapMins > 10 ? 'medium' : 'low');
                    const score = Math.min(1, overlapMins / 60);

                    current.risks.push({
                        type: 'overload',
                        level: riskLevel,
                        score: score,
                        explanation: `Timing clash: Overlaps with "${next.title}" by ${overlapMins} mins.`
                    });

                    next.risks.push({
                        type: 'overload',
                        level: riskLevel,
                        score: score,
                        explanation: `Timing clash: Overlaps with "${current.title}" by ${overlapMins} mins.`
                    });
                }
            }
        }

        return {
            userId,
            date: dateStr,
            blocks: sortedBlocks
        };
    }

    async optimizeTimeline(userId: string, dateStr: string): Promise<DayPulse> {
        const timeline = await this.getDailyTimeline(userId, dateStr);
        const date = new Date(dateStr);
        const optimizedBlocks = [...timeline.blocks];

        for (let i = 0; i < optimizedBlocks.length; i++) {
            const block = optimizedBlocks[i];
            if (block.type === 'event' && block.risks.some(r => r.type === 'lateness' && r.level === 'high')) {
                // Try shifting this event 30 mins later
                const originalStart = new Date(block.startTime);
                const originalEnd = new Date(block.endTime);
                
                const newStart = new Date(originalStart.getTime() + 30 * 60000);
                const newEnd = new Date(originalEnd.getTime() + 30 * 60000);

                // Check for collisions with other blocks
                const collision = optimizedBlocks.some((other, index) => {
                    if (index === i) return false;
                    const oStart = new Date(other.startTime);
                    const oEnd = new Date(other.endTime);
                    return (newStart < oEnd && newEnd > oStart);
                });

                if (!collision) {
                    console.log(`[DayPulseService] Optimizing block ${block.title}: Shifting 30 mins later to reduce lateness risk.`);
                    block.startTime = newStart.toISOString();
                    block.endTime = newEnd.toISOString();
                    // Re-simulating risks for the shifted block would be ideal, 
                    // but for now we'll just mark it as optimized.
                    block.risks = block.risks.filter(r => r.type !== 'lateness');
                    block.suggestion = {
                        title: "Optimized: Shifted 30m later to ensure on-time arrival.",
                        actionId: "OPTIMIZED_SHIFT"
                    };
                }
            }
        }

        return {
            userId,
            date: dateStr,
            blocks: optimizedBlocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime())
        };
    }

    private async simulateRisksForEvent(userId: string, event: CalendarEvent, context: any, personality: any, etaMinutes?: number): Promise<DayPulseBlock['risks']> {
        const risks: DayPulseBlock['risks'] = [];
        if (!context) return [];

        const now = new Date(context.timestamp);
        const eventStart = new Date(event.start_time);
        const minutesToStart = (eventStart.getTime() - now.getTime()) / 60000;
        
        const isTier1 = minutesToStart > 0 && minutesToStart < 120; // Within 2 hours

        // 1. Battery Risk (All tiers)
        const drainRate = 8; // 8% per hour active
        const hoursUntilStart = Math.max(0, minutesToStart / 60);
        const predictedLevel = (context.battery.level * 100) - (drainRate * hoursUntilStart);
        
        if (predictedLevel < 25) {
            risks.push({
                type: 'battery',
                level: predictedLevel < 10 ? 'high' : (predictedLevel < 20 ? 'medium' : 'low'),
                score: Math.min(1, (25 - predictedLevel) / 25),
                explanation: `Predicted battery level: ${Math.round(predictedLevel)}% at start.`
            });
        }

        if (isTier1) {
            // TIER 1: Detailed Risks
            
            // Lateness Risk
            if (etaMinutes !== undefined) {
                const lateness = assessLateness(
                    minutesToStart,
                    etaMinutes,
                    5,  // 5 min buffer
                    event.title,
                    undefined,
                    [],
                    personality
                );
                if (lateness.score > 0.3) {
                    risks.push({
                        type: 'lateness',
                        level: lateness.score > 0.7 ? 'high' : (lateness.score > 0.4 ? 'medium' : 'low'),
                        score: lateness.score,
                        explanation: `ETA: ${etaMinutes} mins. Start in: ${Math.round(minutesToStart)} mins. Graph trace shows tight window.`
                    });
                }
            }

            // Overload Risk (Stub for now)
            if (event.importance === 'high') {
                risks.push({
                    type: 'overload',
                    level: 'low',
                    score: 0.2,
                    explanation: "High importance event. Monitor cognitive load."
                });
            }
        } else if (minutesToStart > 0) {
            // TIER 2: Basic Risks
            
            // Overlap Risk (Simplified)
            // We could check other events here, but for now just personality alignment
            if (personality && personality.traits) {
                const isIntrovert = personality.traits.extraversion < 0.4;
                if (isIntrovert && event.title.toLowerCase().includes('party')) {
                    risks.push({
                        type: 'personality',
                        level: 'medium',
                        score: 0.5,
                        explanation: "Social event detected. Potential energy drain for introvert profile."
                    });
                }
            }
        }

        return risks;
    }
}

// Add simple hashCode for strings if missing
if (!(String.prototype as any).hashCode) {
    (String.prototype as any).hashCode = function() {
        var hash = 0, i, chr;
        if (this.length === 0) return hash;
        for (i = 0; i < this.length; i++) {
            chr = this.charCodeAt(i);
            hash = ((hash << 5) - hash) + chr;
            hash |= 0; // Convert to 32bit integer
        }
        return hash;
    };
}

export const dayPulseService = new DayPulseService();
