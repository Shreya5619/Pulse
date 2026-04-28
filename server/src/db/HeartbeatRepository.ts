import { query } from "./db";

export interface HeartbeatAuditRecord {
  userId: string;
  startedAt: string;
  finishedAt: string;
  contextId?: string;
  riskSnapshot: any;
  futuresResult: any;
  plannerDecision: any;
  guardianDecision: any;
}

export class HeartbeatRepository {
  async save(record: HeartbeatAuditRecord): Promise<void> {
    const sql = `
      INSERT INTO heartbeat_audit (
        user_id,
        started_at,
        finished_at,
        context_id,
        risk_snapshot,
        futures_result,
        planner_decision,
        guardian_decision
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    `;

    const values = [
      record.userId,
      record.startedAt,
      record.finishedAt,
      record.contextId || null,
      JSON.stringify(record.riskSnapshot),
      JSON.stringify(record.futuresResult),
      JSON.stringify(record.plannerDecision),
      JSON.stringify(record.guardianDecision),
    ];

    await query(sql, values);
  }
}

export const heartbeatRepo = new HeartbeatRepository();
