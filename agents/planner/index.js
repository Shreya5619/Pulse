"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.plannerAgent = plannerAgent;
const PlannerEngine_1 = require("../../server/src/services/PlannerEngine");
const PlannerRepository_1 = require("../../server/src/db/PlannerRepository");
/**
 * Planner Agent
 * Proposes interventions to mitigate identified risks.
 *
 * @param initialContext - The user context.
 * @returns decision - A PlannerDecision object.
 */
async function plannerAgent(input) {
    const userId = typeof input === "string" ? input : (input?.userId || "demo-user");
    const decision = await PlannerEngine_1.plannerEngine.decideForUser(userId);
    console.log("[PlannerAgent] Decision:", JSON.stringify(decision, null, 2));
    // Persist decision for auditing
    await PlannerRepository_1.plannerRepo.save(decision).catch(err => {
        console.error("[PlannerAgent] Failed to save decision:", err);
    });
    return decision;
}
