"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.heartbeatAgent = heartbeatAgent;
const HeartbeatOrchestrator_1 = require("../../server/src/services/HeartbeatOrchestrator");
/**
 * Heartbeat Agent
 * Manages the periodic evaluation cycle.
 *
 * @param userId - The user to run the heartbeat for.
 * @returns result - The full execution result from the orchestrator.
 */
async function heartbeatAgent(userId = "demo-user") {
    console.log(`[HeartbeatAgent] Triggering orchestrated cycle for ${userId}...`);
    const result = await HeartbeatOrchestrator_1.heartbeatOrchestrator.runOnce(userId);
    return {
        timestamp: new Date().toISOString(),
        event: "cycle_tick",
        status: "completed",
        result
    };
}
