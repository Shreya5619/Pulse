import WebSocket from "ws";

/**
 * Pulse WebSocket Test Client
 * This script connects to the local Pulse server, triggers a demo,
 * and logs the standardized events to prove end-to-end connectivity.
 */

const WS_URL = "ws://localhost:8080/ws";
const TRIGGER_URL = "http://localhost:8080/demo/trigger";

async function runTest() {
    console.log(`[Test] Connecting to ${WS_URL}...`);
    const ws = new WebSocket(WS_URL);

    ws.on("open", () => {
        console.log("[Test] WebSocket connected!");
    });

    ws.on("message", (data) => {
        const event = JSON.parse(data.toString());
        console.log(`\n[Event Received] ${event.type}`);
        console.log(`Timestamp: ${event.timestamp}`);
        console.log(`Data: ${JSON.stringify(event.data, null, 2)}`);
    });

    ws.on("close", () => {
        console.log("[Test] WebSocket closed.");
    });

    // Wait a bit for connection to stabilize
    await new Promise(r => setTimeout(r, 1000));

    console.log(`[Test] Triggering demo via POST ${TRIGGER_URL}...`);
    try {
        const response = await fetch(TRIGGER_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ userId: "USER_DEMO" })
        });
        const result = await response.json();
        console.log("[Test] Trigger Response:", JSON.stringify(result, null, 2));
    } catch (error) {
        console.error("[Test] Trigger Failed:", error);
    }
}

runTest();
