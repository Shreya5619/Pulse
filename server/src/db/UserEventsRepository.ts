import { CalendarEvent } from "../../../shared/context_snapshot";

export interface UserEventOverride {
    userId: string;
    eventId: string;
    updates: Partial<CalendarEvent>;
    isDeleted?: boolean;
}

export class UserEventsRepository {
    private overrides: Map<string, UserEventOverride[]> = new Map();
    private manualEvents: Map<string, CalendarEvent[]> = new Map();

    async getOverrides(userId: string): Promise<UserEventOverride[]> {
        return this.overrides.get(userId) || [];
    }

    async addOverride(userId: string, override: UserEventOverride): Promise<void> {
        const userOverrides = this.overrides.get(userId) || [];
        const existing = userOverrides.findIndex(o => o.eventId === override.eventId);
        if (existing !== -1) {
            userOverrides[existing] = { ...userOverrides[existing], ...override };
        } else {
            userOverrides.push(override);
        }
        this.overrides.set(userId, userOverrides);
    }

    async getManualEvents(userId: string): Promise<CalendarEvent[]> {
        return this.manualEvents.get(userId) || [];
    }

    async addManualEvent(userId: string, event: CalendarEvent): Promise<void> {
        const events = this.manualEvents.get(userId) || [];
        events.push(event);
        this.manualEvents.set(userId, events);
    }

    async deleteManualEvent(userId: string, eventId: string): Promise<void> {
        const events = this.manualEvents.get(userId) || [];
        const filtered = events.filter(e => e.id !== eventId);
        this.manualEvents.set(userId, filtered);
    }

    async deleteOverride(userId: string, eventId: string): Promise<void> {
        const userOverrides = this.overrides.get(userId) || [];
        const filtered = userOverrides.filter(o => o.eventId !== eventId);
        this.overrides.set(userId, filtered);
    }
}

export const userEventsRepo = new UserEventsRepository();
