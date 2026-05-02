"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.riskAgent = riskAgent;
/**
 * Risk Agent
 * Quantifies failure probability across multiple dimensions (lateness, battery, etc.).
 *
 * Delegates to the RiskEngineService which builds a graph, reads memory,
 * and produces a full RiskSnapshot with human-readable explanations.
 *
 * @param context - The normalized world state from Context Agent.
 * @returns RiskSnapshot with scored risks across all dimensions.
 */
const RiskEngineService_1 = require("../../server/src/services/RiskEngineService");
async function riskAgent(input) {
    const userId = typeof input === "string" ? input : (input?.userId || "demo-user");
    console.log(`[RiskAgent] Computing risk for ${userId}...`);
    const snapshot = await RiskEngineService_1.riskEngine.computeForUser(userId);
    return snapshot;
}
