import { riskEngine } from "./RiskEngineService";
import { dayPulseService } from "./DayPulseService";
import { plannerEngine } from "./PlannerEngine";
import { futuresEngine } from "./FuturesEngine";
import { notificationSummarizer } from "./NotificationSummarizer";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { GraphAdapter } from "./GraphAdapter";
import { userEventsRepo } from "../db/UserEventsRepository";
import { PersonalityAnalysis } from "./PersonalityAnalyzer";
import { queryGroq } from "../utils/llm";

// Safe JSON parser that strips markdown fences
function parseSafe<T>(text: string): T {
    try { return JSON.parse(text) as T; } catch (_) {}
    const match = text.match(/\{[\s\S]*\}/);
    if (match) { try { return JSON.parse(match[0]) as T; } catch (_) {} }
    throw new Error(`[ChatAgent] Could not parse JSON from: ${text.slice(0, 200)}`);
}


export class ChatAgentService {

    async handleMessage(userId: string, userMessage: string, history: any[] = []): Promise<any> {
        console.log(`[ChatAgent] Handling message for ${userId}: "${userMessage}"`);

        const personality = await GraphAdapter.getUserPersonality(userId);
        const preferences = await GraphAdapter.getUserPreferences(userId);

        const systemPrompt = `
You are the Pulse Digital Twin — the front door to the user's digital self. 
You are NOT a generic assistant. You are "Pulse", an AI that understands the user's live graph, risks, and day.

CONTEXT:
- Current Time: ${new Date().toLocaleString()}
- User ID: ${userId}

PERSONALITY:
- Casual, concise, and highly personalized.
- Speak in terms of "your day", "your risk", "your twin".
- Use the provided context (personality, preferences) to tailor your tone.
- Current Personality: ${JSON.stringify(personality)}
- Current Preferences: ${JSON.stringify(preferences)}

CORE RULES:
1. EXPLAIN: Use 'getCurrentRisks' and 'simulateWhatIf' to explain why things are happening.
2. PLAN: Use 'getDailyPulse' to answer scheduling questions.
3. ACT: Use 'getGuardianActions' and 'applyAction' to help the user.
4. LEARN: If the user shares something about themselves, use 'updateTwinGraph'.
5. SAFETY: Never execute an action that changes a schedule or sends a message without asking for confirmation first.

If you need to call a tool, respond ONLY with the JSON object for that tool. Do NOT include any conversational text or explanation. You can call multiple tools one after another; I will provide the results.
Once you have all information and are ready to talk to the user, respond with natural language text.

TOOLS AVAILABLE:
- getCurrentRisks(): Returns active risks (lateness, battery, overload).
- getDailyPulse(): Returns the today's timeline, predicted battery, and risks.
- getGuardianActions(): Returns recommended interventions.
- getNotificationSummary(): Summarizes recent alerts.
- simulateWhatIf(): Returns 3 future scenarios (Do Nothing, Recommended, Focus).
- updateTwinGraph(data): Update traits, interests, or sentiment. Data: { traits?: string[], interests?: string[], sentiment?: string }.
- addDailyEvent(event): Add a manual event. Event: { title, startTime, endTime, locationText? }. Use FULL ISO 8601 strings for times (e.g., "${new Date().toISOString()}").
- applyAction(actionId): Executes a specific intervention (e.g. 'ACTION_ENABLE_BATTERY_SAVER').

RESPONSE FORMAT:
- Tool call: {"tool": "toolName", "args": {}}
- Final answer: Your message to the user.
- Suggested actions: [Action: Title | ID]
`;

        const messages = [
            { role: "system", content: systemPrompt },
            ...history,
            { role: "user", content: userMessage }
        ];

        let iteration = 0;
        const toolsUsed: string[] = [];

        while (iteration < 8) {
            const llmResponse = await queryGroq(messages);
            
            // Check if LLM wants to use a tool (look for the JSON pattern)
            const jsonMatch = llmResponse.match(/\{[\s\S]*"tool"[\s\S]*\}/);
            if (jsonMatch) {
                try {
                    const toolCall = parseSafe<any>(jsonMatch[0]);
                    if (toolCall.tool) {
                        console.log(`[ChatAgent] Calling tool: ${toolCall.tool}`, toolCall.args);
                        toolsUsed.push(toolCall.tool);
                        const result = await this.callTool(userId, toolCall.tool, toolCall.args);
                        
                        messages.push({ role: "assistant", content: llmResponse });
                        messages.push({ role: "system", content: `Tool Result: ${JSON.stringify(result)}` });
                        iteration++;
                        continue;
                    }
                } catch (e) {
                    console.warn("[ChatAgent] Tool call parse failed:", e.message);
                }
            }

            // Final text response
            return {
                text: llmResponse,
                toolsUsed: Array.from(new Set(toolsUsed))
            };
        }

        return { text: "I'm having trouble connecting the dots right now.", toolsUsed };
    }

    private async callTool(userId: string, toolName: string, args: any): Promise<any> {
        switch (toolName) {
            case "getCurrentRisks":
                return await riskEngine.computeForUser(userId);
            case "getDailyPulse":
                return await dayPulseService.getDailyTimeline(userId, new Date().toISOString().split('T')[0]);
            case "getGuardianActions":
                return await plannerEngine.decideForUser(userId);
            case "getNotificationSummary":
                const context = await contextSnapshotRepo.findLatestByUser(userId);
                if (!context || !context.notification_digest) return "No notifications found.";
                return await notificationSummarizer.summarize(context.notification_digest.top_threads || []);
            case "simulateWhatIf":
                return await futuresEngine.computeForUser(userId);
            case "updateTwinGraph":
                await GraphAdapter.applyPersonalityToNeo4j(userId, {
                    traits: args.traits || [],
                    interests: args.interests || [],
                    sentiment: args.sentiment || "Neutral"
                });
                return "Twin graph updated.";
            case "addDailyEvent":
                const event = {
                    id: `manual_${Date.now()}`,
                    title: args.title,
                    start_time: args.startTime,
                    end_time: args.endTime,
                    location_text: args.locationText,
                    importance: 1
                };
                await userEventsRepo.addManualEvent(userId, event as any);
                return "Event added to Daily Pulse.";
            case "applyAction":
                console.log(`[ChatAgent] Applying action ${args.actionId} for ${userId}`);
                // Simple feedback for now. In a real app, this would trigger device actions.
                return `Action ${args.actionId} triggered.`;
            default:
                return `Unknown tool: ${toolName}`;
        }
    }
}

export const chatAgentService = new ChatAgentService();
