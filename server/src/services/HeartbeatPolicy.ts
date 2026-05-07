import { ContextSnapshot } from "../../../shared/context_snapshot";
import { heartbeatConfig } from "../config/heartbeatConfig";

/**
 * Computes the recommended delay until the next heartbeat cycle.
 * Dynamically adjusts cadence based on proximity to upcoming events.
 */
export function computeNextHeartbeatDelay(context: ContextSnapshot | null): number {
  const now = new Date();
  const hour = now.getHours();
  const isNight = hour >= 23 || hour < 6;

  if (isNight) {
    console.log(`[HB] Night mode detected (hour: ${hour}). Using interval: ${heartbeatConfig.nightHeartbeatIntervalMs / 1000}s`);
    return heartbeatConfig.nightHeartbeatIntervalMs;
  }

  // Base delay from config
  const baseDelay = heartbeatConfig.heartbeatIntervalMs;

  if (!context || context.derived?.minutes_to_next_event === undefined || context.derived?.minutes_to_next_event === null) {
    return baseDelay;
  }

  const m = context.derived.minutes_to_next_event;

  // If very close to an event, speed up even more than the base interval
  if (m <= 5) {
    return 30 * 1000; // 30 sec
  }
  if (m <= 20) {
    return 60 * 1000; // 1 min
  }
  
  return baseDelay;
}
