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

    // Mocking action lookup - in a real app, you'd fetch the specific proposed action
    // For now, we'll derive the template and recipient from context/actionId
    let templateId: keyof typeof MESSAGE_TEMPLATES | undefined;
    if (actionId.includes("DELAY") || actionId.includes("LATE")) templateId = "RUNNING_LATE";
    else if (actionId.includes("BATTERY")) templateId = "BATTERY_LOW";
    else if (actionId.includes("LEAVE_NOW")) templateId = "ON_THE_WAY";
    else if (actionId.includes("CHARGER")) templateId = "CHARGING_NEEDED";

    if (!templateId) {
      throw new Error("No template found for action: " + actionId);
    }

    let text = MESSAGE_TEMPLATES[templateId];
    const eventTitle = context?.calendar?.next_event?.title || "event";
    const recipient = context?.calendar?.next_event?.organizer_contact || "123-456-7890";

    // Fill placeholders
    if (templateId === "RUNNING_LATE") {
      const minutes = context?.derived?.minutes_to_next_event || 10;
      const eta = this.calculateEta(minutes);
      text = text.replace('{minutes}', Math.abs(minutes).toString())
                 .replace('{event}', eventTitle)
                 .replace('{eta}', eta);
    } else if (templateId === "BATTERY_LOW") {
      text = text.replace('{time}', "30 minutes"); // Heuristic
    } else if (templateId === "ON_THE_WAY") {
      const eta = "10:05 AM"; // From futures if available
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

  private calculateEta(minutesLate: number): string {
    const now = new Date();
    const etaDate = new Date(now.getTime() + (minutesLate > 0 ? minutesLate : 10) * 60000);
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
        "Customer": "highly professional, polite, and reassuring. emphasize that you will be back online soon.",
        "Family": "casual, warm, and personal. feel free to use informal language or emojis.",
        "General": "polite, neutral, and clear."
      }[role] || "polite and neutral";

      const scenario = actionId.includes("LATE") ? "running late for a meeting" : 
                       actionId.includes("BATTERY") ? "low battery/device shutting down" : 
                       actionId.includes("CHARGER") ? "finding a charger" : "on the way";

      const prompt = `Persona: You are writing a short SMS to your ${role}.
      Relationship Tone: ${roleGuidance}.
      Context: ${scenario}.
      
      Task: Rewrite the message below to match this persona while keeping it under 15 words.
      CRITICAL: You MUST include the battery level and the intention to find a charger.
      
      Original: '${text}'`;

      console.log(`[CommService] Polishing for role: ${role}. Prompt: ${prompt}`);
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
          max_tokens: 50
        })
      });

      const data: any = await response.json();
      console.log(`[CommService] Groq Response:`, JSON.stringify(data));
      
      if (!response.ok) {
        console.warn(`[CommService] Groq API returned error: ${data.error?.message || response.statusText}`);
        return text;
      }

      if (!data.choices || data.choices.length === 0) {
        console.warn("[CommService] Groq API returned no choices.");
        return text;
      }

      const polished = data.choices[0]?.message?.content?.trim();
      
      // Clean up quotes if LLM adds them
      return polished ? polished.replace(/^["']|["']$/g, '') : text;
    } catch (error) {
      console.error("[CommService] LLM polishing failed:", error);
      return text;
    }
  }
}

export const communicationService = new CommunicationService();
