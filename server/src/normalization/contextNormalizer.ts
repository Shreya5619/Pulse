import * as crypto from "node:crypto";
import {
  ContextSnapshot,
  ContextSnapshotSchema,
  Importance,
  NotificationCategory,
  BatteryBand
} from "../../../shared/context_snapshot";


/**
 * Normalizes a raw context payload from the mobile app into a strict ContextSnapshot.
 */
export function normalizeContext(raw: any): ContextSnapshot {
  const timestamp = new Date(raw.timestamp || Date.now()).toISOString();

  // 1. Normalize Location
  const location = {
    lat: raw.location?.lat != null ? Number(raw.location.lat.toFixed(6)) : null,
    lon: raw.location?.lon != null ? Number(raw.location.lon.toFixed(6)) : null,
    accuracy: raw.location?.accuracy != null ? Number(raw.location.accuracy) : null,
    provider: raw.location?.provider || null,
    source: raw.location?.source || null,
    place_id: raw.location?.place_id || null,
  };

  // 2. Normalize Calendar
  const normalizeEvent = (event: any) => {
    if (!event) return null;
    return {
      id: event.id || String(Math.random()),
      title: event.title || "Untitled Event",
      start_time: new Date(event.start_time).toISOString(),
      end_time: new Date(event.end_time).toISOString(),
      location_text: event.location_text || null,
      location: event.location ? {
        lat: Number(event.location.lat),
        lon: Number(event.location.lon),
      } : null,
      is_all_day: !!event.is_all_day,
      importance: mapImportance(event),
    };
  };

  const next_event = normalizeEvent(raw.calendar?.next_event);
  const upcoming_events = (raw.calendar?.upcoming_events || [])
    .map(normalizeEvent)
    .filter((e: any) => e !== null);

  // 3. Normalize Battery
  const batteryLevel = raw.battery?.level != null ? Math.max(0, Math.min(1, raw.battery.level)) : 0;
  const battery = {
    level: batteryLevel,
    is_charging: !!raw.battery?.is_charging,
    power_saver_on: !!raw.battery?.power_saver_on,
    temperature: raw.battery?.temperature || null,
    last_full_charge_at: raw.battery?.last_full_charge_at ? new Date(raw.battery.last_full_charge_at).toISOString() : null,
  };

  // 4. Normalize Notification Digest
  const notification_digest = raw.notification_digest ? {
    summary_window_minutes: Number(raw.notification_digest.summary_window_minutes) || 60,
    total_count: Number(raw.notification_digest.total_count) || 0,
    by_category: raw.notification_digest.by_category || {},
    top_threads: (raw.notification_digest.top_threads || []).map((t: any) => ({
      sender: String(t.sender),
      count: Number(t.count)
    }))
  } : undefined;

  // 5. Device State
  const device_state = {
    network_type: raw.device_state?.network_type || "none",
    is_roaming: !!raw.device_state?.is_roaming,
    screen_on: !!raw.device_state?.screen_on,
    do_not_disturb: !!raw.device_state?.do_not_disturb,
    ringer_mode: raw.device_state?.ringer_mode || "normal",
  };

  // 6. Meta
  const meta = {
    client_version: raw.meta?.client_version || "1.0.0",
    schema_version: raw.meta?.schema_version || "1.0.0",
    capture_reason: raw.meta?.capture_reason || "timer",
    replay_trace_id: raw.meta?.replay_trace_id || null,
  };

  // 7. Derived Flags
  const now = new Date(timestamp).getTime();
  const nextEventStart = next_event ? new Date(next_event.start_time).getTime() : null;
  const minutes_to_next_event = nextEventStart ? Math.round((nextEventStart - now) / 60000) : null;

  const derived = {
    has_next_event: !!next_event,
    minutes_to_next_event,
    is_commute_window: !!(next_event && minutes_to_next_event !== null && minutes_to_next_event <= 90 && next_event.location_text),
    battery_band: getBatteryBand(batteryLevel),
  };

  const snapshot: ContextSnapshot = {
    id: raw.id || crypto.randomUUID(),
    user_id: raw.user_id || "unknown",
    timestamp,
    location,
    calendar: {
      next_event: next_event as any,
      upcoming_events: upcoming_events as any,
    },
    battery,
    notification_digest,
    device_state: device_state as any,
    meta: meta as any,
    derived,
  };

  // Final validation
  return ContextSnapshotSchema.parse(snapshot);
}

function mapImportance(event: any): Importance {
  const title = (event.title || "").toLowerCase();
  const isHighPriority = event.priority_flag || event.importance_level > 7;

  if (title.includes("urgent") || title.includes("emergency") || title.includes("critical")) return "critical";
  if (isHighPriority || title.includes("meeting") || title.includes("interview") || title.includes("exam")) return "high";
  if (title.includes("lunch") || title.includes("coffee") || title.includes("break")) return "low";
  return "normal";
}

function mapNotificationCategory(n: any): NotificationCategory {
  if (n.is_otp_hint || (n.body || "").toLowerCase().includes("code")) return "otp";
  if (n.is_ongoing_call || n.app_package?.includes("telecom") || n.app_package?.includes("dialer")) return "call";

  const pkg = (n.app_package || "").toLowerCase();
  if (pkg.includes("whatsapp") || pkg.includes("messenger") || pkg.includes("discord") || pkg.includes("slack")) return "message";
  if (pkg.includes("promo") || pkg.includes("deal") || pkg.includes("offer")) return "promo";

  return "unknown";
}

function getBatteryBand(level: number): BatteryBand {
  if (level <= 0.1) return "critical";
  if (level <= 0.25) return "low";
  if (level <= 0.8) return "ok";
  return "high";
}
