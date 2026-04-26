import { z } from "zod";

/**
 * ContextSnapshot Schema
 * 
 * This schema defines the structure of data sent from the mobile app to the backend,
 * and enriched by the normalization pipeline.
 */

export const ImportanceSchema = z.enum(["critical", "high", "normal", "low"]);
export type Importance = z.infer<typeof ImportanceSchema>;

export const NotificationCategorySchema = z.enum(["message", "call", "otp", "promo", "unknown"]);
export type NotificationCategory = z.infer<typeof NotificationCategorySchema>;

export const CalendarEventSchema = z.object({
  id: z.string(),
  title: z.string(),
  start_time: z.string().datetime(),
  end_time: z.string().datetime(),
  location_text: z.string().optional().nullable(),
  location: z.object({
    lat: z.number(),
    lon: z.number(),
  }).optional().nullable(),
  is_all_day: z.boolean(),
  importance: ImportanceSchema.default("normal"),
});

export const NotificationItemSchema = z.object({
  id: z.string(), // or hash
  app_package: z.string(),
  sender: z.string().optional().nullable(),
  category: NotificationCategorySchema.default("unknown"),
  is_ongoing: z.boolean(),
  posted_at: z.string().datetime(),
  is_ongoing_call: z.boolean().optional(),
  is_otp_hint: z.boolean().optional(),
});

export const BatteryBandSchema = z.enum(["critical", "low", "ok", "high"]);
export type BatteryBand = z.infer<typeof BatteryBandSchema>;

export const ContextSnapshotSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string(),
  timestamp: z.string().datetime(),

  location: z.object({
    lat: z.number().nullable(),
    lon: z.number().nullable(),
    accuracy: z.number().nullable(),
    provider: z.string().optional().nullable(),
    source: z.enum(["gps", "network", "passive"]).optional().nullable(),
    place_id: z.string().optional().nullable(),
  }),

  calendar: z.object({
    next_event: CalendarEventSchema.nullable(),
    upcoming_events: z.array(CalendarEventSchema), // Limited to next 24h by app
  }),

  battery: z.object({
    level: z.number().min(0).max(1),
    is_charging: z.boolean(),
    power_saver_on: z.boolean(),
    temperature: z.number().optional().nullable(),
    last_full_charge_at: z.string().datetime().optional().nullable(),
  }),

  notifications: z.array(NotificationItemSchema),

  device_state: z.object({
    network_type: z.enum(["wifi", "4g", "5g", "none"]),
    is_roaming: z.boolean(),
    screen_on: z.boolean(),
    do_not_disturb: z.boolean(),
    ringer_mode: z.enum(["normal", "vibrate", "silent"]),
  }),

  meta: z.object({
    client_version: z.string(),
    schema_version: z.string(),
    capture_reason: z.enum(["event_change", "timer", "manual"]),
    replay_trace_id: z.string().optional().nullable(),
  }),

  // Derived flags added by the normalization pipeline
  derived: z.object({
    has_next_event: z.boolean(),
    minutes_to_next_event: z.number().nullable(),
    is_commute_window: z.boolean(),
    battery_band: BatteryBandSchema,
  }).optional(),
});

export type ContextSnapshot = z.infer<typeof ContextSnapshotSchema>;
export type CalendarEvent = z.infer<typeof CalendarEventSchema>;
export type NotificationItem = z.infer<typeof NotificationItemSchema>;
