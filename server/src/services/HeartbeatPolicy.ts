import { ContextSnapshot } from "../../../shared/context_snapshot";

/**
 * Computes the recommended delay until the next heartbeat cycle.
 * Dynamically adjusts cadence based on proximity to upcoming events.
 */
export function computeNextHeartbeatDelay(context: ContextSnapshot | null): number {
  // Base delay: 15 minutes (ms)
  if (!context || context.derived?.minutes_to_next_event === undefined || context.derived?.minutes_to_next_event === null) {
    return 15 * 60 * 1000;
  }

  const m = context.derived.minutes_to_next_event;

  if (m > 60) {
    return 10 * 60 * 1000; // 10 min
  }
  if (m > 20) {
    return 5 * 60 * 1000; // 5 min
  }
  if (m > 5) {
    return 60 * 1000; // 1 min
  }
  
  return 30 * 1000; // 30 sec
}
