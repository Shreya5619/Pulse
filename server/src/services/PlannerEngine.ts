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
import { routingService } from "./RoutingService";
import { graphBuilder } from "./GraphBuilder";
class PlannerEngine {
  async decideForUser(userId: string, selectedScenarioId: string = "RECOMMENDED"): Promise<PlannerDecision> {
    const now = new Date().toISOString();
    const riskSnapshot = await riskEngine.computeForUser(userId);
    const futures = await futuresEngine.computeForUser(userId);
    const memory = await memoryStore.loadAll(userId);
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const personality = await GraphAdapter.getUserPersonality(userId);

    const candidates = (await this.buildCandidates(riskSnapshot, futures, memory, context, personality, selectedScenarioId))
      .map(c => ({
        ...c,
        id: `${c.id}:${Buffer.from(c.title).toString('hex').slice(0, 4)}` // Ensure UI uniqueness per variation
      }));
    const chosen = this.pickBest(candidates, memory, personality, selectedScenarioId);

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

    const allCandidates = await this.buildCandidates(riskSnapshot, futures, memory, context, personality);

    // Filter candidates relevant to this risk type/node
    let relevant = allCandidates.filter(c => {
      if (riskType === 'lateness') return c.id === 'ACTION_LEAVE_NOW' || c.id === 'ACTION_MULTI_MODE_TRANSIT' || c.id === 'ACTION_RECOMMEND_CHARGING_STOP';
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

  private async buildCandidates(
    risk: RiskSnapshot,
    futures: FuturesResult,
    memory: MemoryState,
    context: any,
    personality?: PersonalityAnalysis,
    selectedScenarioId?: string
  ): Promise<PlannerAction[]> {
    const candidates: PlannerAction[] = [];
    const suggestedRecipient = context?.calendar?.next_event?.organizer_contact || "123-456-7890"; // Hardcoded fallback as requested


    const lateness = risk.risks.find(r => r.type === "lateness");
    const battery = risk.risks.find(r => r.type === "battery");
    const overload = risk.risks.find(r => r.type === "overload");
    const response = risk.risks.find(r => r.type === "response_debt");

    // Lateness intervention
    if (lateness && lateness.score >= 0.6) {
      // 1. Fetch multi-mode routes if we have a target node
      let transportInfo: PlannerAction["transportModeInfo"] | undefined;
      let destinationName = "Destination";

      if (lateness.nodeId) {
        const cached = graphBuilder.getCachedGraph(risk.userId);
        const node = cached?.nodes.find(n => n.id === lateness.nodeId);
        destinationName = node?.label || destinationName;

        if (node?.location && context?.location?.lat) {
          try {
            const routes = await routingService.getMultiModeRoutes(
              { lat: context.location.lat, lon: context.location.lon },
              { lat: node.location.lat, lon: node.location.lon }
            );

            const modes = [
              { name: "Car/Taxi", data: routes.car },
              { name: "Auto Rickshaw", data: routes.auto },
              { name: "Two-Wheeler", data: routes.twoWheeler },
              { name: "Public Transit", data: routes.transit },
              { name: "Walking", data: routes.walk }
            ];

            const sorted = modes
              .filter(m => m.data.durationSeconds > 0)
              .sort((a, b) => a.data.durationSeconds - b.data.durationSeconds);

            if (sorted.length >= 2) {
              const best = sorted[0];
              const alt = sorted[1];
              transportInfo = {
                bestMode: best.name,
                bestEta: `${Math.round(best.data.durationSeconds / 60)} min`,
                altMode: alt.name,
                altEta: `${Math.round(alt.data.durationSeconds / 60)} min`
              };
            }
          } catch (e) {
            console.error("[Planner] Failed to fetch multi-mode routes:", e);
          }
        }
      }

      const isRecommended = selectedScenarioId === "RECOMMENDED";
      const isDoNothing = selectedScenarioId === "DO_NOTHING";

      if (transportInfo && isRecommended) {
        candidates.push({
          id: "ACTION_MULTI_MODE_TRANSIT",
          title: `Optimization: Use ${transportInfo.bestMode}`,
          description: `Pulse identifies ${transportInfo.bestMode} as the fastest way to ${destinationName} (${transportInfo.bestEta}). Using this mode secures your schedule.`,
          approvalMode: "ASK_FIRST",
          reasons: [...(lateness.causes || []), `Simulations confirm ${transportInfo.bestMode} is optimal for this traffic`],
          sideEffects: ["Opens navigation for selected mode"],
          appliesToEventId: lateness.nodeId,
          category: "Commute",
          impact: `Saves time vs default mode; reduces lateness risk to Low`,
          transportModeInfo: transportInfo
        });
      } else if (isDoNothing) {
        candidates.push({
          id: "ACTION_LEAVE_NOW",
          title: `CRITICAL: Leave now for ${destinationName}`,
          description: `You are currently trending toward a 15+ minute delay. Immediate departure is required to minimize impact.`,
          approvalMode: "ASK_FIRST",
          reasons: lateness.causes || [],
          sideEffects: ["May trigger navigation"],
          appliesToEventId: lateness.nodeId,
          category: "Commute",
          impact: "Prevents escalating lateness risk"
        });
      } else {
        candidates.push({
          id: "ACTION_LEAVE_NOW",
          title: `Leave now for ${destinationName}`,
          description: `You are at risk of being late. Start moving now to reach your destination.`,
          approvalMode: "ASK_FIRST",
          reasons: lateness.causes || [],
          sideEffects: ["May trigger navigation"],
          appliesToEventId: lateness.nodeId,
          category: "Commute",
          impact: "Cuts lateness risk from High to Low"
        });
      }
    }

    // Battery intervention
    if (battery && battery.score >= 0.6) {
      if (!context.battery.power_saver_on) {
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
      } else {

      }
    }

    // Overload / notifications - More aggressive in Focus Path (Scenario C)
    const isFocusPath = selectedScenarioId === "ALTERNATE";
    if ((overload && overload.score >= 0.6) || (isFocusPath && context.notification_digest && context.notification_digest.total_count > 0)) {
      const noisyThreads = (context.notification_digest?.top_threads || [])
        .filter((t: any) => t.count >= (isFocusPath ? 1 : 3));

      candidates.push({
        id: "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
        title: isFocusPath ? "Enable Focus Filtering" : "Suppress noisy senders for 60 min",
        description: isFocusPath
          ? "Minimize cognitive load by filtering all non-essential notifications."
          : "Temporarily filters low-priority notifications to reduce overload.",
        approvalMode: "ASK_FIRST",
        reasons: overload?.causes || ["Focus mode requested for this block"],
        sideEffects: ["Temporarily mutes selected apps"],
        category: "Focus",
        impact: "Reduces cognitive load during peak stress",
        metadata: {
          noisyApps: noisyThreads.map((t: any) => ({
            name: t.sender,
            count: t.count,
            packageName: t.app_package
          }))
        }
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
    const isChargePath = selectedScenarioId === "ALTERNATE";
    const threshold = memory.battery?.profile?.thresholds?.low ?? 20;
    const baseline = futures.futures.find(f => f.id === "DO_NOTHING");

    if (isChargePath || (baseline && baseline.metrics.batteryPercent !== undefined && baseline.metrics.batteryPercent < (threshold * 100))) {
      candidates.push({
        id: "ACTION_RECOMMEND_CHARGING_STOP",
        title: isChargePath ? "Plan a brief charging stop" : "Emergency charging stop",
        description: isChargePath 
          ? "Charge for 15 minutes before leaving. This strategy prioritizes device safety over a minor delay."
          : "Battery is critical. A brief 15-min charge at a nearby station is required to ensure arrival.",
        approvalMode: "ASK_FIRST",
        reasons: isChargePath ? ["Prioritize battery buffer"] : [`Battery predicted to drop to ${Math.round(baseline?.metrics.batteryPercent || 0)}%`],
        sideEffects: ["Slightly changes route or departure time"],
        category: "Commute",
        impact: "Prevents total battery depletion before arrival"
      });
    }

    return candidates;
  }

  private pickBest(candidates: PlannerAction[], memory: MemoryState, personality?: PersonalityAnalysis, selectedScenarioId: string = "RECOMMENDED"): PlannerAction | null {
    if (selectedScenarioId === "DO_NOTHING") {
      console.log("[Planner] User selected DO_NOTHING path, suppressing interventions.");
      return null;
    }

    if (candidates.length === 0) return null;

    // Default priority order: lateness > battery > overload/response
    let priorities: ActionId[] = [
      "ACTION_MULTI_MODE_TRANSIT",
      "ACTION_LEAVE_NOW",
      "ACTION_ENABLE_BATTERY_SAVER",
      "ACTION_RECOMMEND_CHARGING_STOP",
      "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
      "ACTION_PREPARE_DELAY_MESSAGE"
    ];

    // If user chose ALTERNATE (Focus Path), prioritize focus/battery actions over travel
    if (selectedScenarioId === "ALTERNATE") {
      priorities = [
        "ACTION_SUPPRESS_NOISY_NOTIFICATIONS",
        "ACTION_ENABLE_BATTERY_SAVER",
        "ACTION_PREPARE_DELAY_MESSAGE",
        ...priorities.filter(p => !["ACTION_SUPPRESS_NOISY_NOTIFICATIONS", "ACTION_ENABLE_BATTERY_SAVER", "ACTION_PREPARE_DELAY_MESSAGE"].includes(p))
      ];
    }

    // Adjust priorities based on personality traits
    if (personality?.traits.includes("Goal-oriented")) {
      priorities = ["ACTION_LEAVE_NOW", ...priorities.filter(p => p !== "ACTION_LEAVE_NOW")];
    } else if (personality?.traits.includes("Highly responsive")) {
      priorities = ["ACTION_PREPARE_DELAY_MESSAGE", ...priorities.filter(p => p !== "ACTION_PREPARE_DELAY_MESSAGE")];
    } else if (personality?.sentiment === "Stressed" || personality?.sentiment === "Overwhelmed") {
      priorities = ["ACTION_SUPPRESS_NOISY_NOTIFICATIONS", ...priorities.filter(p => p !== "ACTION_SUPPRESS_NOISY_NOTIFICATIONS")];
    }

    const preferred = [...candidates].sort((a, b) => {
      const baseA = a.id.split(':')[0] as ActionId;
      const baseB = b.id.split(':')[0] as ActionId;
      return priorities.indexOf(baseA) - priorities.indexOf(baseB);
    });

    return preferred[0];
  }
}

export const plannerEngine = new PlannerEngine();
