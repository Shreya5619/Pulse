export type ActionId =
  | "ACTION_LEAVE_NOW"
  | "ACTION_LEAVE_EARLIER_NEXT_TIME"
  | "ACTION_ENABLE_BATTERY_SAVER"
  | "ACTION_SUPPRESS_NOISY_NOTIFICATIONS"
  | "ACTION_PREPARE_DELAY_MESSAGE"
  | "ACTION_RECOMMEND_CHARGING_STOP";

export type ApprovalMode = "AUTO_SAFE" | "ASK_FIRST" | "NEVER_AUTO";

export interface PlannerAction {
  id: ActionId;
  title: string;
  description: string;
  approvalMode: ApprovalMode;
  reasons: string[];       // why we picked this
  sideEffects: string[];   // what else happens
  appliesToEventId?: string;
}

export interface PlannerDecision {
  userId: string;
  timestamp: string;
  chosen: PlannerAction | null;
  alternatives: PlannerAction[];
}
