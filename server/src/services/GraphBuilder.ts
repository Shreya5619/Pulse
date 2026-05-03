import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { memoryStore } from "./MemoryStore";
import { eventsRepo } from "../db/EventsRepository";
import { GraphNode, GraphEdge, GraphSummary, RiskSummaryItem } from "../types/graph";
import { ContextSnapshot, CalendarEvent } from "../../../shared/context_snapshot";
import { MemoryState } from "../../../shared/memory";
import { routingService } from "./RoutingService";
import { geocodingService } from "./GeocodingService";
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

      // TRAVEL Edge
      let travelWeight = 20; // Default fallback
      if (context.location.lat && context.location.lon) {
        // Determine Start Coordinates
        let startLat = event.start_location?.lat;
        let startLon = event.start_location?.lon;

        if ((!startLat || !startLon) && event.start_location?.name) {
          const geoStart = await geocodingService.geocode(event.start_location.name);
          if (geoStart) {
            startLat = geoStart.lat;
            startLon = geoStart.lon;
          }
        }

        // Fallback to current GPS
        startLat = startLat ?? context.location.lat;
        startLon = startLon ?? context.location.lon;

        // Determine Destination Coordinates
        let eventLat = event.location?.lat;
        let eventLon = event.location?.lon;

        if ((!eventLat || !eventLon) && event.location_text) {
          console.log(`[Graph] Geocoding for ${event.title}: ${event.location_text}`);
          const geo = await geocodingService.geocode(event.location_text);
          if (geo) {
            eventLat = geo.lat;
            eventLon = geo.lon;
          }
        }

        if (startLat && startLon && eventLat && eventLon) {
          try {
            const route = await routingService.getRoute(
              { lat: startLat, lon: startLon },
              { lat: eventLat, lon: eventLon }
            );
            travelWeight = Math.ceil(route.durationSeconds / 60);
            console.log(`[Graph] TRAVEL edge ${currentPlaceId} → ${event.title}, etaMinutes=${travelWeight}`);
          } catch (err) {
            console.warn(`[Graph] Routing failed for ${event.title}, using fallback.`);
          }
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

    // 5. MESSAGE_OBLIGATION Nodes derived from digest
    if (context.notification_digest) {
      const topThreads = context.notification_digest.top_threads || [];
      topThreads.forEach((thread, idx) => {
        const msgNodeId = `THREAD_${idx}`;
        nodes.push({
          id: msgNodeId,
          type: "MESSAGE_OBLIGATION",
          label: `Messages from ${thread.sender}`,
          scores: { responseDebt: 0 }
        });

        edges.push({
          id: `INTERRUPTION_THREAD_${idx}`,
          from: "NOW",
          to: msgNodeId,
          type: "INTERRUPTION",
          weight: thread.count * 2 // Weight based on volume
        });
      });
    }

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

  getExplanation(userId: string, nodeId: string) {
    const cached = this.graphCache.get(userId);
    if (!cached) return null;

    // Find the target node
    const target = cached.nodes.find(n => n.id === nodeId);
    if (!target) return null;

    // Find direct neighbors (1-hop)
    const relatedEdges = cached.edges.filter(e => e.from === nodeId || e.to === nodeId);
    const neighborIds = new Set(relatedEdges.map(e => e.from === nodeId ? e.to : e.from));
    neighborIds.add(nodeId);

    const relatedNodes = cached.nodes.filter(n => neighborIds.has(n.id));

    return {
      target,
      nodes: relatedNodes,
      edges: relatedEdges
    };
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
        const digest = context.notification_digest;
        const importantPending = digest?.by_category["IMPORTANT_SENDER"] || 0;
        const urgentOtp = digest?.by_category["URGENT_OTP"] || 0;
        // Estimate oldest message age from notification timestamps (fallback 30min)
        const oldestMinutes = 30; 
        node.scores.responseDebt = responseDebtRisk(importantPending + urgentOtp, oldestMinutes);
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

        // Notifications per hour (approximate from digest)
        const notifRate = context.notification_digest?.total_count ?? 0;

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
