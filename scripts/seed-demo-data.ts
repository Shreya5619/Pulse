#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");
const openclawDir = path.join(dataDir, "openclaw");

function ensureDir(dir: string) {
    fs.mkdirSync(dir, { recursive: true });
}

function writeJson(filePath: string, value: unknown) {
    fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n", "utf8");
}

function writeText(filePath: string, value: string) {
    fs.writeFileSync(filePath, value.trim() + "\n", "utf8");
}

ensureDir(dataDir);
ensureDir(openclawDir);

const demoUser = {
    id: "USER_DEMO",
    name: "Alex",
    homeLocation: "Kormangala",
    destination: "Campus Lab",
    quietHours: "23:00-07:00",
    trustedContacts: ["Lab Partner", "Mom"]
};

const demoScenario = {
    id: "COMMUTE_RESCUE_V0",
    title: "Commute Rescue",
    userId: "USER_DEMO",
    context: {
        userId: "USER_DEMO",
        timestamp: "2026-04-22T10:00:00Z",
        locationLabel: "Home",
        batteryPercent: 17,
        minutesToEvent: 25,
        eventName: "Physics Lab",
        trafficStatus: "JAMMED"
    }
};

const demoEvents = [
    { type: "heartbeat.tick", ts: "2026-04-22T10:00:05Z", payload: { userId: "USER_DEMO", sequence: 1 } },
    {
        type: "context.updated",
        ts: "2026-04-22T10:00:06Z",
        payload: demoScenario.context
    },
    {
        type: "risk.updated",
        ts: "2026-04-22T10:00:08Z",
        payload: {
            userId: "USER_DEMO",
            timestamp: "2026-04-22T10:00:08Z",
            scenario: "COMMUTE_LATE",
            score: 0.84,
            label: "HIGH",
            reasons: ["Traffic worsening", "Battery at 17%", "25 minutes to lab"]
        }
    },
    {
        type: "planner.suggested",
        ts: "2026-04-22T10:00:10Z",
        payload: {
            userId: "USER_DEMO",
            timestamp: "2026-04-22T10:00:10Z",
            actionId: "ACTION_LEAVE_NOW",
            title: "Leave now for campus",
            description: "Leave now and enable Battery Saver to stay on time for lab.",
            recommendedAtMinutesToEvent: 25,
            sideEffects: ["Enable Battery Saver", "Prepare delay note"]
        }
    },
    {
        type: "guardian.decided",
        ts: "2026-04-22T10:00:12Z",
        payload: {
            userId: "USER_DEMO",
            actionId: "ACTION_LEAVE_NOW",
            timestamp: "2026-04-22T10:00:12Z",
            mode: "ASK_FIRST",
            rationale: "This action affects commute timing and may notify others."
        }
    },
    {
        type: "intervention.created",
        ts: "2026-04-22T10:00:15Z",
        payload: {
            userId: "USER_DEMO",
            actionId: "ACTION_LEAVE_NOW",
            createdAt: "2026-04-22T10:00:15Z",
            headline: "Leave now and enable Battery Saver",
            body: "Traffic is worsening and your phone is at 17%. Pulse recommends leaving now so you reach lab on time.",
            ctaLabel: "Start commute",
            secondaryCtaLabel: "Dismiss"
        }
    }
];

writeJson(path.join(dataDir, "demo-user.json"), demoUser);
writeJson(path.join(dataDir, "demo-scenario.json"), demoScenario);
writeJson(path.join(dataDir, "demo-events.json"), demoEvents);

writeText(
    path.join(openclawDir, "SOUL.md"),
    `
# SOUL.md
Pulse is calm, helpful, and intervention-first.
Assist, don't nag.
Respect quiet hours and user autonomy.
`.trim()
);

writeText(
    path.join(openclawDir, "agents.md"),
    `
# agents.md
Context Agent: normalize live signals.
Memory Agent: fetch past patterns.
Risk Agent: score near-term failure probability.
Planner Agent: select best intervention.
Guardian Agent: enforce approval policy.
Heartbeat Agent: run periodic evaluation.
`.trim()
);

writeText(
    path.join(openclawDir, "user.md"),
    `
# user.md
User: Alex
Quiet hours: 23:00-07:00
Trusted contacts: Lab Partner, Mom
Preference: Ask before messaging others.
`.trim()
);

writeText(
    path.join(openclawDir, "heartbeat.md"),
    `
# heartbeat.md
Run demo heartbeat every few seconds.
Evaluate context -> risk -> planner -> guardian.
Emit intervention when risk crosses threshold.
`.trim()
);

console.log("[Pulse] Demo data seeded successfully.");
console.log(`[Pulse] Wrote fixtures to ${dataDir}`);