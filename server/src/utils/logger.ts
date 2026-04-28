export type LogPhase = "CONTEXT" | "GRAPH" | "RISK" | "FUTURES" | "PLANNER" | "GUARDIAN";

export type LogEvent = {
  ts: string;
  userId: string;
  phase: LogPhase;
  summary: string;
  details?: unknown;
};

export function logEvent(e: LogEvent) {
  console.log("[PulseLog]", JSON.stringify(e));
  // In a real system, you'd also write this to a persistent log table or file
}
