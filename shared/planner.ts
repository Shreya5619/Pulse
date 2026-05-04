export type ActionId =
  | "ACTION_LEAVE_NOW"
  | "ACTION_LEAVE_EARLIER_NEXT_TIME"
  | "ACTION_ENABLE_BATTERY_SAVER"
  | "ACTION_FIND_CHARGER"
  | "ACTION_SUPPRESS_NOISY_NOTIFICATIONS"
  | "ACTION_PREPARE_DELAY_MESSAGE"
  | "ACTION_RECOMMEND_CHARGING_STOP"
  | "ACTION_MULTI_MODE_TRANSIT";

export type ApprovalMode = "AUTO_SAFE" | "ASK_FIRST" | "NEVER_AUTO";

export interface PlannerAction {
  id: string; // Changed from ActionId to string to support unique suffixes
  title: string;
  description: string;
  approvalMode: ApprovalMode;
  reasons: string[];       // why we picked this
  sideEffects: string[];   // what else happens
  appliesToEventId?: string;
  category?: "Commute" | "Focus" | "Communication" | "General";
  impact?: string;         // what happens if accepted
  channel?: 'SMS' | 'TELEGRAM' | 'NONE';
  templateId?: 'RUNNING_LATE' | 'BATTERY_LOW' | 'ON_THE_WAY' | 'CHARGING_NEEDED';
  suggestedRecipient?: string; // phone / Telegram handle
  metadata?: any;             // for extra context (e.g. noisy apps)
  transportModeInfo?: {
    bestMode: string;
    bestEta: string;
    altMode: string;
    altEta: string;
  };
}

export interface PlannerDecision {
  userId: string;
  timestamp: string;
  chosen: PlannerAction | null;
  alternatives: PlannerAction[];
}
