"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ContextSnapshotSchema = exports.BatteryBandSchema = exports.NotificationItemSchema = exports.CalendarEventSchema = exports.NotificationCategorySchema = exports.ImportanceSchema = void 0;
const zod_1 = require("zod");
/**
 * ContextSnapshot Schema
 *
 * This schema defines the structure of data sent from the mobile app to the backend,
 * and enriched by the normalization pipeline.
 */
exports.ImportanceSchema = zod_1.z.enum(["critical", "high", "normal", "low"]);
exports.NotificationCategorySchema = zod_1.z.enum(["message", "call", "otp", "promo", "unknown"]);
exports.CalendarEventSchema = zod_1.z.object({
    id: zod_1.z.string(),
    title: zod_1.z.string(),
    start_time: zod_1.z.string().datetime(),
    end_time: zod_1.z.string().datetime(),
    location_text: zod_1.z.string().optional().nullable(),
    location: zod_1.z.object({
        lat: zod_1.z.number(),
        lon: zod_1.z.number(),
    }).optional().nullable(),
    start_location: zod_1.z.object({
        lat: zod_1.z.number(),
        lon: zod_1.z.number(),
        name: zod_1.z.string().optional().nullable(),
    }).optional().nullable(),
    is_all_day: zod_1.z.boolean(),
    importance: exports.ImportanceSchema.default("normal"),
    organizer_name: zod_1.z.string().optional().nullable(),
    organizer_contact: zod_1.z.string().optional().nullable(),
});
exports.NotificationItemSchema = zod_1.z.object({
    id: zod_1.z.string(), // or hash
    app_package: zod_1.z.string(),
    sender: zod_1.z.string().optional().nullable(),
    category: exports.NotificationCategorySchema.default("unknown"),
    is_ongoing: zod_1.z.boolean(),
    posted_at: zod_1.z.string().datetime(),
    is_ongoing_call: zod_1.z.boolean().optional(),
    is_otp_hint: zod_1.z.boolean().optional(),
    title: zod_1.z.string().optional().nullable(),
    body: zod_1.z.string().optional().nullable(),
});
exports.BatteryBandSchema = zod_1.z.enum(["critical", "low", "ok", "high"]);
exports.ContextSnapshotSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    user_id: zod_1.z.string(),
    timestamp: zod_1.z.string().datetime(),
    location: zod_1.z.object({
        lat: zod_1.z.number().nullable(),
        lon: zod_1.z.number().nullable(),
        accuracy: zod_1.z.number().nullable(),
        provider: zod_1.z.string().optional().nullable(),
        source: zod_1.z.enum(["gps", "network", "passive"]).optional().nullable(),
        place_id: zod_1.z.string().optional().nullable(),
    }),
    calendar: zod_1.z.object({
        next_event: exports.CalendarEventSchema.nullable(),
        upcoming_events: zod_1.z.array(exports.CalendarEventSchema), // Limited to next 24h by app
    }),
    battery: zod_1.z.object({
        level: zod_1.z.number().min(0).max(1),
        is_charging: zod_1.z.boolean(),
        power_saver_on: zod_1.z.boolean(),
        temperature: zod_1.z.number().optional().nullable(),
        last_full_charge_at: zod_1.z.string().datetime().optional().nullable(),
    }),
    notification_digest: zod_1.z.object({
        summary_window_minutes: zod_1.z.number(),
        total_count: zod_1.z.number(),
        by_category: zod_1.z.record(zod_1.z.string(), zod_1.z.number()),
        top_threads: zod_1.z.array(zod_1.z.object({
            sender: zod_1.z.string(),
            count: zod_1.z.number(),
            app_package: zod_1.z.string().optional(),
        })),
    }).optional(),
    device_state: zod_1.z.object({
        network_type: zod_1.z.enum(["wifi", "4g", "5g", "none"]),
        is_roaming: zod_1.z.boolean(),
        screen_on: zod_1.z.boolean(),
        do_not_disturb: zod_1.z.boolean(),
        ringer_mode: zod_1.z.enum(["normal", "vibrate", "silent"]),
    }),
    meta: zod_1.z.object({
        client_version: zod_1.z.string(),
        schema_version: zod_1.z.string(),
        capture_reason: zod_1.z.enum(["event_change", "timer", "manual"]),
        replay_trace_id: zod_1.z.string().optional().nullable(),
    }),
    // Derived flags added by the normalization pipeline
    derived: zod_1.z.object({
        has_next_event: zod_1.z.boolean(),
        minutes_to_next_event: zod_1.z.number().nullable(),
        is_commute_window: zod_1.z.boolean(),
        battery_band: exports.BatteryBandSchema,
    }).optional(),
});
