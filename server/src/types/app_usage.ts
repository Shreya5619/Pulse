// Gantt Chart App Usage Models
// This schema mirrors the Flutter `timeline_screen.dart` data models.

export interface AppActivity {
    appName: string;
    startHours: number;
    endHours: number;
    color: string;
}

export interface ScreenSession {
    startHours: number;
    endHours: number;
    activities: AppActivity[];
}

export interface TelemetryPayload {
    userId: string;
    date: string; // ISO Date String
    sessions: ScreenSession[];
}
