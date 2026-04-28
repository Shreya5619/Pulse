import { plannerEngine } from "../../server/src/services/PlannerEngine";

/**
 * Planner Agent
 * Proposes interventions to mitigate identified risks.
 * 
 * @param initialContext - The user context.
 * @returns decision - A PlannerDecision object.
 */
export async function plannerAgent(initialContext: any): Promise<any> {
  const userId = initialContext.userId || "demo-user";
  const decision = await plannerEngine.decideForUser(userId);

  console.log("[PlannerAgent] Decision:", JSON.stringify(decision, null, 2));
  
  return decision;
}
