import { ActionId, PlannerAction, PlannerDecision } from "../../../shared/planner";
import { riskEngine } from "./RiskEngineService";
import { futuresEngine } from "./FuturesEngine";
import { memoryStore } from "./MemoryStore";
import { RiskSnapshot } from "../types/risk";
import { FuturesResult } from "../types/futures";
import { MemoryState } from "../../../shared/memory";

class PlannerEngine {
  async decideForUser(userId: string): Promise<PlannerDecision> {
    const now = new Date().toISOString();
    const riskSnapshot = await riskEngine.computeForUser(userId);
    const futures = await futuresEngine.computeForUser(userId);
    const memory = await memoryStore.loadAll(userId);

    const candidates = this.buildCandidates(riskSnapshot, futures, memory);
    const chosen = this.pickBest(candidates, memory);

    return {
      userId,
      timestamp: now,
      chosen,
      alternatives: candidates.filter(c => c.id !== chosen?.id)
    };
  }

  private buildCandidates(
    risk: RiskSnapshot,
    futures: FuturesResult,
    memory: MemoryState
  ): PlannerAction[] {
    const candidates: PlannerAction[] = [];

    const lateness = risk.risks.find(r => r.type === "lateness");
    const battery  = risk.risks.find(r => r.type === "battery");
    const overload = risk.risks.find(r => r.type === "overload");
    const response = risk.risks.find(r => r.type === "response_debt");

    // Lateness intervention
    if (lateness && lateness.score >= 0.6) {
      candidates.push({
        id: "ACTION_LEAVE_NOW",
        title: "Leave now for your next commitment",
        description: "Based on traffic and your usual buffer, leaving now reduces your risk of being late.",
        approvalMode: "ASK_FIRST",
        reasons: lateness.causes || [],
        sideEffects: ["May trigger navigation", "May send an optional delay message"],
        appliesToEventId: lateness.nodeId
      });
    }

    // Battery intervention
    if (battery && battery.score >= 0.6) {
      candidates.push({
        id: "ACTION_ENABLE_BATTERY_SAVER",
        title: "Enable Battery Saver",
        description: "Battery is likely to fall below a safe level before your next event.",
        approvalMode: "ASK_FIRST",
        reasons: battery.causes || [],
        sideEffects: ["Reduces background activity", "May delay some notifications"]
      });
    }

    // Overload / notifications
    if (overload && overload.score >= 0.6) {
      candidates.push({
        id: "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
        title: "Silence noisy apps for 1 hour",
        description: "You have a dense schedule and many notifications; muting noisy apps lowers overload.",
        approvalMode: "ASK_FIRST",
        reasons: overload.causes || [],
        sideEffects: ["Temporarily mutes selected apps"]
      });
    }

    // Response debt
    if (response && response.score >= 0.6) {
      candidates.push({
        id: "ACTION_PREPARE_DELAY_MESSAGE",
        title: "Draft a quick update",
        description: "You have pending messages to important contacts; Pulse can draft a short update.",
        approvalMode: "ASK_FIRST",
        reasons: response.causes || [],
        sideEffects: ["Creates a draft, you tap to send"]
      });
    }

    // Charging stop (from Futures)
    const alt = futures.futures.find(f => f.id === "ALTERNATE");
    if (alt && alt.metrics.batteryPercent !== undefined && alt.metrics.batteryPercent > 20) {
      candidates.push({
        id: "ACTION_RECOMMEND_CHARGING_STOP",
        title: "Add a short charging stop",
        description: "A brief charging stop keeps your battery safe for the rest of the trip.",
        approvalMode: "ASK_FIRST",
        reasons: [`Alternate future keeps battery at ~${Math.round(alt.metrics.batteryPercent)}%`],
        sideEffects: ["Slightly changes route or departure time"]
      });
    }

    return candidates;
  }

  private pickBest(candidates: PlannerAction[], memory: MemoryState): PlannerAction | null {
    if (candidates.length === 0) return null;

    // priority order: lateness > battery > overload/response
    const priorities: ActionId[] = [
      "ACTION_LEAVE_NOW",
      "ACTION_ENABLE_BATTERY_SAVER",
      "ACTION_RECOMMEND_CHARGING_STOP",
      "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
      "ACTION_PREPARE_DELAY_MESSAGE"
    ];

    const preferred = [...candidates].sort((a, b) =>
      priorities.indexOf(a.id) - priorities.indexOf(b.id)
    );

    return preferred[0];
  }
}

export const plannerEngine = new PlannerEngine();
