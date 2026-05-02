import pool from "../../db/db";
import { LifeCanvasEvent } from "../../types/lifecanvas";

export class MemoryIngestor {
    async ingest(userId: string, transcript: string, timestamp: string): Promise<void> {
        // Mock classification
        const type = "EVENT"; 
        const tags = ["audio_ingest"];
        const entities = {};
        const importance = 0.5;

        // Deduplication
        const isDuplicate = await this.checkDuplicate(userId, transcript, timestamp);
        if (isDuplicate) return;

        // Persist Event
        const eventRes = await pool.query(
            `INSERT INTO life_canvas_events (user_id, type, timestamp, tags, entities, importance, text_content)
             VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
            [userId, type, timestamp, JSON.stringify(tags), JSON.stringify(entities), importance, transcript]
        );
        const eventId = eventRes.rows[0].id;

        // Integrate with Life Graph
        await pool.query(
            `INSERT INTO life_graph_nodes (user_id, type, label, importance, metadata)
             VALUES ($1, $2, $3, $4, $5)`,
            [userId, "LIFE_EVENT", transcript.substring(0, 50), importance, JSON.stringify({ eventId })]
        );
    }

    private async checkDuplicate(userId: string, transcript: string, timestamp: string): Promise<boolean> {
        return false;
    }
}

export const memoryIngestor = new MemoryIngestor();
