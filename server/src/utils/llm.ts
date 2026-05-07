import * as fs from 'fs';
import { Blob } from 'buffer';

function getGroqKeys(): string[] {
    const keys = [
        process.env.GROQ_API_KEY || process.env.GROQ_API,
        process.env.GROQ_FALLBACK,
        process.env.GROQ_API3
    ];
    return keys.filter(k => !!k) as string[];
}

export async function queryGroq(messages: any[], options: { model?: string, temperature?: number, response_format?: any } = {}): Promise<string> {
    const keys = getGroqKeys();
    if (keys.length === 0) throw new Error("No Groq API keys found.");

    let lastError: any = null;

    for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        try {
            const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
                method: "POST",
                headers: { "Content-Type": "application/json", "Authorization": `Bearer ${key}` },
                body: JSON.stringify({
                    model: options.model || "llama-3.3-70b-versatile",
                    messages,
                    response_format: options.response_format,
                    temperature: options.temperature ?? 0.1
                })
            });

            if (!response.ok) {
                let errorDetail = response.statusText;
                try {
                    const errorJson = await response.json();
                    errorDetail = errorJson.error?.message || errorDetail;
                } catch (_) {}
                throw { status: response.status, message: errorDetail };
            }

            const data = await response.json() as any;
            return data.choices?.[0]?.message?.content || "";
        } catch (e: any) {
            lastError = e;
            console.warn(`[LLM Utils] Groq key ${i + 1} failed: ${e.message || e}`);
            // If it's a 401/429 or network error, continue to next key. 
            // Otherwise, it might be a payload error, so we might want to stop, 
            // but for simplicity we'll try all keys.
        }
    }

    throw new Error(`Groq Query Failed after ${keys.length} attempts. Last error: ${lastError?.message || 'Unknown'}`);
}

export async function transcribeAudio(filePath: string): Promise<string> {
    const keys = getGroqKeys();
    if (keys.length === 0) throw new Error("No Groq API keys found for transcription.");

    const fileBuffer = fs.readFileSync(filePath);
    const fileBlob = new Blob([fileBuffer], { type: 'audio/mpeg' });

    let lastError: any = null;

    for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        try {
            const formData = new FormData();
            formData.append("file", fileBlob as any, "recording.m4a");
            formData.append("model", "whisper-large-v3");

            const response = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
                method: "POST",
                headers: { "Authorization": `Bearer ${key}` },
                body: formData
            });

            if (!response.ok) {
                const error = await response.text();
                throw new Error(error);
            }

            const data = await response.json() as any;
            return data.text || "";
        } catch (e: any) {
            lastError = e;
            console.warn(`[LLM Utils] Transcription key ${i + 1} failed: ${e.message || e}`);
        }
    }

    throw new Error(`Transcription failed after ${keys.length} attempts. Last error: ${lastError?.message || 'Unknown'}`);
}
