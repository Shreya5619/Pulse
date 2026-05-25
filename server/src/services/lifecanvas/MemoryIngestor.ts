import pool from "../../db/db";
import * as fs from "fs";
import * as path from "path";
import { LifeCanvasEvent } from "../../types/lifecanvas";

const SERVER_ROOT = path.resolve(__dirname, "../../..");
const JSON_STORE_PATH = path.join(SERVER_ROOT, "db", "lifecanvas_store.json");

// ─── JSON Store (Postgres-down fallback) ──────────────────────────────────────

function loadStore(): any {
    if (!fs.existsSync(JSON_STORE_PATH)) {
        return { events: [], nodes: [], edges: [], nextNodeId: 100, nextEdgeId: 100 };
    }
    try { return JSON.parse(fs.readFileSync(JSON_STORE_PATH, "utf-8")); }
    catch (_) { return { events: [], nodes: [], edges: [], nextNodeId: 100, nextEdgeId: 100 }; }
}

function saveStore(store: any) {
    try { fs.writeFileSync(JSON_STORE_PATH, JSON.stringify(store, null, 2), "utf-8"); }
    catch (e) { console.error("[LifeCanvasAgent] Failed to write JSON store:", e); }
}

function ingestToJsonStore(
    userId: string, transcript: string, timestamp: string,
    title: string, summary: string, type: string, emotion: string,
    importance: number, themes: string[], people: string[], connections: any[]
) {
    const store = loadStore();

    // Dedup
    const dup = store.events.find(
        (e: any) => e.user_id === userId && e.text_content === transcript
    );
    if (dup) { console.log("[LifeCanvasAgent][JSON] Duplicate, skipping."); return; }

    const eventId = store.nextNodeId++;
    store.events.push({ id: eventId, user_id: userId, type, timestamp, tags: themes, entities: { emotion, people }, importance, text_content: transcript, created_at: new Date().toISOString() });

    const nodeId = store.nextNodeId++;
    store.nodes.push({ id: nodeId, user_id: userId, type: "LIFE_EVENT", label: title, importance, metadata: { eventId, emotion, themes, people, summary, timestamp }, created_at: new Date().toISOString() });

    // Theme nodes + edges
    for (const theme of themes) {
        const t = theme.trim();
        if (!t) continue;
        let themeNode = store.nodes.find((n: any) => n.user_id === userId && n.type === "THEME" && n.label.toLowerCase() === t.toLowerCase());
        if (!themeNode) {
            const themeId = store.nextNodeId++;
            themeNode = { id: themeId, user_id: userId, type: "THEME", label: t, importance: 0.6, metadata: {}, created_at: new Date().toISOString() };
            store.nodes.push(themeNode);
        }
        const edgeId = store.nextEdgeId++;
        store.edges.push({ id: edgeId, user_id: userId, source_id: nodeId, target_id: themeNode.id, relation: "thematic_relation", strength: 1.0, created_at: new Date().toISOString() });
    }

    // Causal connections
    for (const conn of connections) {
        const target = store.nodes.find(
            (n: any) => n.user_id === userId && n.type === "LIFE_EVENT" && n.label.toLowerCase() === (conn.targetLabel || "").toLowerCase()
        );
        if (target) {
            const edgeId = store.nextEdgeId++;
            store.edges.push({ id: edgeId, user_id: userId, source_id: nodeId, target_id: target.id, relation: conn.relation || "emotionally_related", strength: conn.strength ?? 0.5, created_at: new Date().toISOString() });
        }
    }

    saveStore(store);
    console.log(`[LifeCanvasAgent][JSON] Persisted node "${title}" (${type}) + ${themes.length} theme edges.`);
}

// ─── LLM Caller (Groq → Ollama qwen3:4b → rule-based) ───────────────────────
function parseSafe<T>(text: string): T {
    try { return JSON.parse(text) as T; } catch (_) {}
    const match = text.match(/\{[\s\S]*\}/);
    if (match) { try { return JSON.parse(match[0]) as T; } catch (_) {} }
    throw new Error(`[LifeCanvasAgent] Could not parse JSON from: ${text.slice(0, 200)}`);
}

async function queryLLM(systemSchema: string, userPrompt: string): Promise<string> {
    const apiKey = process.env.GROQ_API_KEY || process.env.GROQ_API;

    if (apiKey) {
        try {
            console.log("[LifeCanvasAgent] Querying Groq API...");
            const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
                method: "POST",
                headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
                body: JSON.stringify({
                    model: "llama-3.3-70b-versatile",
                    messages: [
                        { role: "system", content: `You are a strict JSON API. Output ONLY a valid JSON object matching this schema: ${systemSchema}. No markdown. No explanations. No extra keys.` },
                        { role: "user", content: userPrompt }
                    ],
                    response_format: { type: "json_object" }
                })
            });
            if (response.ok) {
                const data = await response.json() as any;
                return data.choices?.[0]?.message?.content || "{}";
            }
            console.warn(`[LifeCanvasAgent] Groq returned status ${response.status}. Falling back to Ollama.`);
        } catch (e) {
            console.warn("[LifeCanvasAgent] Groq fetch failed. Falling back to Ollama.", e);
        }
    }

    try {
        console.log("[LifeCanvasAgent] Querying local Ollama (model: qwen3:4b)...");
        const response = await fetch("http://localhost:11434/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                model: "qwen3:4b",
                messages: [
                    { role: "system", content: `You are a strict JSON API. Output ONLY a valid JSON object matching this schema: ${systemSchema}. No markdown. No explanations.` },
                    { role: "user", content: userPrompt }
                ],
                stream: false
            })
        });
        if (response.ok) {
            const data = await response.json() as any;
            return data.choices?.[0]?.message?.content || "{}";
        }
    } catch (e) {
        console.warn("[LifeCanvasAgent] Local Ollama call failed. Using rule-based fallback.", e);
    }

    // Rule-based fallback
    console.log("[LifeCanvasAgent] Utilizing rule-based self-healing semantic extraction.");
    return JSON.stringify({
        event: {
            title: userPrompt.substring(0, 30) + "...",
            summary: userPrompt,
            type: userPrompt.toLowerCase().includes("goal") ? "GOAL" : "EVENT",
            emotion: "reflective",
            importance: 0.5,
            themes: ["life"],
            people: []
        },
        proposedConnections: []
    });
}

// ─── MemoryIngestor ───────────────────────────────────────────────────────────
export class MemoryIngestor {
    async ingest(userId: string, transcript: string, timestamp: string): Promise<void> {
        console.log(`[LifeCanvasAgent] Starting cognitive ingestion for user: ${userId}`);

        // ── Step 1: Observe & Retrieve Context ──
        let recentNodes: any[] = [];
        let activeThemes: any[] = [];
        let useJsonStore = false;

        try {
            const recentNodesRes = await pool.query(
                `SELECT id, label, type FROM life_graph_nodes WHERE user_id = $1 AND type = 'LIFE_EVENT' ORDER BY created_at DESC LIMIT 15`,
                [userId]
            );
            recentNodes = recentNodesRes.rows;

            const themesRes = await pool.query(
                `SELECT id, label FROM life_graph_nodes WHERE user_id = $1 AND type = 'THEME'`,
                [userId]
            );
            activeThemes = themesRes.rows;

            // Deduplication via DB
            const dupCheck = await pool.query(
                `SELECT id FROM life_canvas_events WHERE user_id = $1 AND text_content = $2 AND timestamp::date = $3::date`,
                [userId, transcript, timestamp.split("T")[0]]
            );
            if (dupCheck.rows.length > 0) {
                console.log("[LifeCanvasAgent] Duplicate log detected, skipping.");
                return;
            }
        } catch (dbErr) {
            console.warn("[LifeCanvasAgent] Postgres unavailable. Switching to JSON store for context.", dbErr);
            useJsonStore = true;
            const store = loadStore();
            recentNodes = store.nodes.filter((n: any) => n.user_id === userId && n.type === "LIFE_EVENT").slice(-15);
            activeThemes = store.nodes.filter((n: any) => n.user_id === userId && n.type === "THEME");

            // JSON store dedup
            const dup = store.events.find((e: any) => e.user_id === userId && e.text_content === transcript);
            if (dup) { console.log("[LifeCanvasAgent] Duplicate log (JSON store), skipping."); return; }
        }

        console.log(`[LifeCanvasAgent] Context: ${recentNodes.length} events, ${activeThemes.length} themes. Store: ${useJsonStore ? "JSON" : "Postgres"}`);

        // ── Step 2: Reason via LLM ──
        const schema = `{
            "event": {
                "title": "Concise title (max 6 words)",
                "summary": "1-sentence semantic summary",
                "type": "EVENT|GOAL|HABIT|INSIGHT",
                "emotion": "excited|calm|anxious|sad|overwhelmed|reflective",
                "importance": 0.5,
                "themes": ["theme1", "theme2"],
                "people": ["person1"]
            },
            "proposedConnections": [
                { "targetLabel": "existing node label", "relation": "caused_by|inspired_by|emotionally_related|identity_shift|habit_cycle|goal_alignment|creative_pattern|relationship_influence", "strength": 0.7 }
            ]
        }`;

        const prompt = `
        Observe this new raw journal entry:
        "${transcript}"

        Existing cognitive graph context:
        - Recent Events: ${JSON.stringify(recentNodes)}
        - Active Themes: ${JSON.stringify(activeThemes)}

        Reason about emotional cycles, passion emergence, and causality. Output structured event details and propose graph edges to semantically related existing nodes.
        `;

        let extractionRaw = "{}";
        try { extractionRaw = await queryLLM(schema, prompt); }
        catch (e) { console.error("[LifeCanvasAgent] LLM query failed:", e); }

        let extraction: any;
        try { extraction = parseSafe<any>(extractionRaw); }
        catch (_) {
            extraction = {
                event: { title: transcript.substring(0, 35), summary: transcript, type: "EVENT", emotion: "reflective", importance: 0.5, themes: ["Journal"], people: [] },
                proposedConnections: []
            };
        }

        const evt = extraction.event || {};
        const title = evt.title || transcript.substring(0, 35);
        const summary = evt.summary || transcript;
        const type = evt.type || "EVENT";
        const emotion = evt.emotion || "reflective";
        const importance = evt.importance !== undefined ? Number(evt.importance) : 0.5;
        const themes: string[] = evt.themes || ["Journal"];
        const people: string[] = evt.people || [];
        const connections: any[] = extraction.proposedConnections || [];

        console.log("[LifeCanvasAgent] Reasoning output:", { title, type, emotion, importance, themes });

        // ── Step 3: Execute ──
        if (useJsonStore) {
            ingestToJsonStore(userId, transcript, timestamp, title, summary, type, emotion, importance, themes, people, connections);
            return;
        }

        const client = await pool.connect();
        try {
            await client.query("BEGIN");

            const eventRes = await client.query(
                `INSERT INTO life_canvas_events (user_id, type, timestamp, tags, entities, importance, text_content)
                 VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
                [userId, type, timestamp, JSON.stringify(themes), JSON.stringify({ emotion, people }), importance, transcript]
            );
            const eventId = eventRes.rows[0].id;

            const nodeRes = await client.query(
                `INSERT INTO life_graph_nodes (user_id, type, label, importance, metadata)
                 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
                [userId, "LIFE_EVENT", title, importance, JSON.stringify({ eventId, emotion, themes, people, summary, timestamp })]
            );
            const newNodeId = nodeRes.rows[0].id;

            for (const theme of themes) {
                const normalizedTheme = theme.trim();
                if (!normalizedTheme) continue;

                const themeCheckRes = await client.query(
                    `SELECT id FROM life_graph_nodes WHERE user_id = $1 AND type = 'THEME' AND LOWER(label) = LOWER($2)`,
                    [userId, normalizedTheme]
                );

                let themeNodeId: number;
                if (themeCheckRes.rows.length > 0) {
                    themeNodeId = themeCheckRes.rows[0].id;
                } else {
                    const newThemeRes = await client.query(
                        `INSERT INTO life_graph_nodes (user_id, type, label, importance, metadata)
                         VALUES ($1, 'THEME', $2, 0.6, '{}') RETURNING id`,
                        [userId, normalizedTheme]
                    );
                    themeNodeId = newThemeRes.rows[0].id;
                }

                await client.query(
                    `INSERT INTO life_graph_edges (user_id, source_id, target_id, relation, strength)
                     VALUES ($1, $2, $3, 'thematic_relation', 1.0)`,
                    [userId, newNodeId, themeNodeId]
                );
            }

            for (const conn of connections) {
                if (!conn.targetLabel) continue;
                const matchRes = await client.query(
                    `SELECT id FROM life_graph_nodes WHERE user_id = $1 AND LOWER(label) = LOWER($2) AND type = 'LIFE_EVENT'`,
                    [userId, conn.targetLabel]
                );
                if (matchRes.rows.length > 0) {
                    const matchedNodeId = matchRes.rows[0].id;
                    await client.query(
                        `INSERT INTO life_graph_edges (user_id, source_id, target_id, relation, strength)
                         VALUES ($1, $2, $3, $4, $5)`,
                        [userId, newNodeId, matchedNodeId, conn.relation || "emotionally_related", conn.strength ?? 0.5]
                    );
                    console.log(`[LifeCanvasAgent] Edge: ${newNodeId} → ${matchedNodeId} via '${conn.relation}'`);
                }
            }

            await client.query("COMMIT");
            console.log("[LifeCanvasAgent] DB transaction committed successfully.");
        } catch (e) {
            await client.query("ROLLBACK");
            console.error("[LifeCanvasAgent] DB transaction rolled back:", e);
            // Last-resort: persist to JSON store so data is never lost
            console.log("[LifeCanvasAgent] Falling back to JSON store after DB error.");
            ingestToJsonStore(userId, transcript, timestamp, title, summary, type, emotion, importance, themes, people, connections);
        } finally {
            client.release();
        }
    }
}

export const memoryIngestor = new MemoryIngestor();
