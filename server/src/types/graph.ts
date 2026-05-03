/**
 * Graph Node Types for the Pulse Assistant
 */
export type NodeType = "NOW" | "APPOINTMENT" | "ACT" | "PLACE" | "BATTERY_STATE" | "MESSAGE_OBLIGATION" | "TASK";

export interface GraphNode {
  id: string;
  type: NodeType;
  timeWindow?: { start: string; end?: string };
  label: string;
  scores?: {
    lateness?: number;
    battery?: number;
    overload?: number;
    responseDebt?: number;
  };
}

/**
 * Graph Edge Types
 */
export type EdgeType = "TRAVEL" | "DEPENDENCY" | "URGENCY" | "INTERRUPTION" | "ENERGY_COST";

export interface GraphEdge {
  id: string;
  from: string;
  to: string;
  type: EdgeType;
  weight: number;
}

/**
 * Summary of risks derived from the graph
 */
export interface RiskSummaryItem {
  type: "lateness" | "battery" | "overload" | "response_debt";
  score: number;
  nodeId: string;
  label: string;
  occursAt: string;
}

export interface GraphSummary {
  totalRisksNext90Min: number;
  risks: RiskSummaryItem[];
}
