import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { futuresEngine } from "./FuturesEngine";
import { memoryStore } from "./MemoryStore";
import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

const MESSAGE_TEMPLATES = {
  RUNNING_LATE: 'Running {minutes} minutes late to {event}. ETA {eta}.',
  BATTERY_LOW: 'Battery low, will call after {time}.',
  ON_THE_WAY: 'On the way, new ETA {eta}.',
  CHARGING_NEEDED: 'Battery is critical ({level}%). I might be hard to reach while I find a charger.'
};

export class CommunicationService {
  async prepare(userId: string, actionId: string, role: string = "General") {
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const futures = await futuresEngine.computeForUser(userId);
    const memory = await memoryStore.loadAll(userId);

    let templateId: keyof typeof MESSAGE_TEMPLATES | undefined;
    const aid = actionId.toUpperCase();
    
    if (aid.includes("DELAY") || aid.includes("LATE")) templateId = "RUNNING_LATE";
    else if (aid.includes("BATTERY")) templateId = "BATTERY_LOW";
    else if (aid.includes("LEAVE_NOW") || aid.includes("ON_WAY")) templateId = "ON_THE_WAY";
    else if (aid.includes("CHARGER") || aid.includes("CHARGE")) templateId = "CHARGING_NEEDED";

    if (!templateId) {
      // Fallback for unknown actions
      templateId = "ON_THE_WAY"; 
    }

    let text = MESSAGE_TEMPLATES[templateId];
    const eventTitle = context?.calendar?.next_event?.title || "the meeting";
    const recipient = context?.calendar?.next_event?.organizer_contact || "123-456-7890";

    // Fill placeholders
    if (templateId === "RUNNING_LATE") {
      const minutes = context?.derived?.minutes_to_next_event || 10;
      // If minutes is positive, we are still before the event but predicted late
      // If negative, we are already late.
      const lateAmount = minutes < 0 ? Math.abs(minutes) : 10; 
      const eta = this.calculateEta(lateAmount);
      text = text.replace('{minutes}', lateAmount.toString())
                 .replace('{event}', eventTitle)
                 .replace('{eta}', eta);
    } else if (templateId === "BATTERY_LOW") {
      text = text.replace('{time}', "30 minutes");
    } else if (templateId === "ON_THE_WAY") {
      // Try to get ETA from RECOMMENDED future
      const recommended = futures?.futures.find(f => f.id === "RECOMMENDED");
      const etaMinutes = recommended?.metrics.etaMinutes;
      let eta = "soon";
      if (etaMinutes !== undefined) {
        eta = this.calculateEta(etaMinutes);
      }
      text = text.replace('{eta}', eta);
    } else if (templateId === "CHARGING_NEEDED") {
      const level = Math.round((context?.battery?.level || 0) * 100);
      text = text.replace('{level}', level.toString());
    }

    // Polishing with LLM (Groq) - incorporating role
    const polishedText = await this.polishWithLLM(text, memory, role, actionId);

    return {
      channel: "SMS",
      text: polishedText,
      recipient,
      role,
      actionId,
      availableRoles: ["Manager", "Customer", "Family", "General"]
    };
  }

  private calculateEta(minutesFromNow: number): string {
    const now = new Date();
    const etaDate = new Date(now.getTime() + minutesFromNow * 60000);
    return etaDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  private async polishWithLLM(text: string, memory: any, role: string, actionId: string): Promise<string> {
    const apiKey = process.env.GROQ_API;
    if (!apiKey) {
      console.warn("[CommService] No GROQ_API found, skipping polish.");
      return text;
    }

    try {
      const roleGuidance = {
        "Manager": "professional, respectful, and concise. use a formal tone.",
        "Customer": "highly professional, polite, and reassuring.",
        "Family": "casual, warm, and personal. feel free to use informal language or emojis.",
        "General": "polite, neutral, and clear."
      }[role] || "polite and neutral";

      const isBatteryScenario = actionId.includes("BATTERY") || actionId.includes("CHARGER");
      const scenario = actionId.includes("LATE") ? "running late for a meeting" : 
                       isBatteryScenario ? "low battery/device issues" : "on the way";

      const prompt = `Persona: You are writing a short SMS to your ${role}.
      Relationship Tone: ${roleGuidance}.
      Context: ${scenario}.
      
      Task: Rewrite the message below to match this persona while keeping it under 15 words.
      ${isBatteryScenario ? "CRITICAL: You MUST include the battery level and the intention to find a charger." : "Keep it concise and relevant to the delay."}
      
      Original: '${text}'`;

      console.log(`[CommService] Polishing for role: ${role}.`);
      const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "llama-3.1-8b-instant",
          messages: [
            { role: "system", content: "You are a helpful assistant that polishes messages to be polite and concise." },
            { role: "user", content: prompt }
          ],
          temperature: 0.7,
          max_tokens: 50
        })
      });

      const data: any = await response.json();
      
      if (!response.ok) {
        console.warn(`[CommService] Groq API returned error: ${data.error?.message || response.statusText}`);
        return text;
      }

      const polished = data.choices?.[0]?.message?.content?.trim();
      return polished ? polished.replace(/^["']|["']$/g, '') : text;
    } catch (error) {
      console.error("[CommService] LLM polishing failed:", error);
      return text;
    }
  }

}

export const communicationService = new CommunicationService();
