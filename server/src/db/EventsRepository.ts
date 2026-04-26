import { contextSnapshotRepo } from "./ContextSnapshotRepository";
import { CalendarEvent } from "../../../shared/context_snapshot";

export interface IEventsRepository {
    getUpcoming(userId: string, options: { withinMinutes: number }): Promise<CalendarEvent[]>;
}

export class ContextEventsRepository implements IEventsRepository {
    async getUpcoming(userId: string, options: { withinMinutes: number }): Promise<CalendarEvent[]> {
        const latest = await contextSnapshotRepo.findLatestByUser(userId);
        if (!latest) return [];

        const now = new Date(latest.timestamp);
        const limit = new Date(now.getTime() + options.withinMinutes * 60000);

        // Filter events from the snapshot that are within the window
        return latest.calendar.upcoming_events.filter(event => {
            const startTime = new Date(event.start_time);
            return startTime >= now && startTime <= limit;
        });
    }

    async getNextEvent(userId: string): Promise<CalendarEvent | null> {
        const latest = await contextSnapshotRepo.findLatestByUser(userId);
        if (!latest || !latest.calendar.next_event) {
            // Fallback to first upcoming event if next_event is not explicitly set
            if (latest && latest.calendar.upcoming_events.length > 0) {
                return latest.calendar.upcoming_events[0];
            }
            return null;
        }
        return latest.calendar.next_event;
    }
}

export const eventsRepo = new ContextEventsRepository();
