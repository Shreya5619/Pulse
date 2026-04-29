import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { memoryStore } from "./MemoryStore";
import { eventsRepo } from "../db/EventsRepository";
import { GraphNode, GraphEdge, GraphSummary, RiskSummaryItem } from "../types/graph";
import { ContextSnapshot, CalendarEvent } from "../../../shared/context_snapshot";
import { MemoryState } from "../../../shared/memory";
import { routingService } from "./RoutingService";
import {
  latenessRisk,
  batteryRisk,
  responseDebtRisk,
  overloadRisk
} from "./RiskEngine";

export class GraphBuilder {
  private graphCache = new Map<string, { nodes: GraphNode[]; edges: GraphEdge[]; summary: GraphSummary; context: ContextSnapshot }>();

  async buildForUser(userId: string): Promise<{ nodes: GraphNode[]; edges: GraphEdge[]; summary: GraphSummary; context: ContextSnapshot }> {
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const memory = await memoryStore.loadAll(userId);
    const upcomingEvents = await eventsRepo.getUpcoming(userId, { withinMinutes: 240 });

    if (!context) {
      // Return a minimal stub context so callers don't need null-checks
      const stub = { timestamp: new Date().toISOString() } as ContextSnapshot;
      return { nodes: [], edges: [], summary: { totalRisksNext90Min: 0, risks: [] }, context: stub };
    }

    const nodes: GraphNode[] = [];
    const edges: GraphEdge[] = [];

    // 1. NOW Node
    const nowNode: GraphNode = {
      id: "NOW",
      type: "NOW",
      label: "Current Moment",
      timeWindow: { start: context.timestamp }
    };
    nodes.push(nowNode);

    // 2. PLACE Nodes
    const currentPlaceId = context.location.place_id || "current_loc";
    nodes.push({
      id: `PLACE_${currentPlaceId}`,
      type: "PLACE",
      label: currentPlaceId === "current_loc" ? "Unknown Location" : `Location: ${currentPlaceId}`
    });

    // 3. APPOINTMENT Nodes & TRAVEL Edges
    for (const event of upcomingEvents) {
      const eventNodeId = `APP_${event.id}`;
      nodes.push({
        id: eventNodeId,
        type: "APPOINTMENT",
        label: event.title,
        timeWindow: { start: event.start_time, end: event.end_time },
        scores: { lateness: 0 } // Will calculate below
      });

      // TRAVEL Edge from current location
      let travelWeight = 15; // default 15 mins
      if (context.location.lat && context.location.lon && event.location?.lat && event.location?.lon) {
        try {
          const route = await routingService.getRoute(
            { lat: context.location.lat, lon: context.location.lon },
            { lat: event.location.lat, lon: event.location.lon }
          );
          travelWeight = Math.ceil(route.durationSeconds / 60);
          console.log(`[Graph] TRAVEL edge ${currentPlaceId} → ${event.title}, etaMinutes=${travelWeight}`);
        } catch (err) {
          console.warn(`[Graph] OSRM routing failed for ${event.title}, using fallback.`);
        }
      }

      edges.push({
        id: `TRAVEL_NOW_${event.id}`,
        from: `PLACE_${currentPlaceId}`,
        to: eventNodeId,
        type: "TRAVEL",
        weight: travelWeight
      });

      // URGENCY Edge
      const startTime = new Date(event.start_time).getTime();
      const nowTime = new Date(context.timestamp).getTime();
      const diffMins = Math.max(0, (startTime - nowTime) / 60000);

      edges.push({
        id: `URGENCY_NOW_${event.id}`,
        from: "NOW",
        to: eventNodeId,
        type: "URGENCY",
        weight: diffMins
      });
    }

    // 4. BATTERY_STATE Node & ENERGY_COST Edge
    const batteryNodeId = "BATTERY";
    const batteryBand = context.derived?.battery_band || "ok";
    nodes.push({
      id: batteryNodeId,
      type: "BATTERY_STATE",
      label: `Battery: ${Math.round(context.battery.level * 100)}% (${batteryBand})`,
      scores: { battery: 0 }
    });

    edges.push({
      id: "ENERGY_COST_NOW",
      from: "NOW",
      to: batteryNodeId,
      type: "ENERGY_COST",
      weight: context.battery.is_charging ? 0 : 5 // Stub weight: higher if discharging
    });

    // 5. MESSAGE_OBLIGATION Nodes
    const importantNotifications = context.notifications.filter(n =>
      n.category === "message" || n.category === "call"
    );

    importantNotifications.forEach(n => {
      const msgNodeId = `MSG_${n.id}`;
      nodes.push({
        id: msgNodeId,
        type: "MESSAGE_OBLIGATION",
        label: `Message from ${n.sender || "Unknown"}`,
        scores: { responseDebt: 0 }
      });

      edges.push({
        id: `INTERRUPTION_${n.id}`,
        from: "NOW",
        to: msgNodeId,
        type: "INTERRUPTION",
        weight: 10 // Fixed weight for now
      });
    });

    // --- HEURISTIC SCORE CALCULATION ---
    this.calculateScores(nodes, edges, context, memory);

    // --- SUMMARY GENERATION ---
    const summary = this.computeTopRisks(nodes, context);

    const result = { nodes, edges, summary, context };
    this.graphCache.set(userId, result);
    return result;
  }

  getCachedGraph(userId: string) {
    return this.graphCache.get(userId);
  }

  getCacheEntries() {
    return this.graphCache.entries();
  }

  private calculateScores(nodes: GraphNode[], edges: GraphEdge[], context: ContextSnapshot, memory: MemoryState) {
    const nowTime = new Date(context.timestamp).getTime();

    // Pre-compute aggregate inputs for response-debt and overload
    const importantMessages = nodes.filter(n => n.type === "MESSAGE_OBLIGATION");
    const appointmentNodes = nodes.filter(n => n.type === "APPOINTMENT");

    nodes.forEach(node => {
      if (!node.scores) return;

      // Lateness — delegate to RiskEngine.latenessRisk
      if (node.type === "APPOINTMENT" && node.timeWindow) {
        const edge = edges.find(e => e.to === node.id && e.type === "TRAVEL");
        const etaMinutes = edge ? edge.weight : 20;
        const startTime = new Date(node.timeWindow.start).getTime();
        const minutesToEvent = (startTime - nowTime) / 60000;
        // typical_lateness = avg minutes late; treat as the buffer the user "normally cuts it close" by
        const buffer = memory.habits?.patterns?.typical_lateness ?? 5;

        node.scores.lateness = latenessRisk(minutesToEvent, etaMinutes, buffer);
      }

      // Battery — delegate to RiskEngine.batteryRisk
      if (node.type === "BATTERY_STATE") {
        const currentPct = Math.round(context.battery.level * 100);
        // Use memory discharge rate if available, fall back to 8%/hr estimate
        const drainRate = memory.battery?.profile?.discharge_rates?.active ?? 8;
        // Horizon = minutes to next event or default 120
        const nextEventStart = appointmentNodes
          .map(n => n.timeWindow ? new Date(n.timeWindow.start).getTime() : Infinity)
          .sort((a, b) => a - b)[0];
        const horizonMinutes =
          nextEventStart && nextEventStart !== Infinity
            ? Math.max(0, (nextEventStart - nowTime) / 60000)
            : 120;

        node.scores.battery = batteryRisk(currentPct, horizonMinutes, drainRate);
      }

      // Response Debt — delegate to RiskEngine.responseDebtRisk
      if (node.type === "MESSAGE_OBLIGATION") {
        const importantPending = importantMessages.length;
        // Estimate oldest message age from notification timestamps (fallback 30min)
        const oldestMinutes = 30; // TODO: derive from notification timestamp once available
        node.scores.responseDebt = responseDebtRisk(importantPending, oldestMinutes);
      }

      // Overload — delegate to RiskEngine.overloadRisk
      if (node.type === "APPOINTMENT") {
        const eventsIn90 = appointmentNodes.filter(n => {
          if (!n.timeWindow) return false;
          const start = new Date(n.timeWindow.start).getTime();
          return start <= nowTime + 90 * 60 * 1000;
        }).length;

        const totalPairs = appointmentNodes.length * (appointmentNodes.length - 1) / 2 || 1;
        const overlappingPairs = appointmentNodes.filter(n =>
          n.id !== node.id && this.isOverlapping(node, n)
        ).length;
        const overlapScore = overlappingPairs / totalPairs;

        // Notifications per 15 min (approximate from snapshot count)
        const notifRate = context.notifications.length;

        node.scores.overload = overloadRisk(eventsIn90, overlapScore, notifRate);
      }
    });
  }

  private isOverlapping(n1: GraphNode, n2: GraphNode): boolean {
    if (!n1.timeWindow || !n2.timeWindow) return false;
    const s1 = new Date(n1.timeWindow.start).getTime();
    const e1 = n1.timeWindow.end ? new Date(n1.timeWindow.end).getTime() : s1 + 3600000;
    const s2 = new Date(n2.timeWindow.start).getTime();
    const e2 = n2.timeWindow.end ? new Date(n2.timeWindow.end).getTime() : s2 + 3600000;

    return s1 < e2 && s2 < e1;
  }

  private computeTopRisks(nodes: GraphNode[], context: ContextSnapshot): GraphSummary {
    const nowTime = new Date(context.timestamp).getTime();
    const limitTime = nowTime + 90 * 60 * 1000;

    // Filter nodes in next 90 mins
    const activeNodes = nodes.filter(node => {
      if (!node.timeWindow) return true; // Persistent states like battery/messages
      const start = new Date(node.timeWindow.start).getTime();
      return start <= limitTime; // Starts within 90 mins
    });

    const bestByRisk: Record<string, RiskSummaryItem> = {};

    activeNodes.forEach(node => {
      if (!node.scores) return;

      const checkRisk = (type: RiskSummaryItem["type"], score: number | undefined, template: string) => {
        if (score && score >= 0.4) { // Non-LOW risks only (MEDIUM + HIGH)
          if (!bestByRisk[type] || score > bestByRisk[type].score) {
            bestByRisk[type] = {
              type,
              score,
              nodeId: node.id,
              label: template.replace("${label}", node.label),
              occursAt: node.timeWindow?.start || context.timestamp
            };
          }
        }
      };

      checkRisk("lateness", node.scores.lateness, "Likely late for ${label}");
      checkRisk("battery", node.scores.battery, "Battery might fail before ${label}");
      checkRisk("overload", node.scores.overload, "Schedule overload at ${label}");
      checkRisk("response_debt", node.scores.responseDebt, "Pending response debt");
    });

    const risks = Object.values(bestByRisk)
      .sort((a, b) => b.score - a.score)
      .slice(0, 3);

    return {
      totalRisksNext90Min: risks.length,
      risks
    };
  }
}

export const graphBuilder = new GraphBuilder();
