import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { memoryStore } from "./MemoryStore";
import { graphBuilder } from "./GraphBuilder";
import { riskEngine } from "./RiskEngineService";
import { futuresEngine } from "./FuturesEngine";
import { plannerEngine } from "./PlannerEngine";
import { guardianAgent } from "../../../agents/guardian";
import { plannerRepo } from "../db/PlannerRepository";
import { heartbeatRepo } from "../db/HeartbeatRepository";
import { logEvent } from "../utils/logger";
import { computeNextHeartbeatDelay } from "./HeartbeatPolicy";
import { workspaceService } from "./WorkspaceService";
import { memoryAgent } from "./MemoryAgent";
import { GraphAdapter } from "./GraphAdapter";
import { personalityAnalyzer } from "./PersonalityAnalyzer";
import { broadcast } from "../index";

export class HeartbeatOrchestrator {
  async runOnce(userId: string) {
    const t0 = new Date().toISOString();
    const heartbeatRules = workspaceService.getHeartbeat();
    console.log(`[HB] Start heartbeat for ${userId} @ ${t0} (Rules: ${heartbeatRules.length} bytes)`);

    // 1. Load context + memory
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const memory = await memoryStore.loadAll(userId);
    logEvent({
      ts: new Date().toISOString(),
      userId,
      phase: "CONTEXT",
      summary: context 
        ? `Context loaded: batt=${Math.round(context.battery.level * 100)}%, minutes_to_event=${context.derived?.minutes_to_next_event ?? 'N/A'}`
        : "No context found",
      details: context
    });

    if (context) {
      // Sync basic snapshot to Neo4j Digital Twin
      await GraphAdapter.applySnapshotToNeo4j(userId, context);

      // Deep analyze notifications to understand personality/traits via digest
      if (context.notification_digest && context.notification_digest.total_count > 0) {
        const analysis = await personalityAnalyzer.analyze(userId, context.notification_digest);
        if (analysis) {
          await GraphAdapter.applyPersonalityToNeo4j(userId, analysis);
          logEvent({
            ts: new Date().toISOString(),
            userId,
            phase: "PERSONALITY",
            summary: `Personality analyzed: ${analysis.traits.length} traits, ${analysis.interests.length} interests extracted`,
            details: analysis
          });
        }
      }
    }

    // 2. Build graph
    const graph = await graphBuilder.buildForUser(userId);
    logEvent({
      ts: new Date().toISOString(),
      userId,
      phase: "GRAPH",
      summary: `Graph built: ${graph.nodes.length} nodes, ${graph.edges.length} edges`,
      details: graph.summary
    });

    // 3. Risk
    const risk = await riskEngine.computeForUser(userId);
    const topRisk = risk.risks.length > 0 ? Math.max(...risk.risks.map(r => r.score)) : 0;
    logEvent({
      ts: new Date().toISOString(),
      userId,
      phase: "RISK",
      summary: `Risk assessed: ${risk.risks.length} risks found, top_score=${topRisk.toFixed(2)}`,
      details: risk
    });

    // Sync risks back to Neo4j
    await GraphAdapter.updateRiskInNeo4j(userId, risk);

    broadcast({
      type: "TWIN_UPDATED",
      userId,
      timestamp: new Date().toISOString()
    });

    // 4. Futures
    const futures = await futuresEngine.computeForUser(userId);
    logEvent({
      ts: new Date().toISOString(),
      userId,
      phase: "FUTURES",
      summary: `Futures simulated: ${futures.futures.length} scenarios projected`,
      details: futures
    });

    // 5. Planner
    const activeScenario = memory.status?.active_scenario || "RECOMMENDED";
    const decision = await plannerEngine.decideForUser(userId, activeScenario);
    logEvent({
      ts: new Date().toISOString(),
      userId,
      phase: "PLANNER",
      summary: decision.chosen 
        ? `Plan proposed: ${decision.chosen.id} (${decision.chosen.title})`
        : "No intervention proposed",
      details: decision
    });

    // 6. Guardian
    const guardian = await guardianAgent(decision.chosen);
    logEvent({
      ts: new Date().toISOString(),
      userId,
      phase: "GUARDIAN",
      summary: `Guardian decided: mode=${guardian.mode}, approved=${guardian.approved}`,
      details: guardian
    });

    // 7. Memory Agent (Contextual Summarization)
    await memoryAgent.onHeartbeat(userId);

    // 8. Persist an audit record
    await plannerRepo.save(decision);
    await heartbeatRepo.save({
      userId,
      startedAt: t0,
      finishedAt: new Date().toISOString(),
      contextId: context?.id,
      riskSnapshot: risk,
      futuresResult: futures,
      plannerDecision: decision,
      guardianDecision: guardian
    });

    // 8. Policy Check
    const nextDelay = computeNextHeartbeatDelay(context);
    console.log(`[HB] Policy: Next heartbeat recommended in ${nextDelay / 1000}s`);

    return { 
      context, 
      graph, 
      risk, 
      futures, 
      decision, 
      guardian,
      nextDelay
    };
  }
}

export const heartbeatOrchestrator = new HeartbeatOrchestrator();
