export type RiskLevel = "low" | "medium" | "high" | "critical";

export type PlannerAction =
    | "leave_now"
    | "enable_battery_saver"
    | "draft_delay_message"
    | "reroute"
    | "monitor_only";

export type GuardianAction =
    | "none"
    | "notify"
    | "auto_message"
    | "escalate";

export type InterventionStatus =
    | "pending"
    | "triggered"
    | "completed"
    | "dismissed";

export interface ContextSignal {
    userId: string;
    timestamp: string;
    minutesToDestination: number;
    batteryPercent: number;
    trafficLevel: "light" | "moderate" | "heavy";
    trafficTrend: "improving" | "steady" | "worsening";
    destinationLabel: string;
    currentLocationLabel?: string;
    isCharging?: boolean;
    networkStrength?: "poor" | "ok" | "good";
}

export interface RiskAssessment {
    id: string;
    timestamp: string;
    level: RiskLevel;
    score: number;
    summary: string;
    reasons: string[];
    primaryRisk: "delay" | "battery" | "safety" | "connectivity";
    confidence?: number;
}

export interface PlannerSuggestion {
    id: string;
    timestamp: string;
    action: PlannerAction;
    title: string;
    description: string;
    expectedBenefit: string;
    etaDeltaMinutes?: number;
    batteryDeltaPercent?: number;
    priority: number;
}

export interface GuardianDecision {
    id: string;
    timestamp: string;
    action: GuardianAction;
    shouldNotify: boolean;
    channel?: "push" | "sms" | "in_app";
    recipientLabel?: string;
    messagePreview?: string;
    rationale: string;
}

export interface InterventionCard {
    id: string;
    timestamp: string;
    title: string;
    subtitle: string;
    status: InterventionStatus;
    riskLevel: RiskLevel;
    recommendedActions: string[];
    primaryCta: string;
    secondaryCta?: string;
    messageDraft?: string;
}

export interface WsEnvelope<T> {
    type: string;
    eventId: string;
    timestamp: string;
    data: T;
}

export interface ApiResponse<T> {
    ok: boolean;
    data?: T;
    error?: {
        code: string;
        message: string;
        details?: unknown;
    };
}