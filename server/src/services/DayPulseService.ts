import { eventsRepo } from "../db/EventsRepository";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { riskEngine } from "./RiskEngineService";
import { plannerEngine } from "./PlannerEngine";
import { assessLateness, assessBattery } from "./RiskEngine";
import { GraphAdapter } from "./GraphAdapter";
import { CalendarEvent } from "../../../shared/context_snapshot";

export interface DayPulseBlock {
    eventId: string;
    title: string;
    startTime: string;
    endTime: string;
    risks: {
        type: 'lateness' | 'battery' | 'overload';
        level: 'low' | 'medium' | 'high';
        score: number;
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
        const events = await eventsRepo.getForDay(userId, date);
        const context = await contextSnapshotRepo.findLatestByUser(userId);
        
        console.log(`[DayPulseService] Found ${events.length} events for date ${dateStr}. Latest snapshot exists: ${!!context}`);
        if (context) {
            console.log(`[DayPulseService] Latest snapshot timestamp: ${context.timestamp}`);
            console.log(`[DayPulseService] Total upcoming_events in snapshot: ${context.calendar.upcoming_events.length}`);
            if (events.length === 0 && context.calendar.upcoming_events.length > 0) {
                console.log(`[DayPulseService] Date mismatch? First event in snapshot is at: ${context.calendar.upcoming_events[0].start_time}`);
            }
        }

        const personality = await GraphAdapter.getUserPersonality(userId);

        const blocks: DayPulseBlock[] = [];

        // Simulate risk for each event block
        for (const event of events) {
            const risks = await this.simulateRisksForEvent(userId, event, context, personality);
            
            // Get a suggestion for the highest risk if any
            let suggestion;
            if (risks.length > 0) {
                const topRisk = risks.sort((a, b) => b.score - a.score)[0];
                const actions = await plannerEngine.getActionsForRisk(userId, topRisk.type, event.id);
                if (actions.length > 0) {
                    suggestion = {
                        title: actions[0].title,
                        actionId: actions[0].id
                    };
                }
            }

            blocks.push({
                eventId: event.id || `event_${event.title.hashCode}`,
                title: event.title,
                startTime: event.start_time,
                endTime: event.end_time,
                risks,
                suggestion
            });
        }

        return {
            userId,
            date: dateStr,
            blocks: blocks.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime())
        };
    }

    private async simulateRisksForEvent(userId: string, event: CalendarEvent, context: any, personality: any): Promise<DayPulseBlock['risks']> {
        const risks: DayPulseBlock['risks'] = [];
        if (!context) return [];

        const now = new Date(context.timestamp);
        const eventStart = new Date(event.start_time);
        
        // 1. Lateness Risk (Heuristic)
        // If event is in the future, we estimate travel time
        const minutesToStart = (eventStart.getTime() - now.getTime()) / 60000;
        if (minutesToStart > 0 && minutesToStart < 120) {
            const lateness = assessLateness(
                minutesToStart,
                20, // Estimated 20 min travel
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
                    score: lateness.score
                });
            }
        }

        // 2. Battery Risk
        // Projected drain until event start
        const drainRate = 8; // 8% per hour active
        const hoursUntilStart = Math.max(0, minutesToStart / 60);
        const predictedLevel = (context.battery.level * 100) - (drainRate * hoursUntilStart);
        
        if (predictedLevel < 20) {
            risks.push({
                type: 'battery',
                level: predictedLevel < 10 ? 'high' : 'medium',
                score: (20 - predictedLevel) / 20
            });
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
