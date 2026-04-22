#!/usr/bin/env node
const http = require("http");

const host = process.env.PULSE_HTTP_HOST || "127.0.0.1";
const port = Number(process.env.PULSE_HTTP_PORT || 8080);

const payload = JSON.stringify({
    userId: process.env.PULSE_DEMO_USER_ID || "USER_DEMO"
});

const req = http.request(
    {
        host,
        port,
        path: "/demo/trigger",
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(payload)
        }
    },
    (res: any) => {
        let body = "";
        res.on("data", (chunk: Buffer) => {
            body += chunk.toString("utf8");
        });
        res.on("end", () => {
            if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
                console.log("[Pulse] Demo replay triggered successfully.");
                console.log(body);
            } else {
                console.error(`[Pulse] Replay failed with status ${res.statusCode}`);
                console.error(body);
                process.exit(1);
            }
        });
    }
);

req.on("error", (err: Error) => {
    console.error("[Pulse] Failed to trigger replay:", err.message);
    process.exit(1);
});

req.write(payload);
req.end();