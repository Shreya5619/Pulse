/**
 * RiskEngine — Pure, deterministic heuristic scoring functions.
 *
 * Each function takes plain numeric inputs and returns a score ∈ [0, 1].
 * The `assess*` wrappers additionally produce a full RiskScore with
 * human-readable summaries and cause lists.
 *
 * These functions are intentionally side-effect-free so they can be
 * unit-tested without any infrastructure.
 */

import { RiskScore, RiskLabel, RiskSnapshot } from "../types/risk";
import { PersonalityAnalysis } from "../services/PersonalityAnalyzer";

// ──────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────

/** Map a numeric score to a severity label. */
export function scoreToLabel(score: number): RiskLabel {
  if (score >= 0.7) return "HIGH";
  if (score >= 0.4) return "MEDIUM";
  return "LOW";
}

/** Clamp a value to [0, 1]. */
function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v));
}

// ──────────────────────────────────────────────────────────────────
// 2.1  Lateness Risk
// ──────────────────────────────────────────────────────────────────

/**
 * Pure scoring function for lateness.
 *
 * @param minutesToEvent  Minutes until the event starts.
 * @param etaMinutes      Estimated travel time (e.g. from OSRM).
 * @param buffer          Habitual buffer the user normally leaves (from memory).
 * @returns Risk score ∈ [0, 1].
 */
export function latenessRisk(
  minutesToEvent: number,
  etaMinutes: number,
  buffer: number
): number {
  const slack = minutesToEvent - etaMinutes - buffer;
  if (slack >= 10) return 0.1;
  if (slack >= 5) return 0.4;
  if (slack >= 0) return 0.7;
  return 0.9; // already projected late
}

/**
 * Full assessment wrapper — adds explanation strings.
 */
export function assessLateness(
  minutesToEvent: number,
  etaMinutes: number,
  buffer: number,
  eventLabel: string,
  nodeId?: string,
  preferences: any[] = [],
  personality?: PersonalityAnalysis
): RiskScore {
  let score = latenessRisk(minutesToEvent, etaMinutes, buffer);
  
  // Apply preferences
  const prefs = Array.isArray(preferences) ? preferences : [];
  const tolerance = prefs.find(p => p.category === 'LATENESS_TOLERANCE' && (p.scope === 'DEFAULT' || eventLabel.includes(p.scope)));
  if (tolerance) {
    if (tolerance.value === 'LOW') score = Math.min(1, score * 1.2);
    if (tolerance.value === 'HIGH') score = score * 0.8;
  }

  // Apply Personality Traits
  if (personality?.traits.includes("Goal-oriented")) {
    score = Math.min(1, score * 1.15); // Higher sensitivity to being late
  }

  const label = scoreToLabel(score);
  const slack = minutesToEvent - etaMinutes - buffer;

  const causes: string[] = [
    `ETA to destination: ${etaMinutes} min`,
    `Event starts in: ${minutesToEvent} min`,
    `Habitual buffer: ${buffer} min`,
    `Effective slack: ${slack.toFixed(1)} min`,
  ];

  if (slack < 0) {
    causes.push(`Projected to arrive ${Math.abs(slack).toFixed(0)} min late`);
  }

  const summary =
    `ETA ${etaMinutes}min, event "${eventLabel}" in ${minutesToEvent}min, ` +
    `you usually leave ${buffer}min early → ${label} lateness risk.`;

  return { type: "lateness", score, label, nodeId, summary, causes };
}

// ──────────────────────────────────────────────────────────────────
// 2.2  Battery Depletion Risk
// ──────────────────────────────────────────────────────────────────

/**
 * Pure scoring function for battery depletion.
 *
 * @param currentPct        Current battery percentage (0–100).
 * @param horizonMinutes    Look-ahead window in minutes.
 * @param dischargePerHour  Average drain rate (%/hour) from memory.
 * @returns Risk score ∈ [0, 1].
 */
export function batteryRisk(
  currentPct: number,
  horizonMinutes: number,
  dischargePerHour: number,
  isCharging: boolean = false,
  powerSaverOn: boolean = false
): number {
  const chargePerHour = 20; // 20% per hour charging
  let effectiveDischarge = dischargePerHour;
  if (powerSaverOn) {
    effectiveDischarge *= 0.6; // Heuristic: Power saver reduces consumption by 40%
  }

  const delta = isCharging 
    ? (chargePerHour * horizonMinutes) / 60 
    : -(effectiveDischarge * horizonMinutes) / 60;
    
  const predictedPct = currentPct + delta;
  if (predictedPct >= 30) return 0.1;
  if (predictedPct >= 20) return 0.4;
  if (predictedPct >= 10) return 0.7;
  return 0.9;
}

/**
 * Full assessment wrapper — adds explanation strings.
 */
export function assessBattery(
  currentPct: number,
  horizonMinutes: number,
  dischargePerHour: number,
  isCharging: boolean = false,
  powerSaverOn: boolean = false,
  nodeId?: string,
  preferences: any[] = [],
  personality?: PersonalityAnalysis
): RiskScore {
  let score = batteryRisk(currentPct, horizonMinutes, dischargePerHour, isCharging, powerSaverOn);

  // Apply preferences
  const prefs = Array.isArray(preferences) ? preferences : [];
  const tolerance = prefs.find(p => p.category === 'BATTERY_TOLERANCE');
  if (tolerance) {
    if (tolerance.value === 'HIGH') score = Math.min(1, score * 1.2); // Anxious about battery
  }

  // Apply Sentiment
  if (personality?.sentiment === "Stressed" || personality?.sentiment === "Overwhelmed") {
    score = Math.min(1, score * 1.1); // Being low on battery is more stressful when already stressed
  }

  const label = scoreToLabel(score);
  let effectiveDischarge = dischargePerHour;
  if (powerSaverOn) effectiveDischarge *= 0.6;

  const chargePerHour = 20;
  const delta = isCharging ? (chargePerHour * horizonMinutes) / 60 : -(effectiveDischarge * horizonMinutes) / 60;
  const predictedPct = currentPct + delta;

  const causes: string[] = [
    `Current battery: ${currentPct}%`,
    `Status: ${isCharging ? 'Charging (+20%/hr)' : (powerSaverOn ? 'Battery Saver Active (-40% drain)' : 'Discharging')}`,
    `Typical drain: ${effectiveDischarge.toFixed(1)}%/hr`,
    `Horizon: ${horizonMinutes.toFixed(1)} min`,
    `Predicted level at horizon: ${Math.max(0, Math.min(100, predictedPct)).toFixed(1)}%`,
  ];

  if (predictedPct < 10 && !isCharging) {
    causes.push("Device may shut down before horizon");
  }

  const summary =
    `Battery ${currentPct}%, ${isCharging ? 'charging' : (powerSaverOn ? 'battery saver active' : 'typical drain ' + dischargePerHour + '%/hr')}, ` +
    `${horizonMinutes.toFixed(0)}min window; predicted ${Math.max(0, Math.min(100, predictedPct)).toFixed(0)}% → ${label} battery risk.`;

  return { type: "battery", score, label, nodeId, summary, causes };
}

// ──────────────────────────────────────────────────────────────────
// 2.3  Response Debt Risk
// ──────────────────────────────────────────────────────────────────

/**
 * Pure scoring function for response debt.
 *
 * @param importantPending  Count of unanswered important messages.
 * @param oldestMinutes     Age (in minutes) of the oldest unanswered message.
 * @returns Risk score ∈ [0, 1].
 */
export function responseDebtRisk(
  importantPending: number,
  oldestMinutes: number
): number {
  if (importantPending === 0) return 0;
  let base = Math.min(1, importantPending / 5);
  if (oldestMinutes > 60) base = Math.min(1, base + 0.2);
  if (oldestMinutes > 180) base = Math.min(1, base + 0.3);
  return base;
}

/**
 * Full assessment wrapper — adds explanation strings.
 */
export function assessResponseDebt(
  importantPending: number,
  oldestMinutes: number,
  nodeId?: string,
  personality?: PersonalityAnalysis
): RiskScore {
  let score = responseDebtRisk(importantPending, oldestMinutes);
  
  // Apply Personality Traits
  if (personality?.traits.includes("Highly responsive to work") || personality?.traits.includes("Highly responsive")) {
    score = Math.min(1, score * 1.25); // Deviation from highly responsive trait is higher risk
  }

  const label = scoreToLabel(score);

  const causes: string[] = [];

  if (importantPending === 0) {
    causes.push("No pending important messages");
  } else {
    causes.push(`${importantPending} unread important message(s)`);
    causes.push(`Oldest unanswered: ${oldestMinutes} min ago`);
    if (oldestMinutes > 180) {
      causes.push("Oldest message exceeds 3-hour threshold (+0.3 boost)");
    } else if (oldestMinutes > 60) {
      causes.push("Oldest message exceeds 1-hour threshold (+0.2 boost)");
    }
  }

  const summary =
    importantPending === 0
      ? "No pending response debt."
      : `${importantPending} unread message(s) from important contacts, ` +
      `oldest ${oldestMinutes} min ago → ${label} response debt.`;

  return { type: "response_debt", score, label, nodeId, summary, causes };
}

// ──────────────────────────────────────────────────────────────────
// 2.4  Overload Risk
// ──────────────────────────────────────────────────────────────────

/**
 * Pure scoring function for schedule/cognitive overload.
 *
 * @param eventsNext90   Number of events in the next 90 minutes.
 * @param overlapScore   Fraction of time-window overlap among events (0–1).
 * @param notifRate      Notifications per 15-minute window.
 * @returns Risk score ∈ [0, 1].
 */
export function overloadRisk(
  eventsNext90: number,
  overlapScore: number,
  notifRate: number
): number {
  let score = 0;
  if (eventsNext90 >= 3) score += 0.4;
  if (overlapScore > 0.5) score += 0.3;
  if (notifRate > 20) score += 0.3;
  return Math.min(1, score);
}

/**
 * Full assessment wrapper — adds explanation strings.
 */
export function assessOverload(
  eventsNext90: number,
  overlapScore: number,
  notifRate: number,
  nodeId?: string,
  personality?: PersonalityAnalysis
): RiskScore {
  let score = overloadRisk(eventsNext90, overlapScore, notifRate);

  // Apply Sentiment
  if (personality?.sentiment === "Stressed" || personality?.sentiment === "Overwhelmed") {
    score = Math.min(1, score + 0.2); // Significant boost to overload if already stressed
  }

  const label = scoreToLabel(score);

  const causes: string[] = [
    `Events in next 90 min: ${eventsNext90}`,
    `Time-window overlap ratio: ${(overlapScore * 100).toFixed(0)}%`,
    `Notification rate: ${notifRate}/15min`,
  ];

  if (eventsNext90 >= 3) causes.push("≥3 events triggers +0.4 score");
  if (overlapScore > 0.5) causes.push(">50% overlap triggers +0.3 score");
  if (notifRate > 20) causes.push(">20 notif/15min triggers +0.3 score");

  const summary =
    `${eventsNext90} event(s) in 90min, ${(overlapScore * 100).toFixed(0)}% overlap, ` +
    `${notifRate} notifs/15min → ${label} overload risk.`;

  return { type: "overload", score, label, nodeId, summary, causes };
}

// ──────────────────────────────────────────────────────────────────
// Snapshot Builder
// ──────────────────────────────────────────────────────────────────

/**
 * Convenience helper to bundle multiple RiskScores into a RiskSnapshot.
 */
export function buildSnapshot(
  userId: string,
  risks: RiskScore[]
): RiskSnapshot {
  return {
    userId,
    timestamp: new Date().toISOString(),
    risks: risks.filter((r) => r.score > 0), // omit zero-risk entries
  };
}

/**
 * Specialized assessment for Acts (location-less events) where connectivity/power is the primary risk.
 */
export function assessActBattery(
  currentPct: number,
  minutesToStart: number,
  dischargePerHour: number,
  isCharging: boolean,
  powerSaverOn: boolean,
  eventLabel: string,
  nodeId?: string
): RiskScore {
  const chargeRate = 20; // 20% per hour charging
  let effectiveDischarge = dischargePerHour;
  if (powerSaverOn) effectiveDischarge *= 0.6;
  
  const delta = isCharging ? (chargeRate * minutesToStart) / 60 : -(effectiveDischarge * minutesToStart) / 60;
  const predictedPct = currentPct + delta;
  
  // Stricter thresholds for Acts because they usually require the device active
  let score = 0.1;
  if (predictedPct < 15) score = 0.9;
  else if (predictedPct < 25) score = 0.7;
  else if (predictedPct < 40) score = 0.4;

  const label = scoreToLabel(score);
  const causes = [
    `Target: "${eventLabel}" (ACT)`,
    `Current battery: ${currentPct}%`,
    `Status: ${isCharging ? 'Charging (+20%/hr)' : (powerSaverOn ? 'Battery Saver Active (-40% drain)' : 'Discharging')}`,
    `Time to start: ${minutesToStart.toFixed(1)} min`,
    `Predicted level: ${Math.max(0, predictedPct).toFixed(1)}%`
  ];

  return {
    type: "battery",
    score,
    label,
    nodeId,
    summary: `Act "${eventLabel}" starts in ${minutesToStart.toFixed(0)}min; predicted ${Math.max(0, predictedPct).toFixed(0)}% battery → ${label} risk.`,
    causes
  };
}
