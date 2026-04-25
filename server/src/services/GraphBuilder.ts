import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { memoryStore } from "./MemoryStore";
import { eventsRepo } from "../db/EventsRepository";
import { GraphNode, GraphEdge, GraphSummary, RiskSummaryItem } from "../types/graph";
import { ContextSnapshot, CalendarEvent } from "../../../shared/context_snapshot";
import { MemoryState } from "../../../shared/memory";

export class GraphBuilder {
  async buildForUser(userId: string): Promise<{ nodes: GraphNode[]; edges: GraphEdge[]; summary: GraphSummary }> {
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const memory = await memoryStore.loadAll(userId);
    const upcomingEvents = await eventsRepo.getUpcoming(userId, { withinMinutes: 240 });

    if (!context) {
      return { nodes: [], edges: [], summary: { totalRisksNext90Min: 0, risks: [] } };
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
    upcomingEvents.forEach((event, index) => {
      const eventNodeId = `APP_${event.id}`;
      nodes.push({
        id: eventNodeId,
        type: "APPOINTMENT",
        label: event.title,
        timeWindow: { start: event.start_time, end: event.end_time },
        scores: { lateness: 0 } // Will calculate below
      });

      // TRAVEL Edge from current location (stub ETA for now)
      // In a real app, we'd use a routing engine
      const travelWeight = 15; // default 15 mins
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
    });

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
    const summary = this.generateSummary(nodes, context);

    return { nodes, edges, summary };
  }

  private calculateScores(nodes: GraphNode[], edges: GraphEdge[], context: ContextSnapshot, memory: MemoryState) {
    const nowTime = new Date(context.timestamp).getTime();

    nodes.forEach(node => {
      if (!node.scores) return;

      // Lateness Heuristic
      if (node.type === "APPOINTMENT" && node.timeWindow) {
        const edge = edges.find(e => e.to === node.id && e.type === "TRAVEL");
        const travelTime = edge ? edge.weight : 20;
        const startTime = new Date(node.timeWindow.start).getTime();
        const minsRemaining = (startTime - nowTime) / 60000;
        
        const habitLateMargin = memory.habits?.commute?.buffer_minutes || 5;
        
        // Score is high if minsRemaining < travelTime + margin
        if (minsRemaining < (travelTime + habitLateMargin)) {
          node.scores.lateness = Math.min(1, (travelTime + habitLateMargin - minsRemaining) / 20);
        } else {
          node.scores.lateness = 0;
        }
      }

      // Battery Heuristic
      if (node.type === "BATTERY_STATE") {
        const band = context.derived?.battery_band || "ok";
        let score = 0;
        if (band === "critical") score = 0.9;
        else if (band === "low") score = 0.6;
        else if (band === "ok") score = 0.2;

        // Boost score if memory says fast drain is expected
        if (memory.battery?.drain_patterns?.some(p => p.drain_rate > 0.1)) {
           score = Math.min(1, score + 0.2);
        }
        node.scores.battery = score;
      }

      // Response Debt Heuristic
      if (node.type === "MESSAGE_OBLIGATION") {
        // High if many messages or if from important sender
        node.scores.responseDebt = 0.5; // Simple stub
      }

      // Overload Heuristic
      if (node.type === "APPOINTMENT") {
         // High if overlapping or heavy notifications
         const overlapping = nodes.filter(n => 
           n.type === "APPOINTMENT" && 
           n.id !== node.id && 
           this.isOverlapping(node, n)
         ).length;
         
         const notificationLoad = context.notifications.length > 10 ? 0.4 : 0.1;
         node.scores.overload = Math.min(1, (overlapping * 0.4) + notificationLoad);
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

  private generateSummary(nodes: GraphNode[], context: ContextSnapshot): GraphSummary {
    const risks: RiskSummaryItem[] = [];

    nodes.forEach(node => {
      if (!node.scores) return;

      if (node.scores.lateness && node.scores.lateness > 0.4) {
        risks.push({
          type: "lateness",
          score: node.scores.lateness,
          nodeId: node.id,
          label: `Likely late for ${node.label}`,
          occursAt: node.timeWindow?.start || context.timestamp
        });
      }

      if (node.scores.battery && node.scores.battery > 0.5) {
        risks.push({
          type: "battery",
          score: node.scores.battery,
          nodeId: node.id,
          label: "Battery might not last this window",
          occursAt: context.timestamp
        });
      }

      if (node.scores.overload && node.scores.overload > 0.6) {
        risks.push({
          type: "overload",
          score: node.scores.overload,
          nodeId: node.id,
          label: `Schedule overload around ${node.label}`,
          occursAt: node.timeWindow?.start || context.timestamp
        });
      }

      if (node.scores.responseDebt && node.scores.responseDebt > 0.7) {
        risks.push({
          type: "response_debt",
          score: node.scores.responseDebt,
          nodeId: node.id,
          label: "Accumulating response debt",
          occursAt: context.timestamp
        });
      }
    });

    return {
      totalRisksNext90Min: risks.length,
      risks: risks.sort((a, b) => b.score - a.score)
    };
  }
}

export const graphBuilder = new GraphBuilder();
