import { queryGroq } from "../utils/llm";

// Safe JSON parser that strips markdown fences from LLM output
function parseSafe<T>(text: string): T {
    try { return JSON.parse(text) as T; } catch (_) {}
    const match = text.match(/\{[\s\S]*\}/);
    if (match) { try { return JSON.parse(match[0]) as T; } catch (_) {} }
    throw new Error(`[OpenClaw] Could not parse JSON from: ${text.slice(0, 200)}`);
}

// JSON-enforced LLM caller with strict system prompt
async function queryLLM(systemSchema: string, userPrompt: string): Promise<string> {
    const messages = [
        {
            role: "system",
            content: `You are a strict JSON API. Output ONLY a valid JSON object matching this schema: ${systemSchema}. No markdown. No explanations. No extra keys. Start your response with { and end with }.`
        },
        { role: "user", content: userPrompt }
    ];
    return await queryGroq(messages);
}

export class OpenClawOrchestrator {

    /**
     * Executes the 5-agent LLM pipeline.
     * Each agent receives only clean JSON from the previous — no chatty text.
     */
    async runAgents(userId: string, currentContext: string): Promise<any> {
        console.log(`[OpenClaw] 5-Agent Pipeline for user: ${userId}`);

        // 1. Context Agent — normalize raw text into structured state
        const ctxSchema = `{"mood": "string", "energy": "low|medium|high", "current_activity": "string", "stress_level": "integer 0-10"}`;
        const ctxRaw = await queryLLM(ctxSchema, `Normalize this user context into the JSON schema: ${currentContext}`);
        const context = parseSafe<any>(ctxRaw);
        console.log("[OpenClaw] ✅ Context:", context);

        // 2. Memory Agent — detect deviations from historical baseline
        const memSchema = `{"baseline_deviation": "string", "key_pattern": "string", "notable_change": "string", "is_concerning": "boolean"}`;
        const memRaw = await queryLLM(memSchema, `Analyze deviations from typical daily baseline for this context: ${JSON.stringify(context)}`);
        const memory = parseSafe<any>(memRaw);
        console.log("[OpenClaw] ✅ Memory:", memory);

        // 3. Risk Agent — score probability of burnout/missed goals
        const riskSchema = `{"riskScore": "float 0.0-1.0", "reason": "string", "primary_risk": "burnout|missed_goal|stress|health|none"}`;
        const riskRaw = await queryLLM(riskSchema, `Score risk of burnout or missed goals based on: ${JSON.stringify(memory)}`);
        const risk = parseSafe<any>(riskRaw);
        console.log("[OpenClaw] ✅ Risk:", risk);

        // 4. Planner Agent — generate intervention strategy
        const planSchema = `{"action": "string", "rationale": "string", "urgency": "low|medium|high", "estimated_minutes": "integer"}`;
        const planRaw = await queryLLM(planSchema, `Create a mitigation plan for this risk assessment: ${JSON.stringify(risk)}`);
        const plan = parseSafe<any>(planRaw);
        console.log("[OpenClaw] ✅ Plan:", plan);

        // 5. Guardian Agent — safety check before emitting to user
        const guardSchema = `{"approved": "boolean", "finalMessage": "string", "modifications": "string or null"}`;
        const guardRaw = await queryLLM(guardSchema, `Evaluate if this intervention respects user autonomy and quiet hours. Plan: ${JSON.stringify(plan)}`);
        const guardian = parseSafe<any>(guardRaw);
        console.log("[OpenClaw] ✅ Guardian:", guardian);

        return { context, memory, risk, plan, guardian };
    }
}

export const openClawOrchestrator = new OpenClawOrchestrator();
