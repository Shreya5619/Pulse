/**
 * Risk Model Types for the Pulse Assistant
 *
 * These types define the structured output of the Risk Engine,
 * providing deterministic heuristic-based risk assessments.
 */

/** Categories of risk the engine can detect. */
export type RiskType = "lateness" | "battery" | "response_debt" | "overload";

/** Severity bands for human-readable risk classification. */
export type RiskLabel = "LOW" | "MEDIUM" | "HIGH";

/**
 * A single scored risk with an explanation.
 *
 * - `score` ∈ [0, 1]: 0 = no concern, 1 = critical.
 * - `label`: derived from `score` thresholds (≥0.7 HIGH, ≥0.4 MEDIUM, else LOW).
 * - `nodeId`: optional link to the graph node that triggered this risk.
 * - `summary`: one-line human-readable explanation.
 * - `causes`: detailed list of contributing factors.
 */
export interface RiskScore {
  type: RiskType;
  score: number;
  label: RiskLabel;
  nodeId?: string;
  summary: string;
  causes: string[];
}

/**
 * A point-in-time snapshot of all active risks for a user.
 */
export interface RiskSnapshot {
  userId: string;
  timestamp: string;
  risks: RiskScore[];
}
