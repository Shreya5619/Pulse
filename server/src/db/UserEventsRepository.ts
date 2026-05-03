import { query } from "./db";
import { CalendarEvent } from "../../../shared/context_snapshot";

export interface UserEventOverride {
    userId: string;
    eventId: string;
    updates: Partial<CalendarEvent>;
    isDeleted?: boolean;
}

export class UserEventsRepository {
    async getOverrides(userId: string): Promise<UserEventOverride[]> {
        const sql = `SELECT * FROM event_overrides WHERE user_id = $1`;
        const res = await query(sql, [userId]);
        return res.rows.map(row => ({
            userId: row.user_id,
            eventId: row.event_id,
            updates: row.updates,
            isDeleted: row.is_deleted
        }));
    }

    async addOverride(userId: string, override: UserEventOverride): Promise<void> {
        const sql = `
            INSERT INTO event_overrides (user_id, event_id, updates, is_deleted)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (user_id, event_id) 
            DO UPDATE SET updates = event_overrides.updates || $3, is_deleted = $4
        `;
        await query(sql, [userId, override.eventId, JSON.stringify(override.updates), override.isDeleted ?? false]);
    }

    async getManualEvents(userId: string): Promise<CalendarEvent[]> {
        const sql = `SELECT payload FROM manual_events WHERE user_id = $1`;
        const res = await query(sql, [userId]);
        return res.rows.map(row => row.payload as CalendarEvent);
    }

    async addManualEvent(userId: string, event: CalendarEvent): Promise<void> {
        const sql = `
            INSERT INTO manual_events (id, user_id, payload)
            VALUES ($1, $2, $3)
            ON CONFLICT (id) DO UPDATE SET payload = $3
        `;
        await query(sql, [event.id, userId, JSON.stringify(event)]);
    }

    async deleteManualEvent(userId: string, eventId: string): Promise<void> {
        const sql = `DELETE FROM manual_events WHERE id = $1 AND user_id = $2`;
        await query(sql, [eventId, userId]);
    }

    async deleteOverride(userId: string, eventId: string): Promise<void> {
        const sql = `DELETE FROM event_overrides WHERE user_id = $1 AND event_id = $2`;
        await query(sql, [userId, eventId]);
    }
}

export const userEventsRepo = new UserEventsRepository();
