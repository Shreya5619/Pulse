"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.guardianAgent = guardianAgent;
/**
 * Guardian Agent
 * Acts as a safety and UX gatekeeper for proposed actions.
 *
 * @param chosenAction - The suggested action from Planner Agent.
 * @returns approvalDecision - Final determination on execution mode (auto, suggest, block).
 */
async function guardianAgent(chosenAction) {
    console.log("Guardian Agent: Validating action safety...");
    if (!chosenAction) {
        return {
            mode: "AUTO",
            approved: true,
            rationale: "No action proposed, system in neutral state."
        };
    }
    // TODO: Implement safety/policy checks based on chosenAction
    // For now, default to ASK for all significant actions
    return {
        mode: "ASK",
        approved: true,
        rationale: `Action '${chosenAction.title}' requires user confirmation as it involves device or schedule changes.`
    };
}
