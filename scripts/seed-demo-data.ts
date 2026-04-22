#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");
const openclawDir = path.join(dataDir, "openclaw");

/**
 * seed-demo-data.ts
 * Generates standardized demo fixtures for the Pulse "Commute Rescue" scenario.
 * Follows the strict { type, eventId, timestamp, data } schema.
 */

function ensureDir(dir) {
    fs.mkdirSync(dir, { recursive: true });
}

function writeJson(filePath, value) {
    fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n", "utf8");
}

function writeText(filePath, value) {
    fs.writeFileSync(filePath, value.trim() + "\n", "utf8");
}

ensureDir(dataDir);
ensureDir(openclawDir);

const USER_ID = "USER_DEMO";

const demoUser = {
    id: USER_ID,
    name: "Alex",
    homeLocation: "Kormangala",
    destination: "Campus Lab",
    quietHours: "23:00-07:00",
    trustedContacts: ["Lab Partner", "Mom"]
};

const demoScenario = {
    id: "COMMUTE_RESCUE_V0",
    title: "Commute Rescue",
    userId: USER_ID,
    context: {
        userId: USER_ID,
        timestamp: "2026-04-22T10:00:00Z",
        locationLabel: "Home",
        batteryPercent: 17,
        minutesToEvent: 25,
        eventName: "Physics Lab",
        trafficStatus: "JAMMED"
    }
};

const demoEvents = [
    { 
        type: "heartbeat.tick", 
        eventId: "tick_1",
        timestamp: "2026-04-22T10:00:05Z", 
        data: { userId: USER_ID, sequence: 1 } 
    },
    {
        type: "context.updated",
        eventId: "ctx_1",
        timestamp: "2026-04-22T10:00:06Z",
        data: demoScenario.context
    },
    {
        type: "risk.updated",
        eventId: "risk_1",
        timestamp: "2026-04-22T10:00:08Z",
        data: {
            userId: USER_ID,
            timestamp: "2026-04-22T10:00:08Z",
            scenario: "COMMUTE_LATE",
            score: 0.84,
            label: "HIGH",
            reasons: ["Traffic worsening", "Battery at 17%", "25 minutes to lab"]
        }
    },
    {
        type: "planner.suggested",
        eventId: "plan_1",
        timestamp: "2026-04-22T10:00:10Z",
        data: {
            userId: USER_ID,
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
        eventId: "guard_1",
        timestamp: "2026-04-22T10:00:12Z",
        data: {
            userId: USER_ID,
            actionId: "ACTION_LEAVE_NOW",
            timestamp: "2026-04-22T10:00:12Z",
            mode: "ASK_FIRST",
            rationale: "This action affects commute timing and may notify others."
        }
    },
    {
        type: "intervention.created",
        eventId: "int_1",
        timestamp: "2026-04-22T10:00:15Z",
        data: {
            userId: USER_ID,
            actionId: "ACTION_LEAVE_NOW",
            timestamp: "2026-04-22T10:00:15Z",
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

writeText(path.join(openclawDir, "SOUL.md"), "# SOUL.md\nPulse is calm, helpful, and intervention-first.\nAssist, don't nag.\nRespect quiet hours and user autonomy.");
writeText(path.join(openclawDir, "agents.md"), "# agents.md\nContext Agent: normalize live signals.\nMemory Agent: fetch past patterns.\nRisk Agent: score near-term failure probability.\nPlanner Agent: select best intervention.\nGuardian Agent: enforce approval policy.\nHeartbeat Agent: run periodic evaluation.");
writeText(path.join(openclawDir, "user.md"), "# user.md\nUser: Alex\nQuiet hours: 23:00-07:00\nTrusted contacts: Lab Partner, Mom\nPreference: Ask before messaging others.");
writeText(path.join(openclawDir, "heartbeat.md"), "# heartbeat.md\nRun demo heartbeat every few seconds.\nEvaluate context -> risk -> planner -> guardian.\nEmit intervention when risk crosses threshold.");

console.log("[Pulse] Demo data seeded successfully with standardized schema.");