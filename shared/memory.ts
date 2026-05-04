import { z } from "zod";

/**
 * Memory Model for Pulse
 * These models define the long-term context (memory) of a user,
 * mirrored from OpenClaw expectations for persistent state.
 */

// --- Identity ---
export const IdentityMemorySchema = z.object({
  user_id: z.string(),
  basics: z.object({
    name: z.string().optional(),
    primary_language: z.string().default("en"),
    timezone: z.string().default("UTC"),
  }),
  locations: z.object({
    home: z.object({
      lat: z.number(),
      lon: z.number(),
      address: z.string().optional(),
      place_id: z.string().optional(),
    }).nullable(),
    office: z.object({
      lat: z.number(),
      lon: z.number(),
      address: z.string().optional(),
      place_id: z.string().optional(),
    }).nullable(),
  }),
  commute_preferences: z.object({
    morning_window: z.object({
      start: z.string(), // HH:mm
      end: z.string(),   // HH:mm
    }),
    evening_window: z.object({
      start: z.string(), // HH:mm
      end: z.string(),   // HH:mm
    }),
    default_mode: z.enum(["transit", "driving", "walking", "cycling"]).default("transit"),
  }),
});

export type IdentityMemory = z.infer<typeof IdentityMemorySchema>;

// --- Habits ---
export const HabitPatternSchema = z.object({
  departure_offsets: z.object({
    morning: z.array(z.number()), // minutes relative to event start
    evening: z.array(z.number()),
  }),
  typical_lateness: z.number().default(0), // avg minutes late
  routines: z.object({
    morning_wake_up: z.string().optional(), // HH:mm
    evening_wind_down: z.string().optional(), // HH:mm
  }),
});

export const HabitsMemorySchema = z.object({
  patterns: HabitPatternSchema,
  last_updated: z.string().datetime(),
});

export type HabitsMemory = z.infer<typeof HabitsMemorySchema>;

// --- Battery Profile ---
export const BatteryProfileSchema = z.object({
  discharge_rates: z.object({
    active: z.number(), // % per hour
    standby: z.number(),
  }),
  thresholds: z.object({
    low: z.number().default(0.2),
    critical: z.number().default(0.1),
  }),
  risky_hours: z.array(z.object({
    start: z.string(), // HH:mm
    end: z.string(),   // HH:mm
    reason: z.string().optional(),
  })),
  typical_charge_windows: z.array(z.object({
    start: z.string(),
    end: z.string(),
  })),
});

export const BatteryMemorySchema = z.object({
  profile: BatteryProfileSchema,
  last_updated: z.string().datetime(),
});

export type BatteryMemory = z.infer<typeof BatteryMemorySchema>;

// --- Commute Profile ---
export const RouteProfileSchema = z.object({
  id: z.string(),
  from_label: z.string(),
  to_label: z.string(),
  typical_duration_minutes: z.number(),
  eta_bands: z.object({
    p50: z.number(),
    p90: z.number(),
  }),
  usual_mode: z.string(),
});

export const CommuteMemorySchema = z.object({
  routes: z.array(RouteProfileSchema),
  recent_anomalies: z.array(z.object({
    date: z.string(),
    delay_minutes: z.number(),
    reason: z.string().optional(),
  })),
  last_updated: z.string().datetime(),
});

export type CommuteMemory = z.infer<typeof CommuteMemorySchema>;

// --- Notification Profile ---
export const NotificationMemorySchema = z.object({
  priority_senders: z.array(z.string()),
  noisy_packages: z.array(z.string()),
  quiet_hours: z.array(z.object({
    start: z.string(),
    end: z.string(),
  })),
  app_sensitivity: z.record(z.string(), z.enum(["high", "normal", "low"])),
  last_updated: z.string().datetime(),
});

export type NotificationMemory = z.infer<typeof NotificationMemorySchema>;

export type MemoryState = {
  identity: IdentityMemory | null;
  habits: HabitsMemory | null;
  battery: BatteryMemory | null;
  commute: CommuteMemory | null;
  notifications: NotificationMemory | null;
  status?: {
    active_scenario?: string;
  };
};

