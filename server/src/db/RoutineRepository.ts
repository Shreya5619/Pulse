import { query } from "./db";

export interface RoutineBlock {
    id: string;
    userId: string;
    title: string;
    startTime: string; // HH:mm
    endTime: string;   // HH:mm
    category: 'sleep' | 'study' | 'commute' | 'buffer';
    days: number[]; // 0-6 (Sun-Sat)
    startLocation?: { lat?: number | null; lon?: number | null; name?: string | null } | null;
    destinationLocation?: { lat?: number | null; lon?: number | null; name?: string | null } | null;
    eta?: number | null;
}

export class RoutineRepository {
    async getForUser(userId: string): Promise<RoutineBlock[]> {
        const sql = `SELECT * FROM routines WHERE user_id = $1 OR user_id = 'demo-user'`;
        const res = await query(sql, [userId]);
        return res.rows.map(row => ({
            id: row.id,
            userId: row.user_id,
            title: row.title,
            startTime: row.start_time,
            endTime: row.end_time,
            category: row.category,
            days: row.days,
            startLocation: row.start_location,
            destinationLocation: row.destination_location,
            eta: row.eta
        }));
    }

    async getForDay(userId: string, date: Date): Promise<RoutineBlock[]> {
        const day = date.getDay();
        const routines = await this.getForUser(userId);
        return routines.filter(r => r.days.includes(day));
    }

    async addRoutine(userId: string, routine: Omit<RoutineBlock, 'id' | 'userId'>): Promise<RoutineBlock> {
        const id = `routine_${Date.now()}`;
        const sql = `
            INSERT INTO routines (id, user_id, title, start_time, end_time, category, days, start_location, destination_location, eta)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        `;
        await query(sql, [
            id, 
            userId, 
            routine.title, 
            routine.startTime, 
            routine.endTime, 
            routine.category, 
            routine.days, 
            routine.startLocation ? JSON.stringify(routine.startLocation) : null,
            routine.destinationLocation ? JSON.stringify(routine.destinationLocation) : null,
            routine.eta ?? null
        ]);
        return { ...routine, id, userId };
    }

    async updateRoutine(userId: string, routineId: string, updates: Partial<RoutineBlock>): Promise<void> {
        const current = await this.getRoutine(userId, routineId);
        if (!current) return;

        const updated = { ...current, ...updates };
        const sql = `
            UPDATE routines 
            SET title = $1, start_time = $2, end_time = $3, category = $4, days = $5, start_location = $6, destination_location = $7, eta = $8
            WHERE id = $9 AND user_id = $10
        `;
        await query(sql, [
            updated.title, 
            updated.startTime, 
            updated.endTime, 
            updated.category, 
            updated.days, 
            updated.startLocation ? JSON.stringify(updated.startLocation) : null,
            updated.destinationLocation ? JSON.stringify(updated.destinationLocation) : null,
            updated.eta ?? null,
            routineId, 
            userId
        ]);
    }

    async deleteRoutine(userId: string, routineId: string): Promise<void> {
        const sql = `DELETE FROM routines WHERE id = $1 AND user_id = $2`;
        await query(sql, [routineId, userId]);
    }

    private async getRoutine(userId: string, routineId: string): Promise<RoutineBlock | null> {
        const sql = `SELECT * FROM routines WHERE id = $1 AND (user_id = $2 OR user_id = 'demo-user')`;
        const res = await query(sql, [routineId, userId]);
        if (res.rows.length === 0) return null;
        const row = res.rows[0];
        return {
            id: row.id,
            userId: row.user_id,
            title: row.title,
            startTime: row.start_time,
            endTime: row.end_time,
            category: row.category,
            days: row.days,
            startLocation: row.start_location,
            destinationLocation: row.destination_location,
            eta: row.eta
        };
    }
}

export const routineRepo = new RoutineRepository();
