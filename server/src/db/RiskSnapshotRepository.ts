import { query } from "./db";
import { RiskSnapshot, RiskScore } from "../types/risk";

export interface IRiskSnapshotRepository {
  save(snapshot: RiskSnapshot): Promise<void>;
  findLatest(userId: string): Promise<RiskSnapshot | null>;
  findRange(userId: string, from: Date, to: Date): Promise<RiskSnapshot[]>;
}

export class PostgresRiskSnapshotRepository implements IRiskSnapshotRepository {
  /**
   * Persist a RiskSnapshot.
   * Denormalises `top_score` and `risk_count` for efficient queries.
   */
  async save(snapshot: RiskSnapshot): Promise<void> {
    const topScore = snapshot.risks.length > 0
      ? Math.max(...snapshot.risks.map(r => r.score))
      : 0;

    const sql = `
      INSERT INTO risk_snapshots (user_id, timestamp, top_score, risk_count, risks)
      VALUES ($1, $2, $3, $4, $5)
    `;

    await query(sql, [
      snapshot.userId,
      snapshot.timestamp,
      topScore,
      snapshot.risks.length,
      JSON.stringify(snapshot.risks),
    ]);
  }

  /**
   * Load the most recent snapshot for a user.
   */
  async findLatest(userId: string): Promise<RiskSnapshot | null> {
    const sql = `
      SELECT user_id, timestamp, risks
      FROM risk_snapshots
      WHERE user_id = $1
      ORDER BY timestamp DESC
      LIMIT 1
    `;
    const res = await query(sql, [userId]);

    if (res.rows.length === 0) return null;

    const row = res.rows[0];
    return {
      userId: row.user_id,
      timestamp: row.timestamp,
      risks: row.risks as RiskScore[],
    };
  }

  /**
   * Load all snapshots for a user within a time window (inclusive).
   */
  async findRange(userId: string, from: Date, to: Date): Promise<RiskSnapshot[]> {
    const sql = `
      SELECT user_id, timestamp, risks
      FROM risk_snapshots
      WHERE user_id = $1
        AND timestamp >= $2
        AND timestamp <= $3
      ORDER BY timestamp ASC
    `;
    const res = await query(sql, [userId, from.toISOString(), to.toISOString()]);

    return res.rows.map(row => ({
      userId: row.user_id,
      timestamp: row.timestamp,
      risks: row.risks as RiskScore[],
    }));
  }
}

export const riskSnapshotRepo = new PostgresRiskSnapshotRepository();
