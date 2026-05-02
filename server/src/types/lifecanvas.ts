export interface LifeCanvasEvent {
    id?: string;
    userId: string;
    type: "EVENT" | "EMOTION" | "MILESTONE" | "HABIT";
    timestamp: string;
    tags: string[];
    entities: Record<string, string[]>;
    importance: number;
    textContent: string;
    createdAt?: string;
}

export interface LifeCanvasSummary {
    id?: string;
    userId: string;
    layer: "DAILY" | "WEEKLY" | "MONTHLY" | "YEARLY";
    periodStart: string;
    periodEnd: string;
    summary: string;
    keyEvents: any[];
    patterns: any[];
    emotionalTrend: string;
    createdAt?: string;
}
