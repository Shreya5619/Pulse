import pool from "../../db/db";

export class SummarizerEngine {
    async runDailyCompression(userId: string, dateStr: string): Promise<void> {
        // Extract raw events for the day
        const eventsRes = await pool.query(
            `SELECT * FROM life_canvas_events WHERE user_id = $1 AND timestamp::date = $2::date`,
            [userId, dateStr]
        );
        
        const events = eventsRes.rows;
        if (events.length === 0) return;

        // Generate summary (Mocked logic)
        const summaryText = "Daily summary of " + events.length + " events";
        const keyEvents = events.slice(0, 3).map(e => e.id);
        const patterns = [{"type": "routine", "desc": "Morning workout"}];
        const emotionalTrend = "Neutral";

        await pool.query(
            `INSERT INTO life_canvas_summaries (user_id, layer, period_start, period_end, summary, key_events, patterns, emotional_trend)
             VALUES ($1, 'DAILY', $2, $3, $4, $5, $6, $7)`,
            [userId, dateStr + "T00:00:00Z", dateStr + "T23:59:59Z", summaryText, JSON.stringify(keyEvents), JSON.stringify(patterns), emotionalTrend]
        );
    }
}

export const summarizerEngine = new SummarizerEngine();
