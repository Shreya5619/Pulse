import * as fs from "fs";
import * as path from "path";
import yaml from "js-yaml";
import { 
  MemoryState, 
  IdentityMemory, 
  HabitsMemory, 
  BatteryMemory, 
  CommuteMemory, 
  NotificationMemory 
} from "../../../shared/memory";
import { memoryRepository } from "../db/MemoryRepository";

export const CURRENT_SCHEMA_VERSION = 1;

export interface MemoryMetadata {
  schema_version: number;
  last_updated: string;
  source: string;
}

export class MemoryStore {
  private baseDir = path.join(process.cwd(), 'memory');

  /**
   * Loads all memory for a user. 
   * In dev, we primary from the filesystem.
   */
  async loadAll(userId: string): Promise<MemoryState> {
    const userDir = path.join(this.baseDir, userId);
    
    const state: MemoryState = {
      identity: null,
      habits: null,
      battery: null,
      commute: null,
      notifications: null
    };

    const types: (keyof MemoryState)[] = ['identity', 'habits', 'battery', 'commute', 'notifications'];

    for (const type of types) {
      const filePath = path.join(userDir, `${type}.yaml`);
      if (fs.existsSync(filePath)) {
        try {
          const content = fs.readFileSync(filePath, 'utf8');
          // Strip comments if needed, but js-yaml handles them
          const data = yaml.load(content) as any;
          
          // Migration Hook
          const migratedData = await this.migrateIfNeeded(type, data);
          state[type] = migratedData;
        } catch (error) {
          console.error(`[MemoryStore] Failed to load ${type} for ${userId}:`, error);
        }
      }
    }

    return state;
  }

  /**
   * Saves partial or full memory state.
   * Writes to both Filesystem and Postgres mirror.
   */
  async save(userId: string, partial: Partial<MemoryState>, source: string = 'system'): Promise<void> {
    const userDir = path.join(this.baseDir, userId);
    if (!fs.existsSync(userDir)) {
      fs.mkdirSync(userDir, { recursive: true });
    }

    const last_updated = new Date().toISOString();

    for (const [type, data] of Object.entries(partial)) {
      if (!data) continue;

      const memoryType = type as keyof MemoryState;
      const wrappedData = {
        ...data,
        schema_version: CURRENT_SCHEMA_VERSION,
        last_updated,
        source
      };

      // 1. Save to Filesystem
      const filePath = path.join(userDir, `${type}.yaml`);
      const yamlContent = yaml.dump(wrappedData, { indent: 2 });
      const header = `# Schema Version: ${CURRENT_SCHEMA_VERSION}\n# Last Updated: ${last_updated}\n# Source: ${source}\n\n`;
      fs.writeFileSync(filePath, header + yamlContent);

      // 2. Save to Postgres Mirror
      try {
        await memoryRepository.save(userId, memoryType, wrappedData, source);
      } catch (error) {
        console.warn(`[MemoryStore] Postgres mirror failed for ${type}:`, error);
      }
    }
  }

  // --- Specific Accessors ---

  async getHabits(userId: string): Promise<HabitsMemory | null> {
    const state = await this.loadAll(userId);
    return state.habits;
  }

  async getBatteryProfile(userId: string): Promise<BatteryMemory | null> {
    const state = await this.loadAll(userId);
    return state.battery;
  }

  async getIdentity(userId: string): Promise<IdentityMemory | null> {
    const state = await this.loadAll(userId);
    return state.identity;
  }

  /**
   * Migration Hook
   */
  private async migrateIfNeeded(type: string, data: any): Promise<any> {
    const version = data.schema_version || 0;
    if (version < CURRENT_SCHEMA_VERSION) {
      console.log(`[MemoryStore] Migrating ${type} from v${version} to v${CURRENT_SCHEMA_VERSION}`);
      // Add specific migration logic here
      data.schema_version = CURRENT_SCHEMA_VERSION;
      data.last_updated = new Date().toISOString();
    }
    return data;
  }
}

export const memoryStore = new MemoryStore();
