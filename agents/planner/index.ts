import { plannerEngine } from "../../server/src/services/PlannerEngine";
import { plannerRepo } from "../../server/src/db/PlannerRepository";

/**
 * Planner Agent
 * Proposes interventions to mitigate identified risks.
 * 
 * @param initialContext - The user context.
 * @returns decision - A PlannerDecision object.
 */
export async function plannerAgent(input: any): Promise<any> {
  const userId = typeof input === "string" ? input : (input?.userId || "demo-user");
  const decision = await plannerEngine.decideForUser(userId);

  console.log("[PlannerAgent] Decision:", JSON.stringify(decision, null, 2));
  
  // Persist decision for auditing
  await plannerRepo.save(decision).catch(err => {
    console.error("[PlannerAgent] Failed to save decision:", err);
  });
  
  return decision;
}
