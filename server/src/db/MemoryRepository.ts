import pool from "./db";
import { 
  MemoryState, 
  IdentityMemory, 
  HabitsMemory, 
  BatteryMemory, 
  CommuteMemory, 
  NotificationMemory 
} from "../../../shared/memory";

export const CURRENT_SCHEMA_VERSION = 1;

export class MemoryRepository {
  /**
   * Loads all memory types for a user and runs migrations if necessary.
   */
  async loadAll(userId: string): Promise<MemoryState> {
    const tables = [
      'memory_identity',
      'memory_habits',
      'memory_battery',
      'memory_notifications',
      'memory_commute'
    ];

    const state: any = {
      identity: null,
      habits: null,
      battery: null,
      notifications: null,
      commute: null
    };

    try {
      for (const table of tables) {
        const res = await pool.query(`SELECT * FROM ${table} WHERE user_id = $1`, [userId]);
        if (res.rows.length > 0) {
          let row = res.rows[0];
          
          // Migration Hook
          if (row.schema_version < CURRENT_SCHEMA_VERSION) {
            row = await this.migrate(table, row);
          }

          const type = table.replace('memory_', '');
          state[type] = row.data;
        }
      }
    } catch (error: any) {
      if (error.code === 'ECONNREFUSED') {
        throw new Error(`Database connection failed. Is Postgres/Docker running on ${error.address}:${error.port}?`);
      }
      throw error;
    }

    return state as MemoryState;
  }

  /**
   * Saves a specific memory type for a user (UPSERT).
   */
  async save(userId: string, type: keyof MemoryState, data: any, source: string = 'system'): Promise<void> {
    const table = `memory_${type}`;
    
    // Extract metadata if present in data object (from MemoryStore)
    const version = data.schema_version || CURRENT_SCHEMA_VERSION;
    const updatedAt = data.last_updated || new Date().toISOString();
    const finalSource = data.source || source;

    const query = `
      INSERT INTO ${table} (user_id, data, schema_version, last_updated, source)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (user_id) DO UPDATE SET
        data = EXCLUDED.data,
        schema_version = EXCLUDED.schema_version,
        last_updated = EXCLUDED.last_updated,
        source = EXCLUDED.source
    `;
    await pool.query(query, [userId, data, version, updatedAt, finalSource]);
  }

  /**
   * Stub for migration logic.
   */
  private async migrate(table: string, row: any): Promise<any> {
    console.log(`Migrating ${table} for user ${row.user_id} from v${row.schema_version} to v${CURRENT_SCHEMA_VERSION}`);
    
    // Perform transformations based on table and version
    // For now, we just bump the version
    const newData = row.data; 
    
    await pool.query(
      `UPDATE ${table} SET data = $1, schema_version = $2, last_updated = NOW() WHERE user_id = $3`,
      [newData, CURRENT_SCHEMA_VERSION, row.user_id]
    );

    return { ...row, data: newData, schema_version: CURRENT_SCHEMA_VERSION };
  }

  // Helpers for specific types as requested by "getHabits, getBatteryProfile do not change in signature"
  async getHabits(userId: string): Promise<HabitsMemory | null> {
    const res = await pool.query('SELECT data FROM memory_habits WHERE user_id = $1', [userId]);
    return res.rows[0]?.data || null;
  }

  async getBatteryProfile(userId: string): Promise<BatteryMemory | null> {
    const res = await pool.query('SELECT data FROM memory_battery WHERE user_id = $1', [userId]);
    return res.rows[0]?.data || null;
  }
}

export const memoryRepository = new MemoryRepository();
