"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.heartbeatAgent = heartbeatAgent;
const MemoryAgent_1 = require("../../server/src/services/MemoryAgent");
/**
 * Heartbeat Agent
 * Manages the periodic evaluation cycle.
 *
 * @returns periodic tick/event - Signal to trigger the agent swarm loop.
 */
async function heartbeatAgent(userId = "user_123") {
    console.log("Heartbeat Agent: Emitting periodic tick...");
    // Check for memory summary updates
    await MemoryAgent_1.memoryAgent.onHeartbeat(userId);
    return {
        timestamp: new Date().toISOString(),
        event: "cycle_tick",
        sequence: 1
    };
}
