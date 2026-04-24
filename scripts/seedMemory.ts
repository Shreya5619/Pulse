import { memoryStore } from "../server/src/services/MemoryStore";

/**
 * seeds plausible memory data for a "Sample User" to help testing UI and Risk Engine.
 */
async function seedMemory() {
  const userId = 'user_plausible';
  console.log(`[SeedMemory] Seeding plausible memory for user: ${userId}`);

  const identity = {
    user_id: userId,
    basics: {
      name: "Plausible Pete",
      primary_language: "en",
      timezone: "America/New_York"
    },
    locations: {
      home: { lat: 40.7128, lon: -74.0060, address: "Kormangala, Bangalore" },
      office: { lat: 40.7580, lon: -73.9855, address: "Campus Lab, Bangalore" }
    },
    commute_preferences: {
      morning_window: { start: "08:30", end: "10:00" },
      evening_window: { start: "18:00", end: "20:00" },
      default_mode: "transit"
    }
  };

  const habits = {
    patterns: {
      departure_offsets: {
        morning: [-12, -8, -5, 2], // Often leaves slightly late
        evening: [10, 15, 20]      // Usually stays late
      },
      typical_lateness: 7, // Pete is usually 7 mins late
      routines: {
        morning_wake_up: "07:15",
        evening_wind_down: "23:30"
      }
    }
  };

  const battery = {
    profile: {
      discharge_rates: {
        active: 0.15, // High active drain
        standby: 0.03
      },
      thresholds: {
        low: 0.25,
        critical: 0.10
      },
      risky_hours: [
        { start: "17:00", end: "19:30", reason: "Evening commute, no charger" }
      ],
      typical_charge_windows: [
        { start: "00:00", end: "07:00" }
      ]
    }
  };

  const commute = {
    routes: [
      {
        id: "daily_commute",
        from_label: "Home",
        to_label: "Office",
        typical_duration_minutes: 42,
        eta_bands: { p50: 42, p90: 58 },
        usual_mode: "transit"
      }
    ],
    recent_anomalies: [
      { date: "2026-04-20", delay_minutes: 25, reason: "Public transport strike" }
    ]
  };

  const notifications = {
    priority_senders: ["Boss", "Mom", "Lab Partner"],
    noisy_packages: ["com.instagram.android", "com.android.vending"],
    quiet_hours: [
      { start: "23:00", end: "07:30" }
    ],
    app_sensitivity: {
      "com.whatsapp": "high",
      "com.slack": "high",
      "com.instagram.android": "low"
    }
  };

  await memoryStore.save(userId, {
    identity: identity as any,
    habits: habits as any,
    battery: battery as any,
    commute: commute as any,
    notifications: notifications as any
  }, 'manual_seed');

  console.log(`[SeedMemory] Successfully seeded memory/${userId}/ and Postgres mirror.`);
  process.exit(0);
}

seedMemory().catch(err => {
  console.error("[SeedMemory] Failed:", err);
  process.exit(1);
});
