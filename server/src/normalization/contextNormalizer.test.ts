import { describe, it, expect } from "vitest";
import { normalizeContext } from "./contextNormalizer";

describe("ContextNormalizer", () => {
  it("normalizes a 'commute morning' payload", () => {
    const raw = {
      user_id: "user_123",
      timestamp: "2026-04-24T08:00:00Z",
      location: {
        lat: 37.774928374,
        lon: -122.419415523,
        accuracy: 10,
        provider: "gps",
        source: "gps"
      },
      calendar: {
        next_event: {
          id: "evt_1",
          title: "Morning Meeting",
          start_time: "2026-04-24T09:00:00Z",
          end_time: "2026-04-24T10:00:00Z",
          location_text: "Office Main Hall",
          is_all_day: false
        }
      },
      battery: {
        level: 0.95,
        is_charging: false,
        power_saver_on: false
      },
      device_state: {
        network_type: "5g",
        screen_on: true,
        ringer_mode: "normal"
      },
      meta: {
        client_version: "1.0.0",
        capture_reason: "timer"
      }
    };

    const normalized = normalizeContext(raw);

    expect(normalized.location.lat).toBe(37.774928);
    expect(normalized.location.lon).toBe(-122.419416);
    expect(normalized.calendar.next_event?.importance).toBe("high");
    expect(normalized.derived?.minutes_to_next_event).toBe(60);
    expect(normalized.derived?.is_commute_window).toBe(true);
    expect(normalized.derived?.battery_band).toBe("high");
  });

  it("normalizes an 'office afternoon' payload with urgent event", () => {
    const raw = {
      user_id: "user_123",
      timestamp: "2026-04-24T14:00:00Z",
      calendar: {
        next_event: {
          title: "URGENT: Production Outage",
          start_time: "2026-04-24T14:15:00Z",
          end_time: "2026-04-24T15:00:00Z"
        }
      },
      battery: {
        level: 0.5,
        is_charging: true
      }
    };

    const normalized = normalizeContext(raw);

    expect(normalized.calendar.next_event?.importance).toBe("critical");
    expect(normalized.derived?.minutes_to_next_event).toBe(15);
    expect(normalized.derived?.is_commute_window).toBe(false); // No location_text
    expect(normalized.derived?.battery_band).toBe("ok");
  });

  it("normalizes a 'low-battery late evening' payload", () => {
    const raw = {
      timestamp: "2026-04-24T22:00:00Z",
      battery: {
        level: 0.08,
        is_charging: false,
        power_saver_on: true
      }
    };

    const normalized = normalizeContext(raw);

    expect(normalized.battery.level).toBe(0.08);
    expect(normalized.derived?.battery_band).toBe("critical");
  });

  it("normalizes 'many notifications' payload", () => {
    const raw = {
      notifications: [
        { app_package: "com.whatsapp", body: "Hey there!", posted_at: "2026-04-24T12:00:00Z" },
        { app_package: "com.android.dialer", is_ongoing_call: true },
        { body: "Your login code is 123456", is_otp_hint: true },
        { app_package: "com.shopping.app", body: "Big deals today!" }
      ]
    };

    const normalized = normalizeContext(raw);

    expect(normalized.notifications).toHaveLength(4);
    expect(normalized.notifications[0].category).toBe("message");
    expect(normalized.notifications[1].category).toBe("call");
    expect(normalized.notifications[2].category).toBe("otp");
    expect(normalized.notifications[3].category).toBe("unknown"); // No promo keywords yet in body
  });
});
