import { RiskScore } from "./risk";

export type FutureId = "DO_NOTHING" | "RECOMMENDED" | "ALTERNATE";

export interface FutureMetrics {
  endTime: string;
  etaMinutes?: number;
  batteryPercent?: number;
  expectedLatenessMinutes?: number;
  missedCommitments: number;
  notificationCount?: number;
  overlapCount?: number;
  stressScore: number; // 0–1
}

export interface FutureCard {
  id: FutureId;
  title: string;
  description: string;
  metrics: FutureMetrics;
  risks: RiskScore[];
}

export interface FuturesResult {
  userId: string;
  baseTime: string;
  horizonMinutes: number;
  futures: FutureCard[];
}
