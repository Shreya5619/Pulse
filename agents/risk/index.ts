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
import { riskEngine } from "../../server/src/services/RiskEngineService";
import { RiskSnapshot } from "../../server/src/types/risk";

export async function riskAgent(input: any): Promise<RiskSnapshot> {
  const userId = typeof input === "string" ? input : (input?.userId || "demo-user");

  console.log(`[RiskAgent] Computing risk for ${userId}...`);
  const snapshot = await riskEngine.computeForUser(userId);

  return snapshot;
}
