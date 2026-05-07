import { PlannerAction } from "../../shared/planner";

export interface HeartbeatConfig {
  heartbeatIntervalMs: number;
  nightHeartbeatIntervalMs: number;
  maxAutoActionsPerHour: number;
  allowAutoSafeActions: boolean;
}

// Simple in-memory tracker for auto-actions
let autoActionsThisHour = 0;
let lastHourReset = Date.now();

/**
 * Guardian Agent
 * Acts as a safety and UX gatekeeper for proposed actions.
 */
export async function guardianAgent(
  chosenAction: PlannerAction | null, 
  config?: HeartbeatConfig
): Promise<{ 
  mode: "AUTO" | "ASK" | "BLOCK"; 
  approved: boolean; 
  rationale: string 
}> {
  console.log("Guardian Agent: Validating action safety...");

  if (!chosenAction) {
    return {
      mode: "AUTO",
      approved: true,
      rationale: "No action proposed, system in neutral state."
    };
  }

  // Reset hourly counter if needed
  const now = Date.now();
  if (now - lastHourReset > 3600000) {
    autoActionsThisHour = 0;
    lastHourReset = now;
  }

  // Safety Policy Checks
  let mode: "AUTO" | "ASK" | "BLOCK" = "ASK";
  let approved = true;
  let rationale = `Action '${chosenAction.title}' requires user confirmation.`;

  const isSafeAction = chosenAction.id.startsWith('MUTE') || chosenAction.id.startsWith('BATTERY_OPTIMIZE');

  if (config) {
    if (isSafeAction && config.allowAutoSafeActions) {
      if (autoActionsThisHour < config.maxAutoActionsPerHour) {
        mode = "AUTO";
        autoActionsThisHour++;
        rationale = `Safe action '${chosenAction.title}' auto-approved by policy (Quota: ${autoActionsThisHour}/${config.maxAutoActionsPerHour}).`;
      } else {
        mode = "ASK";
        rationale = `Action '${chosenAction.title}' downgraded to ASK: Hourly auto-action quota exceeded (${config.maxAutoActionsPerHour}).`;
      }
    }
  }

  return { mode, approved, rationale };
}
