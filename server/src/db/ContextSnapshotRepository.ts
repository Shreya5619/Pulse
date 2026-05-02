import { query } from "./db";
import { ContextSnapshot } from "../../../shared/context_snapshot";

export interface IContextSnapshotRepository {
    save(snapshot: ContextSnapshot): Promise<void>;
    findLatestByUser(userId: string): Promise<ContextSnapshot | null>;
    findRecent(userId: string, limit: number): Promise<ContextSnapshot[]>;
    findRange(userId: string, from: Date, to: Date): Promise<ContextSnapshot[]>;
}

export class PostgresContextSnapshotRepository implements IContextSnapshotRepository {
    async save(snapshot: ContextSnapshot): Promise<void> {
        const sql = `
            INSERT INTO context_snapshots (
                id, user_id, timestamp, payload, minutes_to_next_event, has_next_event
            ) VALUES ($1, $2, $3, $4, $5, $6)
        `;
        const params = [
            snapshot.id,
            snapshot.user_id,
            snapshot.timestamp,
            JSON.stringify(snapshot),
            snapshot.derived?.minutes_to_next_event ?? null,
            snapshot.derived?.has_next_event ?? false
        ];

        await query(sql, params);
    }

    async findLatestByUser(userId: string): Promise<ContextSnapshot | null> {
        const sql = `
            SELECT payload 
            FROM context_snapshots 
            WHERE user_id = $1 
            ORDER BY timestamp DESC 
            LIMIT 1
        `;
        const res = await query(sql, [userId]);
        
        if (res.rows.length === 0) return null;
        return res.rows[0].payload as ContextSnapshot;
    }

    async findRecent(userId: string, limit: number): Promise<ContextSnapshot[]> {
        const sql = `
            SELECT payload 
            FROM context_snapshots 
            WHERE user_id = $1 
            ORDER BY timestamp DESC 
            LIMIT $2
        `;
        const res = await query(sql, [userId, limit]);
        return res.rows.map(row => row.payload as ContextSnapshot);
    }

    async findRange(userId: string, from: Date, to: Date): Promise<ContextSnapshot[]> {
        const sql = `
            SELECT payload 
            FROM context_snapshots 
            WHERE user_id = $1 
              AND timestamp >= $2 
              AND timestamp <= $3 
            ORDER BY timestamp ASC
        `;
        const res = await query(sql, [userId, from.toISOString(), to.toISOString()]);
        
        return res.rows.map(row => row.payload as ContextSnapshot);
    }
}

export const contextSnapshotRepo = new PostgresContextSnapshotRepository();
