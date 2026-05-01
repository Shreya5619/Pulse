import { ActionId, PlannerAction, PlannerDecision } from "../../../shared/planner";
import { riskEngine } from "./RiskEngineService";
import { futuresEngine } from "./FuturesEngine";
import { memoryStore } from "./MemoryStore";
import { RiskSnapshot } from "../types/risk";
import { FuturesResult } from "../types/futures";
import { MemoryState } from "../../../shared/memory";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { GraphAdapter } from "./GraphAdapter";
import { PersonalityAnalysis } from "./PersonalityAnalyzer";

class PlannerEngine {
  async decideForUser(userId: string): Promise<PlannerDecision> {
    const now = new Date().toISOString();
    const riskSnapshot = await riskEngine.computeForUser(userId);
    const futures = await futuresEngine.computeForUser(userId);
    const memory = await memoryStore.loadAll(userId);
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const personality = await GraphAdapter.getUserPersonality(userId);

    const candidates = this.buildCandidates(riskSnapshot, futures, memory, context, personality);
    const chosen = this.pickBest(candidates, memory, personality);

    return {
      userId,
      timestamp: now,
      chosen,
      alternatives: candidates.filter(c => c.id !== chosen?.id)
    };
  }

  async getActionsForRisk(userId: string, riskType: string, nodeId?: string): Promise<PlannerAction[]> {
    const riskSnapshot = await riskEngine.computeForUser(userId);
    const futures = await futuresEngine.computeForUser(userId);
    const memory = await memoryStore.loadAll(userId);
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const personality = await GraphAdapter.getUserPersonality(userId);

    const allCandidates = this.buildCandidates(riskSnapshot, futures, memory, context, personality);

    // Filter candidates relevant to this risk type/node
    let relevant = allCandidates.filter(c => {
      if (riskType === 'lateness') return c.id === 'ACTION_LEAVE_NOW' || c.id === 'ACTION_RECOMMEND_CHARGING_STOP';
      if (riskType === 'battery') return c.id === 'ACTION_ENABLE_BATTERY_SAVER' || c.id === 'ACTION_RECOMMEND_CHARGING_STOP';
      if (riskType === 'overload') return c.id === 'ACTION_SUPPRESS_NOISY_NOTIFICATIONS';
      if (riskType === 'response_debt') return c.id === 'ACTION_PREPARE_DELAY_MESSAGE';
      return false;
    });

    // If we have a specific nodeId, prioritize actions that apply to it
    if (nodeId) {
      relevant = relevant.sort((a, b) => (a.appliesToEventId === nodeId ? -1 : 1));
    }

    // Ensure we have at least some generic actions if nothing specific found
    if (relevant.length === 0) {
      if (riskType === 'lateness') {
         relevant.push({
           id: "ACTION_PREPARE_DELAY_MESSAGE",
           title: "Send 'Running 10 minutes late'",
           description: "Quick update to the organizer.",
           approvalMode: "ASK_FIRST",
           reasons: ["Mitigate lateness impact"],
           sideEffects: []
         });
      }
    }

    return relevant.slice(0, 3);
  }

  private buildCandidates(
    risk: RiskSnapshot,
    futures: FuturesResult,
    memory: MemoryState,
    context: any,
    personality?: PersonalityAnalysis
  ): PlannerAction[] {
    const candidates: PlannerAction[] = [];
    const suggestedRecipient = context?.calendar?.next_event?.organizer_contact || "123-456-7890"; // Hardcoded fallback as requested


    const lateness = risk.risks.find(r => r.type === "lateness");
    const battery  = risk.risks.find(r => r.type === "battery");
    const overload = risk.risks.find(r => r.type === "overload");
    const response = risk.risks.find(r => r.type === "response_debt");

    // Lateness intervention
    if (lateness && lateness.score >= 0.6) {
      candidates.push({
        id: "ACTION_LEAVE_NOW",
        title: "Leave now and take cab to Office HQ",
        description: "Switching to a cab now saves 15 mins of walking in traffic.",
        approvalMode: "ASK_FIRST",
        reasons: lateness.causes || [],
        sideEffects: ["May trigger navigation", "May send an optional delay message"],
        appliesToEventId: lateness.nodeId,
        category: "Commute",
        impact: "Cuts lateness risk from High to Low",
        templateId: "ON_THE_WAY",
        channel: "SMS",
        suggestedRecipient
      });
    }

    // Battery intervention
    if (battery && battery.score >= 0.6) {
      candidates.push({
        id: "ACTION_ENABLE_BATTERY_SAVER",
        title: "Enable Battery Saver mode",
        description: "Optimizes background syncing and brightness to preserve power.",
        approvalMode: "ASK_FIRST",
        reasons: battery.causes || [],
        sideEffects: ["Reduces background activity", "May delay some notifications"],
        category: "Focus",
        impact: "Ensures device remains active until destination",
        templateId: "BATTERY_LOW",
        channel: "SMS",
        suggestedRecipient
      });
    }

    // Overload / notifications
    if (overload && overload.score >= 0.6) {
      candidates.push({
        id: "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
        title: "Suppress noisy senders for 60 min",
        description: "Temporarily filters low-priority notifications to reduce overload.",
        approvalMode: "ASK_FIRST",
        reasons: overload.causes || [],
        sideEffects: ["Temporarily mutes selected apps"],
        category: "Focus",
        impact: "Reduces cognitive load during peak stress"
      });
    }

    // Response debt
    if (response && response.score >= 0.6) {
      candidates.push({
        id: "ACTION_PREPARE_DELAY_MESSAGE",
        title: "Send 'Running 10 minutes late'",
        description: "Pulse has drafted a polite update for your next appointment.",
        approvalMode: "ASK_FIRST",
        reasons: response.causes || [],
        sideEffects: ["Creates a draft, you tap to send"],
        category: "Communication",
        impact: "Proactively manages attendee expectations",
        templateId: "RUNNING_LATE",
        channel: "SMS",
        suggestedRecipient
      });
    }

    // Charging stop (from Futures)
    const alt = futures.futures.find(f => f.id === "ALTERNATE");
    if (alt && alt.metrics.batteryPercent !== undefined && alt.metrics.batteryPercent > 20) {
      candidates.push({
        id: "ACTION_RECOMMEND_CHARGING_STOP",
        title: "Plan a charging stop",
        description: "A brief 15-min charge at a nearby station is recommended.",
        approvalMode: "ASK_FIRST",
        reasons: [`Alternate future keeps battery at ~${Math.round(alt.metrics.batteryPercent)}%`],
        sideEffects: ["Slightly changes route or departure time"],
        category: "Commute",
        impact: "Prevents total battery depletion before arrival"
      });
    }

    return candidates;
  }

  private pickBest(candidates: PlannerAction[], memory: MemoryState, personality?: PersonalityAnalysis): PlannerAction | null {
    if (candidates.length === 0) return null;

    // Default priority order: lateness > battery > overload/response
    let priorities: ActionId[] = [
      "ACTION_LEAVE_NOW",
      "ACTION_ENABLE_BATTERY_SAVER",
      "ACTION_RECOMMEND_CHARGING_STOP",
      "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
      "ACTION_PREPARE_DELAY_MESSAGE"
    ];

    // Adjust priorities based on personality traits
    if (personality?.traits.includes("Goal-oriented")) {
      priorities = ["ACTION_LEAVE_NOW", ...priorities.filter(p => p !== "ACTION_LEAVE_NOW")];
    } else if (personality?.traits.includes("Highly responsive")) {
      priorities = ["ACTION_PREPARE_DELAY_MESSAGE", ...priorities.filter(p => p !== "ACTION_PREPARE_DELAY_MESSAGE")];
    } else if (personality?.sentiment === "Stressed" || personality?.sentiment === "Overwhelmed") {
      priorities = ["ACTION_SUPPRESS_NOISY_NOTIFICATIONS", ...priorities.filter(p => p !== "ACTION_SUPPRESS_NOISY_NOTIFICATIONS")];
    }

    const preferred = [...candidates].sort((a, b) =>
      priorities.indexOf(a.id) - priorities.indexOf(b.id)
    );

    return preferred[0];
  }
}

export const plannerEngine = new PlannerEngine();
