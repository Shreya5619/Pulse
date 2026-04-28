import { heartbeatOrchestrator } from "../../server/src/services/HeartbeatOrchestrator";

/**
 * Heartbeat Agent
 * Manages the periodic evaluation cycle.
 * 
 * @param userId - The user to run the heartbeat for.
 * @returns result - The full execution result from the orchestrator.
 */
export async function heartbeatAgent(userId: string = "demo-user"): Promise<any> {
  console.log(`[HeartbeatAgent] Triggering orchestrated cycle for ${userId}...`);

  const result = await heartbeatOrchestrator.runOnce(userId);

  return {
    timestamp: new Date().toISOString(),
    event: "cycle_tick",
    status: "completed",
    result
  };
}
