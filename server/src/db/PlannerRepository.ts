import { query } from "./db";
import { PlannerDecision } from "../../../shared/planner";

export class PlannerRepository {
  async save(decision: PlannerDecision): Promise<void> {
    const sql = `
      INSERT INTO planner_decisions (
        user_id, 
        timestamp, 
        chosen_id, 
        chosen_title, 
        alternatives, 
        payload
      )
      VALUES ($1, $2, $3, $4, $5, $6)
    `;

    const values = [
      decision.userId,
      decision.timestamp,
      decision.chosen?.id || null,
      decision.chosen?.title || null,
      JSON.stringify(decision.alternatives),
      JSON.stringify(decision),
    ];

    await query(sql, values);
  }

  async findLatestByUser(userId: string): Promise<PlannerDecision | null> {
    const sql = `
      SELECT payload 
      FROM planner_decisions 
      WHERE user_id = $1 
      ORDER BY timestamp DESC 
      LIMIT 1
    `;
    const res = await query(sql, [userId]);
    return res.rows[0]?.payload || null;
  }
}

export const plannerRepo = new PlannerRepository();
