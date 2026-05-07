import fs from 'fs';
import path from 'path';

export interface HeartbeatConfig {
  heartbeatIntervalMs: number;
  nightHeartbeatIntervalMs: number;
  maxAutoActionsPerHour: number;
  allowAutoSafeActions: boolean;
}

const DEFAULT_CONFIG: HeartbeatConfig = {
  heartbeatIntervalMs: 300000,
  nightHeartbeatIntervalMs: 900000,
  maxAutoActionsPerHour: 3,
  allowAutoSafeActions: true
};

const MEMORY_DIR = path.resolve(__dirname, '../../../memory');
const CONFIG_FILE = path.join(MEMORY_DIR, 'HEARTBEAT.md');

export function loadHeartbeatConfig(): HeartbeatConfig {
  try {
    if (!fs.existsSync(CONFIG_FILE)) {
      console.warn(`[Config] HEARTBEAT.md not found at ${CONFIG_FILE}, using defaults.`);
      return DEFAULT_CONFIG;
    }

    const content = fs.readFileSync(CONFIG_FILE, 'utf8');
    const jsonMatch = content.match(/```jsonc?\n([\s\S]*?)\n```/);

    if (!jsonMatch) {
      console.warn(`[Config] No JSON block found in HEARTBEAT.md, using defaults.`);
      return DEFAULT_CONFIG;
    }

    const jsonStr = jsonMatch[1].replace(/\/\/.*$/gm, ''); // Remove single-line comments
    const config = JSON.parse(jsonStr);

    return {
      heartbeatIntervalMs: config.heartbeat_interval_ms ?? DEFAULT_CONFIG.heartbeatIntervalMs,
      nightHeartbeatIntervalMs: config.night_heartbeat_interval_ms ?? DEFAULT_CONFIG.nightHeartbeatIntervalMs,
      maxAutoActionsPerHour: config.max_auto_actions_per_hour ?? DEFAULT_CONFIG.maxAutoActionsPerHour,
      allowAutoSafeActions: config.allow_auto_safe_actions ?? DEFAULT_CONFIG.allowAutoSafeActions
    };
  } catch (error) {
    console.error(`[Config] Failed to parse HEARTBEAT.md:`, error);
    return DEFAULT_CONFIG;
  }
}

export const heartbeatConfig = loadHeartbeatConfig();
