"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationMemorySchema = exports.CommuteMemorySchema = exports.RouteProfileSchema = exports.BatteryMemorySchema = exports.BatteryProfileSchema = exports.HabitsMemorySchema = exports.HabitPatternSchema = exports.IdentityMemorySchema = void 0;
const zod_1 = require("zod");
/**
 * Memory Model for Pulse
 * These models define the long-term context (memory) of a user,
 * mirrored from OpenClaw expectations for persistent state.
 */
// --- Identity ---
exports.IdentityMemorySchema = zod_1.z.object({
    user_id: zod_1.z.string(),
    basics: zod_1.z.object({
        name: zod_1.z.string().optional(),
        primary_language: zod_1.z.string().default("en"),
        timezone: zod_1.z.string().default("UTC"),
    }),
    locations: zod_1.z.object({
        home: zod_1.z.object({
            lat: zod_1.z.number(),
            lon: zod_1.z.number(),
            address: zod_1.z.string().optional(),
            place_id: zod_1.z.string().optional(),
        }).nullable(),
        office: zod_1.z.object({
            lat: zod_1.z.number(),
            lon: zod_1.z.number(),
            address: zod_1.z.string().optional(),
            place_id: zod_1.z.string().optional(),
        }).nullable(),
    }),
    commute_preferences: zod_1.z.object({
        morning_window: zod_1.z.object({
            start: zod_1.z.string(), // HH:mm
            end: zod_1.z.string(), // HH:mm
        }),
        evening_window: zod_1.z.object({
            start: zod_1.z.string(), // HH:mm
            end: zod_1.z.string(), // HH:mm
        }),
        default_mode: zod_1.z.enum(["transit", "driving", "walking", "cycling"]).default("transit"),
    }),
});
// --- Habits ---
exports.HabitPatternSchema = zod_1.z.object({
    departure_offsets: zod_1.z.object({
        morning: zod_1.z.array(zod_1.z.number()), // minutes relative to event start
        evening: zod_1.z.array(zod_1.z.number()),
    }),
    typical_lateness: zod_1.z.number().default(0), // avg minutes late
    routines: zod_1.z.object({
        morning_wake_up: zod_1.z.string().optional(), // HH:mm
        evening_wind_down: zod_1.z.string().optional(), // HH:mm
    }),
});
exports.HabitsMemorySchema = zod_1.z.object({
    patterns: exports.HabitPatternSchema,
    last_updated: zod_1.z.string().datetime(),
});
// --- Battery Profile ---
exports.BatteryProfileSchema = zod_1.z.object({
    discharge_rates: zod_1.z.object({
        active: zod_1.z.number(), // % per hour
        standby: zod_1.z.number(),
    }),
    thresholds: zod_1.z.object({
        low: zod_1.z.number().default(0.2),
        critical: zod_1.z.number().default(0.1),
    }),
    risky_hours: zod_1.z.array(zod_1.z.object({
        start: zod_1.z.string(), // HH:mm
        end: zod_1.z.string(), // HH:mm
        reason: zod_1.z.string().optional(),
    })),
    typical_charge_windows: zod_1.z.array(zod_1.z.object({
        start: zod_1.z.string(),
        end: zod_1.z.string(),
    })),
});
exports.BatteryMemorySchema = zod_1.z.object({
    profile: exports.BatteryProfileSchema,
    last_updated: zod_1.z.string().datetime(),
});
// --- Commute Profile ---
exports.RouteProfileSchema = zod_1.z.object({
    id: zod_1.z.string(),
    from_label: zod_1.z.string(),
    to_label: zod_1.z.string(),
    typical_duration_minutes: zod_1.z.number(),
    eta_bands: zod_1.z.object({
        p50: zod_1.z.number(),
        p90: zod_1.z.number(),
    }),
    usual_mode: zod_1.z.string(),
});
exports.CommuteMemorySchema = zod_1.z.object({
    routes: zod_1.z.array(exports.RouteProfileSchema),
    recent_anomalies: zod_1.z.array(zod_1.z.object({
        date: zod_1.z.string(),
        delay_minutes: zod_1.z.number(),
        reason: zod_1.z.string().optional(),
    })),
    last_updated: zod_1.z.string().datetime(),
});
// --- Notification Profile ---
exports.NotificationMemorySchema = zod_1.z.object({
    priority_senders: zod_1.z.array(zod_1.z.string()),
    noisy_packages: zod_1.z.array(zod_1.z.string()),
    quiet_hours: zod_1.z.array(zod_1.z.object({
        start: zod_1.z.string(),
        end: zod_1.z.string(),
    })),
    app_sensitivity: zod_1.z.record(zod_1.z.string(), zod_1.z.enum(["high", "normal", "low"])),
    last_updated: zod_1.z.string().datetime(),
});
