import { RiskSnapshot, RiskScore } from "../types/risk";
import { GraphNode, GraphEdge } from "../types/graph";
import { graphBuilder } from "./GraphBuilder";
import { memoryStore } from "./MemoryStore";
import { riskSnapshotRepo } from "../db/RiskSnapshotRepository";
import { 
  assessLateness, 
  assessBattery, 
  assessResponseDebt, 
  assessResponseDebt, 
  assessOverload 
} from "./RiskEngine";
import { GraphAdapter } from "./GraphAdapter";

// ──────────────────────────────────────────────────────────────────
// Graph Helpers
// ──────────────────────────────────────────────────────────────────

interface NextAppointment {
  node: GraphNode;
  minutesToEvent: number;
  etaMinutes: number;
}

/**
 * Walk the graph to find the next upcoming appointment node
 * and its associated TRAVEL edge weight.
 */
function findNextAppointmentNode(
  nodes: GraphNode[],
  edges: GraphEdge[],
  nowMs: number
): NextAppointment | null {
  const appts = nodes
    .filter((n) => n.type === "APPOINTMENT" && n.timeWindow?.start)
    .map((n) => {
      const startMs = new Date(n.timeWindow!.start).getTime();
      const minutesToEvent = (startMs - nowMs) / 60000;
      return { node: n, minutesToEvent };
    })
    .filter((a) => a.minutesToEvent > 0) // future only
    .sort((a, b) => a.minutesToEvent - b.minutesToEvent);

  if (appts.length === 0) return null;

  const closest = appts[0];
  const travelEdge = edges.find(
    (e) => e.to === closest.node.id && e.type === "TRAVEL"
  );
  const etaMinutes = travelEdge ? travelEdge.weight : 20; // fallback 20 min

  return { ...closest, etaMinutes };
}

/**
 * Check whether two time-windowed nodes overlap.
 */
function nodesOverlap(n1: GraphNode, n2: GraphNode): boolean {
  if (!n1.timeWindow || !n2.timeWindow) return false;
  const s1 = new Date(n1.timeWindow.start).getTime();
  const e1 = n1.timeWindow.end
    ? new Date(n1.timeWindow.end).getTime()
    : s1 + 3600000;
  const s2 = new Date(n2.timeWindow.start).getTime();
  const e2 = n2.timeWindow.end
    ? new Date(n2.timeWindow.end).getTime()
    : s2 + 3600000;
  return s1 < e2 && s2 < e1;
}

// ──────────────────────────────────────────────────────────────────
// RiskEngineService — graph + memory → RiskSnapshot
// ──────────────────────────────────────────────────────────────────

/**
 * High-level service that builds a graph, reads memory, and produces
 * a full RiskSnapshot with explanations. Persists every snapshot to Postgres.
 */
export class RiskEngineService {
  /**
   * Compute all risk dimensions for a user and persist the result.
   */
  async computeForUser(userId: string): Promise<RiskSnapshot> {
    const graph = await graphBuilder.buildForUser(userId);
    const memory = await memoryStore.loadAll(userId);
    const preferences = await GraphAdapter.getUserPreferences(userId);
    const now = new Date().toISOString();
    const nowMs = Date.now();

    const risks: RiskScore[] = [];

    // ── Lateness ────────────────────────────────────────────────
    const nextAppt = findNextAppointmentNode(graph.nodes, graph.edges, nowMs);
    if (nextAppt) {
      const { node, minutesToEvent, etaMinutes } = nextAppt;
      const buffer = memory.habits?.patterns?.typical_lateness ?? 5;
      risks.push(
        assessLateness(minutesToEvent, etaMinutes, buffer, node.label, node.id, preferences)
      );
    }

    // ── Battery ─────────────────────────────────────────────────
    const battNode = graph.nodes.find((n) => n.type === "BATTERY_STATE");
    if (battNode) {
      const currentPct = graph.context.battery
        ? Math.round(graph.context.battery.level * 100)
        : 50;
      const drainRate =
        memory.battery?.profile?.discharge_rates?.active ?? 8;

      // Horizon = minutes to next event or default 120
      const appointmentNodes = graph.nodes.filter(
        (n) => n.type === "APPOINTMENT"
      );
      const nextEventMs = appointmentNodes
        .map((n) =>
          n.timeWindow ? new Date(n.timeWindow.start).getTime() : Infinity
        )
        .sort((a, b) => a - b)[0];
      const horizonMinutes =
        nextEventMs && nextEventMs !== Infinity
          ? Math.max(0, (nextEventMs - nowMs) / 60000)
          : 120;

      risks.push(
        assessBattery(currentPct, horizonMinutes, drainRate, battNode.id, preferences)
      );
    }

    // ── Response Debt ───────────────────────────────────────────
    const msgNodes = graph.nodes.filter(
      (n) => n.type === "MESSAGE_OBLIGATION"
    );
    if (msgNodes.length > 0) {
      const oldestMinutes = 30;
      risks.push(
        assessResponseDebt(msgNodes.length, oldestMinutes, msgNodes[0].id)
      );
    }

    // ── Overload ────────────────────────────────────────────────
    const appointmentNodes = graph.nodes.filter(
      (n) => n.type === "APPOINTMENT"
    );
    const eventsIn90 = appointmentNodes.filter((n) => {
      if (!n.timeWindow) return false;
      const start = new Date(n.timeWindow.start).getTime();
      return start <= nowMs + 90 * 60 * 1000;
    }).length;

    if (eventsIn90 > 0) {
      const totalPairs =
        (appointmentNodes.length * (appointmentNodes.length - 1)) / 2 || 1;
      let overlappingCount = 0;
      for (let i = 0; i < appointmentNodes.length; i++) {
        for (let j = i + 1; j < appointmentNodes.length; j++) {
          if (nodesOverlap(appointmentNodes[i], appointmentNodes[j])) {
            overlappingCount++;
          }
        }
      }
      const overlapScore = overlappingCount / totalPairs;
      const notifRate = graph.context.notifications
        ? graph.context.notifications.length
        : 0;

      risks.push(assessOverload(eventsIn90, overlapScore, notifRate));
    }

    // ── Build & Persist ─────────────────────────────────────────
    const snapshot: RiskSnapshot = {
      userId,
      timestamp: now,
      risks: risks.filter((r) => r.score > 0),
    };

    // Fire-and-forget persist
    riskSnapshotRepo.save(snapshot).catch((err) => {
      console.warn("[RiskEngineService] Failed to persist snapshot:", err);
    });

    console.log(
      `[RiskEngineService] computeForUser(${userId}): ${snapshot.risks.length} risk(s), ` +
        `top=${snapshot.risks.length > 0 ? Math.max(...snapshot.risks.map((r) => r.score)).toFixed(2) : "0.00"}`
    );

    return snapshot;
  }
}

export const riskEngine = new RiskEngineService();
