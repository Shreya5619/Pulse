// shared/contracts.ts

/**
 * Pulse API Contracts (Standardized)
 * This file is the single source of truth for REST and WebSocket payloads.
 */

export type IsoTimestamp = string;
export type UUID = string;

export * from "./context_snapshot";


// --- Domain Entities ---

export type TrafficStatus = "JAMMED" | "SLOW" | "CLEAR";

export interface ContextSignal {
    readonly userId: UUID;
    readonly timestamp: IsoTimestamp;
    readonly locationLabel: string;      // e.g. "Home"
    readonly batteryPercent: number;     // 0-100
    readonly minutesToEvent: number;     // e.g. 25
    readonly eventName: string;          // e.g. "Physics Lab"
    readonly trafficStatus: TrafficStatus;
}

export type RiskLabel = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";

export interface RiskAssessment {
    readonly userId: UUID;
    readonly timestamp: IsoTimestamp;
    readonly scenario: string;           // e.g. "COMMUTE_LATE"
    readonly score: number;              // 0-1
    readonly label: RiskLabel;
    readonly reasons: readonly string[];
}

export interface PlannerSuggestion {
    readonly userId: UUID;
    readonly timestamp: IsoTimestamp;
    readonly actionId: UUID;
    readonly title: string;
    readonly description: string;
    readonly recommendedAtMinutesToEvent: number;
    readonly sideEffects: readonly string[];
}

export type GuardianMode = "AUTO_ACT" | "ASK_FIRST" | "BLOCK";

export interface GuardianDecision {
    readonly userId: UUID;
    readonly actionId: UUID;
    readonly timestamp: IsoTimestamp;
    readonly mode: GuardianMode;
    readonly rationale: string;
}

export interface InterventionCard {
    readonly userId: UUID;
    readonly actionId: UUID;
    readonly timestamp: IsoTimestamp;
    readonly headline: string;
    readonly body: string;
    readonly ctaLabel: string;
    readonly secondaryCtaLabel?: string;
}

// --- WebSocket Envelope ---

export type WsEventType =
    | "connection.ready"
    | "heartbeat.tick"
    | "context.updated"
    | "risk.updated"
    | "planner.suggested"
    | "guardian.decided"
    | "intervention.created";

export interface WsEnvelope<T = any> {
    readonly type: WsEventType;
    readonly eventId: UUID;
    readonly timestamp: IsoTimestamp;
    readonly data: T;
}

// --- REST API Wrappers ---

export interface ApiSuccess<T> {
    readonly ok: true;
    readonly data: T;
}

export interface ApiError {
    readonly ok: false;
    readonly error: {
        readonly code: string;
        readonly message: string;
    };
}

export type ApiResponse<T> = ApiSuccess<T> | ApiError;

// --- Helper Constructors ---

export function makeWsEnvelope<T>(
    type: WsEventType,
    eventId: UUID,
    data: T
): WsEnvelope<T> {
    return {
        type,
        eventId,
        timestamp: new Date().toISOString(),
        data,
    };
}