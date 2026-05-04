import { heartbeatOrchestrator } from "./HeartbeatOrchestrator";
import { WebSocketServer, WebSocket } from "ws";

const runningUsers = new Set<string>();
let lastInterventionText = "";

export async function runAgentPulseFlow(initialContext: any, broadcast: (message: any) => void) {
    const userId = initialContext.user_id || initialContext.userId || "demo-user";
    if (runningUsers.has(userId)) {
        console.log(`[Pulse] Run already in progress for user ${userId}, skipping.`);
        return;
    }

    try {
        runningUsers.add(userId);
        console.log(`[Pulse] Starting orchestrated flow for ${userId}...`);

        const result = await heartbeatOrchestrator.runOnce(userId);

        // Broadcast granular updates
        if (result.context) {
            broadcast({
                type: "context.updated",
                userId,
                eventId: `ctx_${Date.now()}`,
                timestamp: new Date().toISOString(),
                data: result.context
            });
        }

        broadcast({
            type: "graph.updated",
            userId,
            eventId: `graph_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: result.graph.summary
        });

        broadcast({
            type: "risk.updated",
            userId,
            eventId: `risk_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: result.risk
        });

        broadcast({
            type: "futures.updated",
            userId,
            eventId: `fut_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: result.futures
        });

        if (result.decision.chosen) {
            broadcast({
                type: "planner.suggested",
                userId,
                eventId: `plan_${Date.now()}`,
                timestamp: new Date().toISOString(),
                data: result.decision
            });

            if (result.decision.chosen.templateId) {
                broadcast({
                    type: "COMM_ACTION_PROPOSED",
                    userId,
                    eventId: `comm_${Date.now()}`,
                    timestamp: new Date().toISOString(),
                    data: {
                        actionId: result.decision.chosen.id,
                        templateId: result.decision.chosen.templateId,
                        channel: result.decision.chosen.channel,
                        previewText: result.decision.chosen.title // Simple preview for now
                    }
                });
            }
        }

        broadcast({
            type: "guardian.decided",
            userId,
            eventId: `guard_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: {
                userId,
                actionId: result.decision.chosen?.id,
                timestamp: new Date().toISOString(),
                mode: result.guardian.mode,
                rationale: result.guardian.rationale
            }
        });

        broadcast({
            type: "heartbeat.policy",
            userId,
            eventId: `hb_policy_${Date.now()}`,
            timestamp: new Date().toISOString(),
            data: {
                userId,
                nextRecommendedDelayMs: result.nextDelay
            }
        });

        if (result.decision.chosen && result.guardian.approved) {
            lastInterventionText = result.decision.chosen.title;
            broadcast({
                type: "intervention.created",
                userId,
                eventId: `int_${Date.now()}`,
                timestamp: new Date().toISOString(),
                data: {
                    userId,
                    actionId: result.decision.chosen.id,
                    timestamp: new Date().toISOString(),
                    headline: result.decision.chosen.title,
                    body: result.decision.chosen.description,
                    ctaLabel: "Accept",
                    secondaryCtaLabel: "Dismiss"
                }
            });
        }

        console.log("[Pulse] Orchestrated flow completed.");
        return { alert: lastInterventionText };
    } catch (error) {
        console.error("[Pulse] Orchestrated flow error:", error);
    } finally {
        runningUsers.delete(userId);
    }
}
