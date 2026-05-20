// --- State Management ---
let lifeCanvasMd = localStorage.getItem('lifeCanvasMd') || "# Life History\nNo history yet.";
let recentHistoryMd = localStorage.getItem('recentHistoryMd') || "# Last 3 Days\nNo data yet.";
let graphData = JSON.parse(localStorage.getItem('graphData')) || { nodes: [], edges: [] };
let mindTwinData = JSON.parse(localStorage.getItem('mindTwinData')) || { 
    nodes: [
        { data: { id: 'user', name: 'User', type: 'CORE', importance: 50 }, position: { x: 500, y: 500 } },
        { data: { id: 'plans', name: 'Plans', type: 'CATEGORY', importance: 30 }, position: { x: 500, y: 300 } },
        { data: { id: 'activities', name: 'Activities', type: 'CATEGORY', importance: 30 }, position: { x: 700, y: 500 } },
        { data: { id: 'hobbies', name: 'Hobbies', type: 'CATEGORY', importance: 30 }, position: { x: 500, y: 700 } },
        { data: { id: 'duties', name: 'Duties', type: 'CATEGORY', importance: 30 }, position: { x: 300, y: 500 } }
    ], 
    edges: [
        { data: { source: 'user', target: 'plans', label: 'HAS' } },
        { data: { source: 'user', target: 'activities', label: 'HAS' } },
        { data: { source: 'user', target: 'hobbies', label: 'HAS' } },
        { data: { source: 'user', target: 'duties', label: 'HAS' } }
    ] 
};

// --- UI Elements ---
const cyContainer = document.getElementById('cy');
const cyMindContainer = document.getElementById('cyMind');
const logInput = document.getElementById('logInput');
const ingestBtn = document.getElementById('ingestBtn');
const lifeCanvasEl = document.getElementById('lifeCanvasContent');
const recentHistoryEl = document.getElementById('recentHistoryContent');
const llmResponseEl = document.getElementById('llmResponseContent');
const llmSourceEl = document.getElementById('llmSource');
const viewDateEl = document.getElementById('viewDate');
const summarizeDayBtn = document.getElementById('summarizeDayBtn');
const showLifeTreeBtn = document.getElementById('showLifeTree');
const showMindTwinBtn = document.getElementById('showMindTwin');
const groqConfigEl = document.getElementById('groqConfig');
const ollamaConfigEl = document.getElementById('ollamaConfig');
const apiKeyEl = document.getElementById('apiKey');
const ollamaModelEl = document.getElementById('ollamaModel');
const liveClockEl = document.getElementById('liveClock');
const autoConnectEl = document.getElementById('autoConnect');
const timelineHeaderEl = document.getElementById('timelineHeader');
let indexMd = localStorage.getItem('indexMd') || '# Significant Life Events\n';

// --- Initialization ---
const DEFAULT_GROQ_KEY = "";
if (apiKeyEl && !apiKeyEl.value) {
    apiKeyEl.value = DEFAULT_GROQ_KEY;
}
updateContextDisplay();

llmSourceEl.addEventListener('change', (e) => {
    if (e.target.value === 'groq') {
        groqConfigEl.style.display = 'block';
        ollamaConfigEl.style.display = 'none';
    } else {
        groqConfigEl.style.display = 'none';
        ollamaConfigEl.style.display = 'block';
    }
});

// Life Tree Style
const lifeStyle = [
    { selector: 'node', style: { 'background-color': 'data(color)', 'label': 'data(name)', 'color': '#fff', 'font-size': '9px', 'width': 'mapData(importance, 0, 100, 15, 35)', 'height': 'mapData(importance, 0, 100, 15, 35)', 'text-valign': 'bottom', 'text-margin-y': '6px', 'font-family': 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif', 'font-weight': 400, 'min-zoomed-font-size': 4, 'shadow-blur': 10, 'shadow-color': 'data(color)', 'shadow-opacity': 0.4 } },
    { selector: 'node:selected', style: { 'border-width': 1.5, 'border-color': '#fff', 'shadow-color': '#fff', 'shadow-opacity': 0.8 } },
    { selector: 'node[type = "GOAL"]', style: { 'background-color': '#bf5af2' } },
    { selector: 'node[type = "MILESTONE"]', style: { 'background-color': '#64d2ff' } },
    { selector: 'node[type = "START"]', style: { 'background-color': '#fff', 'width': 15, 'height': 15 } },
    { selector: '.timeline-mark', style: { 'background-opacity': 0, 'width': 1, 'height': 1000, 'shape': 'rectangle', 'background-color': 'rgba(255,255,255,0.05)', 'label': 'data(name)', 'color': 'rgba(255,255,255,0.2)', 'font-size': '10px', 'font-family': 'system-ui, monospace', 'text-valign': 'top', 'text-margin-y': '-20px' } },
    { selector: '.current-time-bar', style: { 'width': 1, 'height': 5000, 'shape': 'rectangle', 'background-color': 'rgba(255,255,255,0.4)', 'label': 'NOW', 'color': '#fff', 'font-size': '9px', 'font-family': 'system-ui, monospace', 'text-valign': 'top', 'text-margin-y': '-30px', 'font-weight': 600 } },
    { selector: '.minute-mark', style: { 'background-opacity': 0, 'width': 1, 'height': 600, 'shape': 'rectangle', 'background-color': 'rgba(255,255,255,0.02)', 'display': 'none' } },
    { selector: 'edge', style: { 'width': 0.8, 'line-color': 'rgba(255,255,255,0.2)', 'target-arrow-color': 'rgba(255,255,255,0.3)', 'target-arrow-shape': 'triangle', 'curve-style': 'bezier', 'label': 'data(label)', 'font-size': '7px', 'font-family': 'system-ui, sans-serif', 'color': 'rgba(255,255,255,0.6)', 'arrow-scale': 0.8, 'text-background-opacity': 0.8, 'text-background-color': '#020412', 'text-background-padding': 2 } },
    { selector: 'node.phantom', style: { 'border-style': 'dashed', 'border-width': 1.5, 'border-color': 'rgba(191,90,242,0.6)', 'background-opacity': 0.25, 'color': 'rgba(255,255,255,0.4)', 'shadow-opacity': 0.15, 'shadow-color': '#bf5af2' } }
];

// Mind Twin Style (Neural Network)
const mindStyle = [
    { selector: 'node', style: { 'background-color': '#0a84ff', 'label': 'data(name)', 'color': '#eee', 'font-size': '11px', 'font-family': 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif', 'font-weight': 400, 'text-valign': 'center', 'text-halign': 'center', 'text-wrap': 'wrap', 'text-max-width': '70px', 'width': 'mapData(importance, 0, 100, 24, 64)', 'height': 'mapData(importance, 0, 100, 24, 64)', 'border-width': 1, 'border-color': 'rgba(255,255,255,0.2)', 'background-opacity': 0.8, 'shadow-blur': 15, 'shadow-color': '#0a84ff', 'shadow-opacity': 0.3, 'shadow-offset-x': 0, 'shadow-offset-y': 0 } },
    { selector: 'node:selected', style: { 'border-width': 2, 'border-color': '#fff', 'shadow-color': '#fff', 'shadow-opacity': 0.6 } },
    { selector: 'node[type = "CATEGORY"]', style: { 'background-color': '#bf5af2', 'border-color': 'rgba(191,90,242,0.4)', 'shadow-color': '#bf5af2', 'font-weight': 500, 'font-size': '12px' } },
    { selector: 'node[id = "user"]', style: { 'background-color': '#fff', 'color': '#000', 'width': 44, 'height': 44, 'font-weight': 500, 'border-color': 'rgba(255,255,255,0.3)', 'shadow-color': '#fff', 'shadow-opacity': 0.2 } },
    { selector: ':parent', style: { 'background-color': 'rgba(255,255,255,0.02)', 'background-opacity': 1, 'border-width': 1, 'border-color': 'rgba(255,255,255,0.08)', 'shape': 'roundrectangle', 'label': 'data(name)', 'color': 'rgba(255,255,255,0.3)', 'font-size': '10px', 'font-family': 'system-ui, sans-serif', 'text-valign': 'top', 'padding': '20px' } },
    { selector: 'edge', style: { 'width': 0.6, 'line-color': 'rgba(255,255,255,0.15)', 'target-arrow-shape': 'triangle', 'target-arrow-color': 'rgba(255,255,255,0.25)', 'arrow-scale': 0.6, 'curve-style': 'bezier' } },
    { selector: 'edge[directed = "false"]', style: { 'target-arrow-shape': 'none', 'line-style': 'dashed', 'line-color': 'rgba(255,255,255,0.1)' } }
];

// --- Custom Force-Directed Physics for Mind Twin ---
let physicsRunning = false;
let physicsRAF = null;
const REPULSION = 12000;
const SPRING_K = 0.006;
const SPRING_LEN = 160;
const GRAVITY = 0.008;
const DAMPING = 0.85;
const nodeVelocities = {};

function startMindPhysics() {
    if (physicsRunning) return;
    physicsRunning = true;
    physicsTick();
}

function stopMindPhysics() {
    physicsRunning = false;
    if (physicsRAF) cancelAnimationFrame(physicsRAF);
}

function physicsTick() {
    if (!physicsRunning) return;
    
    const nodes = cyMind.nodes().filter(n => !n.grabbed() && !n.isParent());
    const edges = cyMind.edges();
    const pan = cyMind.pan();
    const zoom = cyMind.zoom();
    const cx = (cyMind.width() / 2 - pan.x) / zoom;
    const cy2 = (cyMind.height() / 2 - pan.y) / zoom;
    
    const forces = {};
    nodes.forEach(n => {
        forces[n.id()] = { x: 0, y: 0 };
        if (!nodeVelocities[n.id()]) nodeVelocities[n.id()] = { x: 0, y: 0 };
    });
    
    const nodeArr = nodes.toArray();
    for (let i = 0; i < nodeArr.length; i++) {
        for (let j = i + 1; j < nodeArr.length; j++) {
            const a = nodeArr[i], b = nodeArr[j];
            const posA = a.position(), posB = b.position();
            let dx = posA.x - posB.x, dy = posA.y - posB.y;
            let dist = Math.sqrt(dx * dx + dy * dy) || 1;
            let force = REPULSION / (dist * dist);
            let fx = (dx / dist) * force, fy = (dy / dist) * force;
            forces[a.id()].x += fx; forces[a.id()].y += fy;
            forces[b.id()].x -= fx; forces[b.id()].y -= fy;
        }
    }
    
    edges.forEach(e => {
        const src = e.source(), tgt = e.target();
        if (!forces[src.id()] || !forces[tgt.id()]) return;
        const posA = src.position(), posB = tgt.position();
        let dx = posB.x - posA.x, dy = posB.y - posA.y;
        let dist = Math.sqrt(dx * dx + dy * dy) || 1;
        let d = dist - SPRING_LEN;
        let fx = (dx / dist) * d * SPRING_K, fy = (dy / dist) * d * SPRING_K;
        forces[src.id()].x += fx; forces[src.id()].y += fy;
        forces[tgt.id()].x -= fx; forces[tgt.id()].y -= fy;
    });
    
    nodes.forEach(n => {
        const pos = n.position();
        forces[n.id()].x += (cx - pos.x) * GRAVITY;
        forces[n.id()].y += (cy2 - pos.y) * GRAVITY;
    });
    
    cyMind.batch(() => {
        nodes.forEach(n => {
            const id = n.id(), vel = nodeVelocities[id];
            vel.x = (vel.x + forces[id].x) * DAMPING;
            vel.y = (vel.y + forces[id].y) * DAMPING;
            const speed = Math.sqrt(vel.x * vel.x + vel.y * vel.y);
            if (speed > 8) { vel.x = (vel.x / speed) * 8; vel.y = (vel.y / speed) * 8; }
            if (speed > 0.05) {
                n.position({ x: n.position().x + vel.x, y: n.position().y + vel.y });
            }
        });
    });
    
    physicsRAF = requestAnimationFrame(physicsTick);
}

// --- Custom Force-Directed Physics for Life Tree (Jelly Timeline) ---
let lifePhysicsRunning = false;
let lifePhysicsRAF = null;
let lifeSnapMode = true; // Default to pinned timeline

document.getElementById('toggleSnap').addEventListener('click', () => {
    lifeSnapMode = !lifeSnapMode;
    const btn = document.getElementById('toggleSnap');
    if (lifeSnapMode) btn.classList.add('active-mode');
    else btn.classList.remove('active-mode');
    startLifePhysics(); // Ensure it's running
});

function startLifePhysics() {
    if (lifePhysicsRunning) return;
    lifePhysicsRunning = true;
    lifePhysicsTick();
}

function lifePhysicsTick() {
    if (!lifePhysicsRunning) return;
    
    // Only apply physics to actual event nodes
    const nodes = cy.nodes().filter(n => !n.grabbed() && n.data('type') !== 'MARK' && n.data('type') !== 'MIN_MARK' && n.data('type') !== 'CURSOR' && n.data('type') !== 'START');
    const edges = cy.edges();
    
    const forces = {};
    nodes.forEach(n => {
        forces[n.id()] = { x: 0, y: 0 };
        if (!nodeVelocities[n.id()]) nodeVelocities[n.id()] = { x: 0, y: 0 };
    });

    if (!lifeSnapMode) {
        // Full Jelly Mode: node repulsion + edge springs
        const nodeArr = nodes.toArray();
        for (let i = 0; i < nodeArr.length; i++) {
            for (let j = i + 1; j < nodeArr.length; j++) {
                const a = nodeArr[i], b = nodeArr[j];
                const posA = a.position(), posB = b.position();
                let dx = posA.x - posB.x, dy = posA.y - posB.y;
                let dist = Math.sqrt(dx * dx + dy * dy) || 1;
                let force = REPULSION / (dist * dist);
                let fx = (dx / dist) * force, fy = (dy / dist) * force;
                forces[a.id()].x += fx; forces[a.id()].y += fy;
                forces[b.id()].x -= fx; forces[b.id()].y -= fy;
            }
        }
        
        edges.forEach(e => {
            const src = e.source(), tgt = e.target();
            if (!forces[src.id()] || !forces[tgt.id()]) return;
            const posA = src.position(), posB = tgt.position();
            let dx = posB.x - posA.x, dy = posB.y - posA.y;
            let dist = Math.sqrt(dx * dx + dy * dy) || 1;
            let d = dist - 100; // shorter spring for life tree
            let fx = (dx / dist) * d * SPRING_K, fy = (dy / dist) * d * SPRING_K;
            forces[src.id()].x += fx; forces[src.id()].y += fy;
            forces[tgt.id()].x -= fx; forces[tgt.id()].y -= fy;
        });

        // Soft gravity towards chrono anchor to keep them roughly on timeline
        nodes.forEach(n => {
            const pos = n.position();
            const cx = n.data('chronoX') || pos.x;
            const cy_anchor = n.data('chronoY') || pos.y;
            forces[n.id()].x += (cx - pos.x) * 0.05; // Strict on X
            forces[n.id()].y += (cy_anchor - pos.y) * 0.01; // Very loose on Y
        });
    } else {
        // Snap Mode: Strong pull to exact chrono position
        nodes.forEach(n => {
            const pos = n.position();
            const cx = n.data('chronoX') || pos.x;
            const cy_anchor = n.data('chronoY') || pos.y;
            forces[n.id()].x += (cx - pos.x) * 0.3; 
            forces[n.id()].y += (cy_anchor - pos.y) * 0.3;
        });
    }
    
    cy.batch(() => {
        nodes.forEach(n => {
            const id = n.id(), vel = nodeVelocities[id];
            const damping = lifeSnapMode ? 0.4 : DAMPING; // Faster settling when snapped
            vel.x = (vel.x + forces[id].x) * damping;
            vel.y = (vel.y + forces[id].y) * damping;
            const speed = Math.sqrt(vel.x * vel.x + vel.y * vel.y);
            const maxSpeed = lifeSnapMode ? 40 : 8;
            if (speed > maxSpeed) { vel.x = (vel.x / speed) * maxSpeed; vel.y = (vel.y / speed) * maxSpeed; }
            if (speed > 0.05) {
                n.position({ x: n.position().x + vel.x, y: n.position().y + vel.y });
            }
        });
    });
    
    lifePhysicsRAF = requestAnimationFrame(lifePhysicsTick);
}

const cy = cytoscape({
    container: cyContainer,
    elements: graphData,
    style: lifeStyle,
    layout: { name: 'preset' }
});

const cyMind = cytoscape({
    container: cyMindContainer,
    elements: mindTwinData,
    style: mindStyle,
    layout: { name: 'preset' },
    userZoomingEnabled: true,
    userPanningEnabled: true,
    boxSelectionEnabled: true
});

// Start live physics after a short delay (lets elements render first)
setTimeout(() => {
    startMindPhysics();
    startLifePhysics();
}, 600);

// Tab Switching
showLifeTreeBtn.addEventListener('click', () => {
    showLifeTreeBtn.classList.add('active');
    showMindTwinBtn.classList.remove('active');
    cyContainer.classList.add('active');
    cyMindContainer.classList.remove('active');
    timelineHeaderEl.style.display = 'block';
    cy.resize();
    cy.fit();
});

showMindTwinBtn.addEventListener('click', () => {
    showMindTwinBtn.classList.add('active');
    showLifeTreeBtn.classList.remove('active');
    cyMindContainer.classList.add('active');
    cyContainer.classList.remove('active');
    timelineHeaderEl.style.display = 'none';
    cyMind.resize();
    cyMind.fit();
});

if (graphData.nodes.length === 0) {
    const rootId = 'root_today';
    cy.add({
        group: 'nodes',
        data: { id: rootId, name: 'Today', type: 'START', importance: 20 },
        position: { x: 100, y: 300 }
    });
    saveGraph();
}

// Set default date to today and load
viewDateEl.valueAsDate = new Date();
loadDayData();

// Live Cursor & Clock Update
setInterval(() => {
    updateCurrentTimeBar();
    const now = new Date();
    if (liveClockEl) liveClockEl.innerText = now.toLocaleTimeString('en-US', { hour12: false });
}, 1000);
updateCurrentTimeBar();

viewDateEl.addEventListener('change', () => {
    loadDayData();
});

async function summarizeDay() {
    // Legacy stub — no longer used, replaced by 2-sub-feature modal
}

// Brainstorm panel — prevent Cytoscape from stealing mouse events
document.getElementById('mindTodoPanel').addEventListener('mousedown', e => e.stopPropagation());
document.getElementById('mindTodoPanel').addEventListener('pointerdown', e => e.stopPropagation());

summarizeDayBtn.addEventListener('click', () => {
    // Populate date checklist from lifeCanvasMd day headers
    const modal = document.getElementById('summarizeModal');
    const container = document.getElementById('dateChecklistContainer');
    const dayMatches = [...lifeCanvasMd.matchAll(/###\s+(\d{4}-\d{2}-\d{2})/g)];
    if (dayMatches.length === 0) {
        container.innerHTML = '<p style="color:var(--text-dim);font-size:11px;">No day summaries yet.</p>';
    } else {
        container.innerHTML = dayMatches.map(m =>
            `<label class="tidy-item leaf"><input type="checkbox" value="${m[1]}"> ${m[1]}</label>`
        ).join('');
    }
    modal.classList.add('open');
});
document.getElementById('closeSummarize').onclick = () => document.getElementById('summarizeModal').classList.remove('open');

document.getElementById('sumNewLogsBtn').addEventListener('click', async () => {
    const apiKey = apiKeyEl.value.trim();
    if (!apiKey) { showToast('Need Groq API Key'); return; }
    const btn = document.getElementById('sumNewLogsBtn');
    btn.disabled = true; btn.innerText = 'THINKING...';
    try {
        const prompt = `Summarize these NEW log entries into 1-2 paragraphs. Focus on goals, actions, and insights.
try to keep it brief points (e.g., "did this", "learned that", "ate a this").
Do NOT re-summarize old events from: ${indexMd.slice(0, 300)}
NEW LOGS:
${recentHistoryMd}
Output: concise summary text only.`;
        const summary = await fetchLlm(prompt, 'groq', apiKey, '');
        lifeCanvasMd += `\n\n### ${viewDateEl.value}\n${summary}`;
        recentHistoryMd = '# Logs for ' + viewDateEl.value + '\n';
        saveDayData(); updateContextDisplay();
        document.getElementById('summarizeModal').classList.remove('open');
        showToast('Summarized into lifecanvas.md!');
    } catch(e) { showToast('Failed: ' + e.message); }
    finally { btn.disabled = false; btn.innerText = 'SUMMARIZE NEW LOGS'; }
});

document.getElementById('sumRangeBtn').addEventListener('click', async () => {
    const selected = [...document.querySelectorAll('#dateChecklistContainer input:checked')].map(i => i.value);
    if (selected.length === 0) { showToast('Select at least one day.'); return; }
    const apiKey = apiKeyEl.value.trim();
    if (!apiKey) { showToast('Need Groq API Key'); return; }
    const btn = document.getElementById('sumRangeBtn');
    btn.disabled = true; btn.innerText = 'THINKING...';
    try {
        // Extract the content for each selected day from lifeCanvasMd
        const sections = selected.map(d => {
            const re = new RegExp(`###\\s*${d}([\\s\\S]*?)(?=###|$)`);
            const m = lifeCanvasMd.match(re);
            return m ? `[${d}]: ${m[1].trim()}` : '';
        }).filter(Boolean).join('\n\n');
        const prompt = `Create an ultra-short summary of summaries (3-5 sentences total) for these days:\n${sections}\nWrite strictly in the first-person perspective (e.g., "I focused on...", "I achieved...").\nOutput: condensed text only.`;
        const result = await fetchLlm(prompt, 'groq', apiKey, '');
        lifeCanvasMd += `\n\n### Summary (${selected[0]} to ${selected[selected.length-1]})\n${result}`;
        saveDayData(); updateContextDisplay();
        document.getElementById('summarizeModal').classList.remove('open');
        showToast('Range summary added to lifecanvas.md!');
    } catch(e) { showToast('Failed: ' + e.message); }
    finally { btn.disabled = false; btn.innerText = 'SUMMARIZE SELECTED DAYS'; }
});

function loadDayData() {
    const dateStr = viewDateEl.value;
    lifeCanvasMd = localStorage.getItem('lifeCanvasMd') || '# Life History\nNo history yet.';
    recentHistoryMd = localStorage.getItem(`recentHistoryMd_${dateStr}`) || '# Logs for ' + dateStr + '\n';
    indexMd = localStorage.getItem('indexMd') || '# Significant Life Events\n';

    // --- Multi-day merge: load ALL saved days into the graph ---
    cy.elements().remove();
    const allKeys = Object.keys(localStorage).filter(k => k.startsWith('graphData_'));
    const loadedIds = new Set();
    allKeys.forEach(key => {
        try {
            const els = JSON.parse(localStorage.getItem(key));
            if (els && els.nodes) {
                els.nodes.forEach(n => {
                    if (!loadedIds.has(n.data.id)) {
                        loadedIds.add(n.data.id);
                        if (n.data.chronoX === undefined) {
                            n.data.chronoX = n.position.x;
                            n.data.chronoY = n.position.y;
                        }
                        cy.add(n);
                    }
                });
                els.edges.forEach(e => {
                    const eid = e.data.id || `${e.data.source}_${e.data.target}`;
                    if (!loadedIds.has(eid)) {
                        loadedIds.add(eid);
                        try { cy.add(e); } catch(_) {}
                    }
                });
            }
        } catch(_) {}
    });

    // Ensure today's Day Start exists
    if (cy.getElementById('root_' + dateStr).length === 0) {
        cy.add({
            group: 'nodes',
            data: { id: 'root_' + dateStr, name: dateStr, type: 'START', importance: 20 },
            position: { x: 100, y: 300 }
        });
    }

    // Cleanup Mind Twin tangles
    cyMind.nodes().forEach(node => {
        if (node.id() === 'user' || node.data('type') === 'CATEGORY') return;
        const incomingEdges = node.incomers('edge');
        if (incomingEdges.length > 1) {
            const userEdge = incomingEdges.filter(e => e.source().id() === 'user');
            if (userEdge.length > 0 && incomingEdges.length > userEdge.length) cyMind.remove(userEdge);
        }
    });

    drawTimeline();
    updateContextDisplay();
    cy.fit();
}

function saveDayData() {
    const dateStr = viewDateEl.value;
    localStorage.setItem('lifeCanvasMd', lifeCanvasMd);
    localStorage.setItem(`recentHistoryMd_${dateStr}`, recentHistoryMd);
    
    // Filter out UI markers so they aren't saved to localStorage
    const coreNodes = cy.nodes('[type != "MARK"][type != "MIN_MARK"][type != "CURSOR"]').map(n => n.json());
    const allEdges = cy.edges().map(e => e.json());
    
    localStorage.setItem(`graphData_${dateStr}`, JSON.stringify({ nodes: coreNodes, edges: allEdges }));
    localStorage.setItem('mindTwinData', JSON.stringify(cyMind.json().elements));
}

// Replace original saveGraph with saveDayData logic
function saveGraph() {
    saveDayData();
}

function updateMindTwin(update) {
    // Safety: Ensure root 'user' node exists
    if (cyMind.getElementById('user').length === 0) {
        cyMind.add({
            group: 'nodes',
            data: { id: 'user', name: 'User', type: 'CORE', importance: 50 }
        });
    }

    if (update.newNode) {
        const id = update.newNode.id || `mind_${Date.now()}`;
        let parentId = update.newNode.parentId || 'user';
        
        // Auto-recreate missing parent if it's a known category or requested as new
        if (cyMind.getElementById(parentId).length === 0) {
            console.log("Parent category missing, re-creating:", parentId);
            const catId = parentId.toLowerCase().replace(/\s+/g, '_');
            
            // Create the missing category first
            if (cyMind.getElementById(catId).length === 0) {
                cyMind.add({
                    group: 'nodes',
                    data: { id: catId, name: parentId.charAt(0).toUpperCase() + parentId.slice(1), type: 'CATEGORY', importance: 30 }
                });
                cyMind.add({
                    group: 'edges',
                    data: { source: 'user', target: catId, label: 'HAS' }
                });
            }
            parentId = catId;
        }

        if (cyMind.getElementById(id).length === 0) {
            cyMind.add({
                group: 'nodes',
                data: { ...update.newNode, id }
            });
            cyMind.add({
                group: 'edges',
                data: { source: parentId, target: id, label: 'HAS' }
            });
        }
    }

    // Process Graph Mutations
    if (update.graphMutations) {
        const mut = update.graphMutations;
        if (mut.deleteNodes) {
            mut.deleteNodes.forEach(id => { cyMind.getElementById(id).remove(); });
        }
        if (mut.deleteEdges) {
            mut.deleteEdges.forEach(e => {
                cyMind.edges(`[source = "${e.sourceId}"][target = "${e.targetId}"]`).remove();
                cyMind.edges(`[source = "${e.targetId}"][target = "${e.sourceId}"]`).remove();
            });
        }
        if (mut.addEdges) {
            mut.addEdges.forEach(e => {
                const sourceExists = cyMind.getElementById(e.sourceId).length > 0;
                const targetExists = cyMind.getElementById(e.targetId).length > 0;
                if (sourceExists && targetExists) {
                    cyMind.add({ group: 'edges', data: { source: e.sourceId, target: e.targetId, label: e.label || 'LINK' } });
                }
            });
        }
    }

    startMindPhysics();
    saveDayData();
}

function renderReasoningStep(step) {
    const timeline = document.getElementById('agentStepTimeline');
    if (!timeline) return;
    
    // Clear placeholder
    const placeholder = timeline.querySelector('.no-trace-placeholder');
    if (placeholder) {
        timeline.innerHTML = '';
    }
    
    const stepEl = document.createElement('div');
    stepEl.className = 'agent-step';
    
    let emoji = '🧠';
    if (step.type === 'command') emoji = '💻';
    if (step.type === 'cypher') emoji = '🔍';
    if (step.type === 'result') emoji = '⚡';
    if (step.type === 'final') emoji = '✅';
    
    stepEl.innerHTML = `
        <div class="agent-step-rail">
            <div class="agent-step-icon agent-step-icon--${step.type}">${emoji}</div>
            <div class="agent-step-line"></div>
        </div>
        <div class="agent-step-body">
            <div class="agent-step-head">
                <span class="agent-step-num">Step ${step.id}</span>
                <span class="agent-step-title">${step.title}</span>
                <span class="agent-step-time">${new Date().toLocaleTimeString()}</span>
            </div>
            <div class="agent-step-detail">${step.detail}</div>
            ${step.cmd ? `<pre class="agent-step-cmd">${step.cmd}</pre>` : ''}
        </div>
    `;
    
    timeline.appendChild(stepEl);
    timeline.scrollTop = timeline.scrollHeight;
}

const sleep = ms => new Promise(res => setTimeout(res, ms));

async function ingestLog() {
    console.log("Ingest button clicked");
    const text = logInput.value.trim();
    const source = llmSourceEl.value;
    const autoConnect = autoConnectEl.checked;
    
    let apiKey = apiKeyEl.value.trim();
    const ollamaModel = ollamaModelEl.value.trim();
    
    if (source === 'groq') {
        if (!apiKey) apiKey = DEFAULT_GROQ_KEY;
    }

    if (!text) { showToast("Please enter a log"); return; }

    ingestBtn.disabled = true;
    ingestBtn.innerText = "THINKING...";

    const timeline = document.getElementById('agentStepTimeline');
    if (timeline) timeline.innerHTML = '';

    try {
        const timestamp = new Date().toLocaleString();
        
        // Step 1: Observing log input
        renderReasoningStep({
            id: 1,
            type: 'thinking',
            title: 'Observing Raw Input',
            detail: `Analyzing raw user entry log: "${text.substring(0, 60)}${text.length > 60 ? '...' : ''}"`
        });
        await sleep(600);
        
        // Step 2: Retrieving Context
        renderReasoningStep({
            id: 2,
            type: 'command',
            title: 'Context Retrieval',
            detail: 'Retrieving temporal and theme-based memory slots to ground reasoning context...'
        });
        await sleep(600);
        
        // Step 3: LLM Extraction (Dual Graph Update)
        renderReasoningStep({
            id: 3,
            type: 'cypher',
            title: `Reasoning Loop (${source === 'groq' ? 'Groq Llama-3.3' : 'Ollama Local'})`,
            detail: `Sending prompt to the cognitive engine for emotional causal mapping...`,
            cmd: `PROMPT PREVIEW:\n- Context size: ${getFocusedNodes(text).length} nodes\n- Target schema: Dual-Graph format`
        });
        
        const extraction = await callLlm(text, source, apiKey, ollamaModel, autoConnect);
        
        // Update LLM Response Display
        llmResponseEl.innerText = JSON.stringify(extraction, null, 2);
        await sleep(600);
        
        // Step 4: Proposing mutations
        renderReasoningStep({
            id: 4,
            type: 'result',
            title: 'Proposing Mutations',
            detail: `Planned node creation: [${extraction.lifeTreeUpdate?.newNode?.name || 'none'}] (${extraction.lifeTreeUpdate?.newNode?.type || 'N/A'})`,
            cmd: `MUTATION JSON:\n${JSON.stringify({ lifeTree: extraction.lifeTreeUpdate?.newNode, mindTwin: extraction.mindTwinUpdate?.newNode }, null, 2)}`
        });
        await sleep(600);
        
        // 2. Update Files (Simulated)
        recentHistoryMd += `\n[${timestamp}] ${text}`;
        localStorage.setItem('recentHistoryMd', recentHistoryMd);
        
        // 3. Update Life Tree (Chronological)
        if (extraction.lifeTreeUpdate) {
            addNodeToGraph(extraction.lifeTreeUpdate, text, autoConnect);
        }
        
        // 4. Update Mind Twin (Semantic)
        if (extraction.mindTwinUpdate) {
            updateMindTwin(extraction.mindTwinUpdate);
        }
        
        // Step 5: Applied changes
        renderReasoningStep({
            id: 5,
            type: 'final',
            title: 'Graph Mutations Applied',
            detail: 'Successfully registered new nodes, color-coded themes, and causal relationship edges!'
        });
        
        // 5. Cleanup
        logInput.value = "";
        updateContextDisplay();
    } catch (e) {
        console.error(e);
        showToast("Extraction failed: " + e.message);
        renderReasoningStep({
            id: 5,
            type: 'thinking',
            title: 'Agent Error',
            detail: `Cognitive engine encountered an error: ${e.message}. Fallback applied.`
        });
    } finally {
        ingestBtn.disabled = false;
        ingestBtn.innerText = "INGEST LOG";
    }
}

async function callLlm(text, source, apiKey, model, autoConnect) {
    let cleanApiKey = (apiKey || "").trim() || DEFAULT_GROQ_KEY;
    if (cleanApiKey.includes('=')) {
        cleanApiKey = cleanApiKey.split('=')[1].replace(/['"]/g, '').trim();
    }

    const lifeNodesContext = getFocusedNodes(text).map(n => `ID: ${n.id()} | Name: ${n.data('name')}`).join('\n');
    const mindNodesContext = cyMind.nodes().map(n => `ID: ${n.id()} | Name: ${n.data('name')}`).join('\n');
    const mindEdgesContext = cyMind.edges().map(e => `${e.source().id()} -> ${e.target().id()}`).join('\n');

    const lifeTreeSchema = autoConnect 
        ? `"newNode": { "id": "unique_id", "name": "...", "type": "GOAL|EVENT|HABIT|INSIGHT", "importance": 20-60, "summary": "...", "color": "#hex" },
         "connections": [{ "sourceId": "id", "targetId": "id", "label": "Relation" }],
         "graphMutations": { "deleteNodes": ["id"], "addEdges": [{"sourceId": "id", "targetId": "id", "label": "Relation"}], "deleteEdges": [{"sourceId": "id", "targetId": "id"}] }`
        : `"newNode": { "id": "unique_id", "name": "...", "type": "GOAL|EVENT|HABIT|INSIGHT", "importance": 20-60, "summary": "...", "color": "#hex" },
         "graphMutations": { "deleteNodes": ["id"], "addEdges": [{"sourceId": "id", "targetId": "id", "label": "Relation"}], "deleteEdges": [{"sourceId": "id", "targetId": "id"}] }`;

    const prompt = `
    TASK: Process life log for DUAL-GRAPH updates. The input might be a new event OR an instruction to modify the graphs (e.g. "delete X", "connect Y to Z").
    
    IMPORTANT: 
    1. NEVER use IDs starting with "min_" or "hour_". Those are reserved for the timeline UI.
    2. For Life Tree connections, use labels like "Follows", "Causes", or "Related".
    3. If the input is just an instruction to modify the graph, set newNode to null and use graphMutations.
    
    CONTEXT:
    ---
    LIFE TREE (Chronological): ${lifeNodesContext}
    MIND TWIN NODES: ${mindNodesContext}
    MIND TWIN EDGES: ${mindEdgesContext}
    ---
    NEW LOG OR INSTRUCTION: "${text}"

    JSON SCHEMA:
    {
      "lifeTreeUpdate": {
         ${lifeTreeSchema}
      },
      "mindTwinUpdate": {
         "newNode": { 
            "id": "new_id", 
            "name": "...", 
            "parentId": "id_of_existing_node_OR_new_category_name", 
            "isNewCategory": false,
            "importance": 20-50 
         },
         "graphMutations": {
             "deleteNodes": ["id"],
             "addEdges": [{"sourceId": "id", "targetId": "id", "label": "Relation"}],
             "deleteEdges": [{"sourceId": "id", "targetId": "id"}]
         }
      }
    }
    Set updates or mutations to null if not applicable.
    ONLY RETURN JSON.`;

    try {
        if (source === 'groq') {
            const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${cleanApiKey}`
                },
                body: JSON.stringify({
                    model: "llama-3.3-70b-versatile",
                    messages: [{ role: "user", content: prompt }],
                    response_format: { type: "json_object" }
                })
            });
            const data = await response.json();
            if (!response.ok) {
                throw new Error(data.error?.message || `Groq Error: ${response.status}`);
            }
            if (!data.choices || !data.choices[0]) {
                throw new Error("Invalid response format from Groq (missing choices)");
            }
            return parseLlmJson(data.choices[0].message.content);
        } else {
            // Ollama Local API
            console.log("Calling Local Ollama with model:", model);
            const response = await fetch("http://localhost:11434/v1/chat/completions", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    model: model,
                    messages: [{ role: "user", content: prompt + "\nRespond with JSON only." }],
                    stream: false
                })
            });
            const data = await response.json();
            console.log("Ollama Raw Response:", data);

            if (data.error) {
                throw new Error(`Ollama Error: ${data.error.message || data.error}`);
            }

            if (!data.choices || data.choices.length === 0) {
                // Check if it's the standard Ollama /api/generate format instead
                if (data.message && data.message.content) {
                    return parseLlmJson(data.message.content);
                }
                if (data.response) {
                    return parseLlmJson(data.response);
                }
                throw new Error("Invalid response format from Ollama. Check console.");
            }
            
            return parseLlmJson(data.choices[0].message.content);
        }
    } catch (llmErr) {
        console.warn("LLM API request failed. Triggering client-side rules parser fallback:", llmErr);
        showToast("LLM offline. Running client-side semantic parser fallback.");
        
        const cleanText = text.replace(/['"]/g, '');
        const words = cleanText.split(' ');
        const name = words.slice(0, 3).join(' ') + (words.length > 3 ? "..." : "");
        const id = "node_" + Date.now();
        const type = text.toLowerCase().includes("goal") ? "GOAL" : text.toLowerCase().includes("insight") ? "INSIGHT" : "EVENT";
        const importance = Math.floor(Math.random() * 30) + 30; // 30 to 60
        const color = type === 'GOAL' ? '#bf5af2' : type === 'INSIGHT' ? '#64d2ff' : '#0a84ff';
        
        return {
            lifeTreeUpdate: {
                newNode: {
                    id: id,
                    name: name,
                    type: type,
                    importance: importance,
                    summary: text,
                    color: color
                },
                connections: []
            },
            mindTwinUpdate: {
                newNode: {
                    id: "mind_" + id,
                    name: name,
                    parentId: type === 'GOAL' ? 'plans' : 'activities',
                    importance: importance - 10
                }
            }
        };
    }
}

function getFocusedNodes(text) {
    const keywords = text.toLowerCase().split(/\W+/).filter(w => w.length > 3);
    // Exclude UI elements from LLM context using both type AND ID prefix for safety
    const allNodes = cy.nodes().filter(n => {
        const type = n.data('type');
        const id = n.id();
        return type !== 'MARK' && type !== 'MIN_MARK' && type !== 'CURSOR' && 
               !id.startsWith('min_') && !id.startsWith('hour_');
    });
    
    // 1. Always include the last 3 nodes (temporal context)
    const temporalContext = allNodes.slice(-3).toArray();
    
    // 2. Search for keyword matches in names/summaries
    const keywordMatches = allNodes.filter(node => {
        const content = (node.data('name') + " " + (node.data('summary') || "")).toLowerCase();
        return keywords.some(word => content.includes(word));
    }).toArray();

    // 3. Combine and remove duplicates
    const combined = [...temporalContext, ...keywordMatches];
    const uniqueIds = new Set();
    return combined.filter(node => {
        if (uniqueIds.has(node.id())) return false;
        uniqueIds.add(node.id());
        return true;
    });
}

function parseLlmJson(content) {
    console.log("Parsing LLM Content:", content);
    try {
        return JSON.parse(content);
    } catch (e) {
        // Cleanup in case of markdown blocks or leading/trailing text
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
            return JSON.parse(jsonMatch[0]);
        }
        throw new Error("Failed to parse LLM response as JSON. Raw content: " + content);
    }
}
function addNodeToGraph(extraction, rawText, autoConnect) {
    const newNodeData = extraction.newNode;
    const connections = extraction.connections || [];

    if (newNodeData) {
        const id = newNodeData.id || `node_${Date.now()}`;
        
        // --- Accurate Timeline Positioning ---
        const now = new Date();
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const secondsSinceStart = (now.getTime() - startOfDay) / 1000;
        
        // Scale: 1 hour = 200px
        const x = 100 + (secondsSinceStart / 3600) * 200;
        
        // Y Position based on type/importance to prevent scattering
        // GOALS/INSIGHTS go higher, EVENTS/HABITS stay in middle
        let base_y = 300;
        if (newNodeData.type === 'GOAL' || newNodeData.type === 'INSIGHT') {
            base_y = 150 - (newNodeData.importance || 0);
        } else {
            base_y = 450 + (newNodeData.importance || 0);
        }
        
        // Add jitter/repulsion for Y
        const jitter = (Math.random() * 40 - 20);
        const y = base_y + jitter;

        // Add fallback color if none provided
        const color = newNodeData.color || (newNodeData.type === 'GOAL' ? '#bf5af2' : newNodeData.type === 'MILESTONE' ? '#64d2ff' : '#0a84ff');

        cy.add({
            group: 'nodes',
            data: { ...newNodeData, id, rawText, color, chronoX: x, chronoY: y },
            position: { x, y }
        });

        // Default follow connection (Deduplicated)
        if (autoConnect) {
            const lastNode = cy.nodes().not(`#${id}`).last();
            const hasOutwardConnection = connections.some(c => c.sourceId === id);
            if (!hasOutwardConnection && lastNode.length > 0 && lastNode.id() !== id) {
                addEdge(lastNode.id(), id, 'FOLLOWS');
            }
        }
    }

    // Add all explicit connections (Deduplicated)
    if (autoConnect) {
        connections.forEach(conn => {
            addEdge(conn.sourceId, conn.targetId, conn.label);
        });
    }

    // Process Graph Mutations
    if (extraction.graphMutations) {
        const mut = extraction.graphMutations;
        if (mut.deleteNodes) {
            mut.deleteNodes.forEach(id => { cy.getElementById(id).remove(); });
        }
        if (mut.deleteEdges) {
            mut.deleteEdges.forEach(e => {
                cy.edges(`[source = "${e.sourceId}"][target = "${e.targetId}"]`).remove();
                cy.edges(`[source = "${e.targetId}"][target = "${e.sourceId}"]`).remove();
            });
        }
        if (mut.addEdges) {
            mut.addEdges.forEach(e => addEdge(e.sourceId, e.targetId, e.label));
        }
    }

    drawTimeline();
    cy.fit();
    saveGraph();
    
    // Update index.md with significant events
    if (newNodeData && (newNodeData.importance || 0) >= 60) {
        indexMd += `\n- [${new Date().toLocaleDateString()}] ${newNodeData.name}: ${newNodeData.summary || rawText}`;
        localStorage.setItem('indexMd', indexMd);
    }
}

function addEdge(source, target, label) {
    const sourceExists = cy.getElementById(source).length > 0;
    const targetExists = cy.getElementById(target).length > 0;
    
    if (sourceExists && targetExists) {
        // Prevent repeated edges
        const existing = cy.edges(`[source = "${source}"][target = "${target}"]`);
        if (existing.length === 0) {
            cy.add({
                group: 'edges',
                data: { source, target, label }
            });
        }
    }
}

function drawTimeline() {
    // Clear any residual node-based markers
    cy.nodes('[type = "MARK"], [type = "MIN_MARK"]').remove();
    
    // Trigger the new HTML header render
    renderTimelineHeader();
    updateCurrentTimeBar();
}

function updateCurrentTimeBar() {
    // CSS overlay approach — infinite top-to-bottom span, not clipped by Cytoscape canvas
    let bar = document.getElementById('nowBarOverlay');
    if (!bar) {
        bar = document.createElement('div');
        bar.id = 'nowBarOverlay';
        bar.style.cssText = 'position:absolute;top:60px;bottom:0;width:1px;background:rgba(255,255,255,0.65);z-index:500;pointer-events:none;';
        const lbl = document.createElement('div');
        lbl.style.cssText = 'position:absolute;top:5px;left:3px;background:rgba(255,255,255,0.15);color:#fff;font-size:8px;font-weight:bold;padding:2px 4px;border-radius:3px;white-space:nowrap;';
        lbl.innerText = 'NOW';
        bar.appendChild(lbl);
        cyContainer.style.position = 'relative';
        cyContainer.appendChild(bar);
    }
    const pan = cy.pan();
    const zoom = cy.zoom();
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const secondsSinceStart = (now.getTime() - startOfDay) / 1000;
    const graphX = 100 + (secondsSinceStart / 3600) * 200;
    const screenX = (graphX * zoom) + pan.x;
    bar.style.left = screenX + 'px';
    // Clean up any old Cytoscape node version
    cy.remove('.current-time-bar');
}

function saveGraph() {
    const data = cy.json().elements;
    localStorage.setItem('graphData', JSON.stringify(data));
}

function updateContextDisplay() {
    lifeCanvasEl.innerText = lifeCanvasMd;
    recentHistoryEl.innerText = recentHistoryMd;
}

// --- Event Listeners ---
let askModeActive = false;
ingestBtn.addEventListener('click', () => {
    const q = document.getElementById('logInput').value.trim();
    if (!q) return;
    if (askModeActive) {
        askLifeCanvas(q);
    } else {
        ingestLog();
    }
});

document.getElementById('zoomIn').addEventListener('click', () => {
    cy.animate({ zoom: cy.zoom() * 1.2, duration: 200 });
});
document.getElementById('zoomOut').addEventListener('click', () => {
    cy.animate({ zoom: cy.zoom() * 0.8, duration: 200 });
});
document.getElementById('resetView').addEventListener('click', () => {
    cy.animate({ fit: { padding: 50 }, duration: 400 });
});

cy.on('tap', 'node', function(evt){
    const node = evt.target;
    if (node.data('type') === 'MARK' || node.data('type') === 'MIN_MARK' || node.data('type') === 'CURSOR') return;
    document.getElementById('nodeTitle').innerText = node.data('name');
    document.getElementById('nodeData').innerHTML = `
        <p><strong>Type:</strong> ${node.data('type')}</p>
        <p><strong>Importance:</strong> ${node.data('importance')}</p>
        <p><strong>Summary:</strong> ${node.data('summary') || '—'}</p>
        <p><strong>Raw Log:</strong></p>
        <pre>${node.data('rawText') || 'Initial Node'}</pre>
        <p><strong>JSON:</strong></p>
        <pre>${JSON.stringify(node.data(), null, 2)}</pre>
    `;
    document.getElementById('detailModal').classList.add('open');
});

// Smooth scroll-wheel zoom
cyContainer.addEventListener('wheel', (e) => {
    e.preventDefault();
    const factor = e.deltaY < 0 ? 1.12 : 0.89;
    const newZoom = Math.min(Math.max(cy.zoom() * factor, 0.0005), 20);
    cy.animate({ zoom: { level: newZoom, renderedPosition: { x: e.offsetX, y: e.offsetY } }, duration: 180, easing: 'ease-out' });
}, { passive: false });

// Viewport Event for dynamic UI elements
cy.on('viewport', () => {
    const z = cy.zoom();
    const sizeMultiplier = 1 / Math.sqrt(z);
    cy.style()
      .selector('node[type != "MARK"][type != "MIN_MARK"][type != "CURSOR"]')
      .style({
          'width': `mapData(importance, 0, 100, 0, ${100 * sizeMultiplier})`,
          'height': `mapData(importance, 0, 100, 0, ${100 * sizeMultiplier})`
      })
      .update();
    renderTimelineHeader();
    updateCurrentTimeBar();
    renderGanttChart(); // keep Gantt in sync with pan/zoom
});


function renderTimelineHeader() {
    if (!timelineHeaderEl || timelineHeaderEl.style.display === 'none') return;
    timelineHeaderEl.innerHTML = '';
    
    const pan = cy.pan();
    const zoom = cy.zoom();
    const width = timelineHeaderEl.clientWidth;
    const dateStr = viewDateEl.value;
    const baseDate = new Date(dateStr + 'T00:00:00');
    const startOfTodayMs = baseDate.getTime();

    // Helper: Convert screen pixel to timestamp
    function screenXToMs(x) {
        const graphX = (x - pan.x) / zoom;
        const hoursOffset = (graphX - 100) / 200;
        return startOfTodayMs + (hoursOffset * 3600 * 1000);
    }

    // Helper: Convert timestamp to screen pixel
    function msToScreenX(ms) {
        const hoursOffset = (ms - startOfTodayMs) / (3600 * 1000);
        const graphX = 100 + (hoursOffset * 200);
        return (graphX * zoom) + pan.x;
    }

    // Determine zoom tier and step size
    let mode = 'HOUR';
    let stepMs = 3600 * 1000; // 1 hour
    
    if (zoom > 4.0) { mode = 'MINUTE'; stepMs = 5 * 60 * 1000; }
    else if (zoom > 1.5) { mode = '15MIN'; stepMs = 15 * 60 * 1000; }
    else if (zoom > 0.6) { mode = 'HOUR'; stepMs = 3600 * 1000; }
    else if (zoom > 0.2) { mode = '3HOUR'; stepMs = 3 * 3600 * 1000; }
    else if (zoom > 0.1) { mode = '6HOUR'; stepMs = 6 * 3600 * 1000; }
    else if (zoom > 0.05) { mode = '12HOUR'; stepMs = 12 * 3600 * 1000; }
    else if (zoom > 0.015) { mode = 'DAY'; stepMs = 24 * 3600 * 1000; }
    else if (zoom > 0.004) { mode = 'WEEK'; stepMs = 7 * 24 * 3600 * 1000; }
    else if (zoom > 0.001) { mode = 'MONTH'; stepMs = 30 * 24 * 3600 * 1000; }
    else { mode = 'YEAR'; stepMs = 365 * 24 * 3600 * 1000; }

    // Calculate visible time range
    const startTime = screenXToMs(-200);
    const endTime = screenXToMs(width + 200);

    // Round startTime to nearest step
    let currentTime = Math.floor(startTime / stepMs) * stepMs;
    let current = new Date(currentTime);

    while (current.getTime() <= endTime) {
        const x = msToScreenX(current.getTime());
        
        // Draw Tick
        const tick = document.createElement('div');
        tick.className = 'timeline-tick hour';
        tick.style.left = `${x}px`;
        timelineHeaderEl.appendChild(tick);

        // Draw Label
        const label = document.createElement('div');
        label.className = 'timeline-label';
        label.style.left = `${x}px`;
        
        if (mode === 'MINUTE' || mode === '15MIN') label.innerText = `${current.getHours()}:${current.getMinutes().toString().padStart(2, '0')}`;
        else if (mode === 'HOUR' || mode === '3HOUR' || mode === '6HOUR' || mode === '12HOUR') label.innerText = `${current.getHours()}:00`;
        else if (mode === 'DAY') label.innerText = current.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric' });
        else if (mode === 'WEEK') label.innerText = `Week ${Math.ceil(current.getDate() / 7)} (${current.toLocaleDateString('en-US', { month: 'short' })})`;
        else if (mode === 'MONTH') label.innerText = current.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });
        else if (mode === 'YEAR') label.innerText = current.getFullYear();

        timelineHeaderEl.appendChild(label);
        
        // Increment
        if (mode === 'MONTH') current.setMonth(current.getMonth() + 1);
        else if (mode === 'YEAR') current.setFullYear(current.getFullYear() + 1);
        else current.setTime(current.getTime() + stepMs);
    }
}

document.getElementById('closeDetailModal').onclick = () => document.getElementById('detailModal').classList.remove('open');
window.addEventListener('click', e => {
    if (e.target === document.getElementById('detailModal')) document.getElementById('detailModal').classList.remove('open');
    if (e.target === document.getElementById('summarizeModal')) document.getElementById('summarizeModal').classList.remove('open');
    if (e.target === document.getElementById('tidyModal')) document.getElementById('tidyModal').classList.remove('open');
});
document.getElementById('resetMindView').addEventListener('click', () => {
    cyMind.animate({ fit: { padding: 50 }, duration: 400 });
});
// --- Tidy Mind Logic ---
const tidyModal = document.getElementById('tidyModal');
const tidyMindBtn = document.getElementById('tidyMindBtn');
const tidyList = document.getElementById('tidyList');
const applyTidyBtn = document.getElementById('applyTidyBtn');
const closeTidy = document.getElementById('closeTidy');

tidyMindBtn.addEventListener('click', () => {
    renderTidyList();
    document.getElementById('tidyModal').classList.add('open');
});

document.getElementById('closeTidy').onclick = () => document.getElementById('tidyModal').classList.remove('open');

// --- Mind Twin Manual Editing ---
document.getElementById('addMindEvent').addEventListener('click', () => {
    const name = prompt("Enter Event/Item Name:");
    if (name) {
        const id = `manual_${Date.now()}`;
        cyMind.add({
            group: 'nodes',
            data: { id, name, type: 'EVENT', importance: 40 }
        });
        saveDayData();
    }
});

document.getElementById('addMindCat').addEventListener('click', () => {
    const name = prompt("Enter Category Name:");
    if (name) {
        const id = `cat_${Date.now()}`;
        cyMind.add({
            group: 'nodes',
            data: { id, name, type: 'CATEGORY', importance: 50 }
        });
        saveDayData();
    }
});

document.getElementById('groupNodesBtn').addEventListener('click', () => {
    const selected = cyMind.nodes(':selected');
    if (selected.length < 2) {
        showToast("Select multiple nodes to group them!");
        return;
    }
    const name = prompt("Enter Holder Blob Name:");
    if (name) {
        const parentId = `holder_${Date.now()}`;
        cyMind.add({
            group: 'nodes',
            data: { id: parentId, name, type: 'HOLDER' }
        });
        selected.move({ parent: parentId });
        saveDayData();
    }
});

document.getElementById('deleteMindNodes').addEventListener('click', () => {
    const selected = cyMind.elements(':selected');
    if (selected.length > 0) {
        cyMind.remove(selected);
        saveDayData();
    }
});

// Click-to-Connect Logic (no shift required — click node once to select, again to connect)
let connectionSource = null;
cyMind.on('tap', 'node', (evt) => {
    const node = evt.target;
    if (!connectionSource) {
        // First tap — set as source, highlight
        connectionSource = node;
        node.style({ 'border-color': '#ff0', 'border-width': 3 });
        document.getElementById('connectHint').classList.add('visible');
    } else {
        if (connectionSource.id() === node.id()) {
            // Tapped same node — cancel
            connectionSource.style({ 'border-width': 0 });
            connectionSource = null;
            document.getElementById('connectHint').classList.remove('visible');
            return;
        }
        // Check if edge already exists between these two
        const existingFwd = cyMind.edges(`[source = "${connectionSource.id()}"][target = "${node.id()}"]`);
        const existingBwd = cyMind.edges(`[source = "${node.id()}"][target = "${connectionSource.id()}"]`);
        const existing = existingFwd.union(existingBwd);
        if (existing.length > 0) {
            // Toggle OFF — remove edge
            cyMind.remove(existing);
        } else {
            // Toggle ON — ask directed or undirected
            const directed = confirm('Create directed arrow? (Cancel = undirected line)');
            cyMind.add({
                group: 'edges',
                data: { source: connectionSource.id(), target: node.id(), directed: directed ? 'true' : 'false' }
            });
        }
        connectionSource.style({ 'border-width': 0 });
        connectionSource = null;
        document.getElementById('connectHint').classList.remove('visible');
        saveDayData();
    }
});

// Tap background — cancel connection
cyMind.on('tap', (evt) => {
    if (evt.target === cyMind && connectionSource) {
        connectionSource.style({ 'border-width': 0 });
        connectionSource = null;
        document.getElementById('connectHint').classList.remove('visible');
    }
});

function renderTidyList() {
    tidyList.innerHTML = '';
    
    // Get all category nodes
    const categories = cyMind.nodes('[type = "CATEGORY"]');
    
    categories.forEach(cat => {
        // Add category header
        const catDiv = document.createElement('div');
        catDiv.className = 'tidy-item category';
        catDiv.innerHTML = `<input type="checkbox" checked data-id="${cat.id()}"> ${cat.data('name')}`;
        tidyList.appendChild(catDiv);
        
        // Find children
        const children = cat.outgoers('node');
        children.forEach(child => {
            const childDiv = document.createElement('div');
            childDiv.className = 'tidy-item leaf';
            childDiv.innerHTML = `<input type="checkbox" checked data-id="${child.id()}"> ${child.data('name')}`;
            tidyList.appendChild(childDiv);
        });
    });
}

applyTidyBtn.addEventListener('click', () => {
    const checkboxes = tidyList.querySelectorAll('input[type="checkbox"]');
    const toRemove = [];
    
    checkboxes.forEach(cb => {
        if (!cb.checked) {
            toRemove.push(cb.getAttribute('data-id'));
        }
    });
    
    if (toRemove.length > 0) {
        cyMind.remove(cyMind.nodes().filter(n => toRemove.includes(n.id())));
        saveDayData();
        startMindPhysics();
    }
    document.getElementById('tidyModal').classList.remove('open');
});
// --- Mind Twin To-Do Revamp Logic ---
const todoItemsContainer = document.getElementById('todoItemsContainer');
const addTodoLineBtn = document.getElementById('addTodoLineBtn');
const processTodosBtn = document.getElementById('processTodosBtn');

addTodoLineBtn.addEventListener('click', () => {
    const div = document.createElement('div');
    div.className = 'todo-line';
    div.innerHTML = '<input type="text" placeholder="Something to map...">';
    todoItemsContainer.appendChild(div);
    div.querySelector('input').focus();
});

processTodosBtn.addEventListener('click', async () => {
    const inputs = todoItemsContainer.querySelectorAll('input');
    const todos = Array.from(inputs).map(i => i.value.trim()).filter(v => v !== '');
    
    if (todos.length === 0) return;
    
    processTodosBtn.disabled = true;
    processTodosBtn.innerText = "THINKING...";
    
    try {
        const source = llmSourceEl.value;
        const apiKey = apiKeyEl.value.trim();
        const model = ollamaModelEl.value.trim();
        
        const prompt = `
        TASK: Organise this messy list into a Mind Twin Knowledge Graph.
        LIST: ${todos.join(', ')}
        
        CONTEXT (Existing): ${cyMind.nodes().map(n => n.data('name')).join(', ')}
        
        JSON SCHEMA:
        {
          "updates": [
            { "id": "new_id", "name": "Item Name", "parentId": "existing_id_or_new_category", "importance": 20-50 }
          ]
        }
        ONLY RETURN JSON.`;

        const response = await fetchLlm(prompt, source, apiKey, model);
        const data = parseLlmJson(response);
        
        if (data.updates) {
            data.updates.forEach(update => {
                updateMindTwin({ newNode: update });
            });
            startMindPhysics(); // Reintegrate new nodes into live physics
            todoItemsContainer.innerHTML = '<div class="todo-line"><input type="text" placeholder="Something to map..."></div>';
        }
    } catch (e) {
        console.error("Todo Processing failed:", e);
        showToast("AI Mapping failed. Check console.");
    } finally {
        processTodosBtn.disabled = false;
        processTodosBtn.innerText = "MIND-MAP WITH AI";
    }
});

// ==============================================================
// ===== MOCK GANTT DATA (App Usage — mirrors Flutter model) =====
// ==============================================================
const GANTT_ROWS = ['Screen', 'Messages', 'Chrome', 'Instagram', 'YouTube', 'WhatsApp', 'Spotify'];
const MOCK_GANTT = [
    { app: 'Screen',    startH: 8.0,  endH: 9.5,  color: '#64ffda', isScreen: true },
    { app: 'Screen',    startH: 9.7,  endH: 11.0, color: '#64ffda', isScreen: true },
    { app: 'Screen',    startH: 11.3, endH: 13.0, color: '#64ffda', isScreen: true },
    { app: 'Screen',    startH: 13.3, endH: 15.0, color: '#64ffda', isScreen: true },
    { app: 'Screen',    startH: 15.3, endH: 17.0, color: '#64ffda', isScreen: true },
    { app: 'Screen',    startH: 17.3, endH: 19.0, color: '#64ffda', isScreen: true },
    { app: 'Screen',    startH: 19.3, endH: 22.0, color: '#64ffda', isScreen: true },
    { app: 'Messages',  startH: 8.0,  endH: 8.4,  color: '#4ADE80' },
    { app: 'Chrome',    startH: 8.4,  endH: 9.5,  color: '#60A5FA' },
    { app: 'WhatsApp',  startH: 9.7,  endH: 10.2, color: '#64B5F6' },
    { app: 'Instagram', startH: 10.2, endH: 11.0, color: '#A78BFA' },
    { app: 'Chrome',    startH: 11.3, endH: 12.3, color: '#60A5FA' },
    { app: 'YouTube',   startH: 12.3, endH: 13.0, color: '#E57373' },
    { app: 'Spotify',   startH: 13.3, endH: 14.0, color: '#81C784' },
    { app: 'Messages',  startH: 16.0, endH: 17.0, color: '#4ADE80' },
    { app: 'Instagram', startH: 17.3, endH: 18.2, color: '#A78BFA' },
    { app: 'YouTube',   startH: 18.2, endH: 19.0, color: '#E57373' },
    { app: 'WhatsApp',  startH: 19.3, endH: 20.0, color: '#64B5F6' },
    { app: 'Chrome',    startH: 20.0, endH: 21.0, color: '#60A5FA' },
    { app: 'Spotify',   startH: 21.0, endH: 22.0, color: '#81C784' },
];

let phantomGanttBars = [];
const GANTT_ROW_H = 14;
const GANTT_LABEL_W = 56;

function timeToScreenX(h) {
    // Must match updateCurrentTimeBar formula: graphX = 100 + h * 200
    const graphX = 100 + h * 200;
    return graphX * cy.zoom() + cy.pan().x;
}

function renderGanttChart() {
    const canvas = document.getElementById('ganttCanvas');
    if (!canvas || !cyContainer.classList.contains('active')) return;

    // Resize canvas pixel buffer to match CSS size
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;

    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Row label background
    ctx.fillStyle = 'rgba(2,4,18,0.85)';
    ctx.fillRect(0, 0, GANTT_LABEL_W, canvas.height);

    GANTT_ROWS.forEach((row, i) => {
        const y = i * (GANTT_ROW_H + 2) + 6;

        // Row label
        ctx.fillStyle = 'rgba(255,255,255,0.28)';
        ctx.font = '7px system-ui, sans-serif';
        ctx.fillText(row, 4, y + GANTT_ROW_H - 3);

        // Alternating row bg
        if (i % 2 === 0) {
            ctx.fillStyle = 'rgba(255,255,255,0.015)';
            ctx.fillRect(GANTT_LABEL_W, y, canvas.width - GANTT_LABEL_W, GANTT_ROW_H);
        }
    });

    // Draw real activity bars
    MOCK_GANTT.forEach(act => {
        const rowIdx = GANTT_ROWS.indexOf(act.app);
        if (rowIdx < 0) return;
        const x1 = Math.max(timeToScreenX(act.startH), GANTT_LABEL_W);
        const x2 = timeToScreenX(act.endH);
        const w = x2 - x1;
        if (w < 1) return;
        const y = rowIdx * (GANTT_ROW_H + 2) + 6;

        ctx.fillStyle = act.isScreen ? 'rgba(100,255,218,0.35)' : act.color + 'bb';
        ctx.beginPath();
        ctx.roundRect(x1, y + 1, Math.max(w, 2), GANTT_ROW_H - 2, 3);
        ctx.fill();
    });

    // Draw phantom (predicted) bars as dashed outlines
    phantomGanttBars.forEach(bar => {
        const rowIdx = GANTT_ROWS.indexOf(bar.app);
        if (rowIdx < 0) return;
        const x1 = Math.max(timeToScreenX(bar.startH), GANTT_LABEL_W);
        const x2 = timeToScreenX(bar.endH);
        const w = x2 - x1;
        if (w < 1) return;
        const y = rowIdx * (GANTT_ROW_H + 2) + 6;
        ctx.setLineDash([4, 3]);
        ctx.strokeStyle = (bar.color || '#bf5af2') + 'aa';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.roundRect(x1, y + 1, Math.max(w, 2), GANTT_ROW_H - 2, 3);
        ctx.stroke();
        ctx.setLineDash([]);
    });

    // Draw NOW line on Gantt
    const nowH = (() => { const n = new Date(); return n.getHours() + n.getMinutes() / 60 + n.getSeconds() / 3600; })();
    const nowX = timeToScreenX(nowH);
    if (nowX > GANTT_LABEL_W && nowX < canvas.width) {
        ctx.strokeStyle = 'rgba(255,255,255,0.55)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(nowX, 0);
        ctx.lineTo(nowX, canvas.height);
        ctx.stroke();
    }
}

// Initial render + phantom cleanup loop
setTimeout(renderGanttChart, 700);
setInterval(() => {
    const nowH = (() => { const n = new Date(); return n.getHours() + n.getMinutes() / 60; })();
    // Remove phantom Life Tree nodes whose time has passed
    cy.nodes('.phantom').forEach(n => {
        const pTime = n.data('phantomTs');
        if (pTime && Date.now() > pTime) cy.remove(n);
    });
    // Remove phantom Gantt bars whose end time has passed
    phantomGanttBars = phantomGanttBars.filter(b => b.endH > nowH);
    renderGanttChart();
}, 15000);

// ==============================================================
// ===== TOAST NOTIFICATION =====
// ==============================================================
let toastTimeout = null;
function showToast(text, durationMs = 6000) {
    const toast = document.getElementById('lcToast');
    if (!toast) return;
    clearTimeout(toastTimeout);
    toast.innerText = text;
    toast.classList.add('visible');
    toastTimeout = setTimeout(() => toast.classList.remove('visible'), durationMs);
}
document.getElementById('lcToast').addEventListener('click', () => {
    document.getElementById('lcToast').classList.remove('visible');
});

// ==============================================================
// ===== ASK LIFECANVAS MODE =====
// ==============================================================
document.getElementById('askToggle').addEventListener('click', () => {
    askModeActive = !askModeActive;
    const btn = document.getElementById('askToggle');
    const ta = document.getElementById('logInput');
    if (askModeActive) {
        btn.classList.add('active');
        btn.innerText = '🔮 ASK';
        document.getElementById('ingestBtn').innerText = 'ASK →';
        ta.placeholder = 'Ask LifeCanvas anything... (Life Tree, Gantt, Mind Twin, all notes in context)';
    } else {
        btn.classList.remove('active');
        btn.innerText = '🔮 ASK';
        document.getElementById('ingestBtn').innerText = 'INGEST LOG';
        ta.placeholder = "What happened today? (e.g. 'Started the Pulse project')";
    }
});

async function askLifeCanvas(query) {
    const apiKey = apiKeyEl.value.trim();
    if (!apiKey) { showToast('❌ Need Groq API Key to use Ask LifeCanvas.', 4000); return; }

    showToast('🔮 LifeCanvas is thinking...', 4000);

    const now = new Date();
    const lifeCtx = cy.nodes()
        .filter(n => !n.hasClass('phantom') && n.data('type') !== 'MARK' && n.data('type') !== 'START' && n.data('type') !== 'MIN_MARK')
        .map(n => `[${n.data('type')}] "${n.data('name')}": ${n.data('summary') || ''}`)
        .join('\n');

    const mindCtx = cyMind.nodes().map(n => n.data('name')).filter(Boolean).join(', ');

    const nowH = now.getHours() + now.getMinutes() / 60;
    const appUsageCtx = MOCK_GANTT
        .filter(g => !g.isScreen && g.startH <= nowH)
        .map(g => `${g.app}(${g.startH.toFixed(1)}-${g.endH.toFixed(1)}h)`)
        .join(', ');

    const prompt = `You are LifeCanvas AI, a personal life intelligence assistant.
Answer the user's question concisely (2-5 sentences) using only the context below. Speak in second person ("you did...", "based on your...").

CURRENT TIME: ${now.toLocaleString()}
LIFE TREE (events/goals): ${lifeCtx.slice(0, 700)}
MIND TWIN (concepts): ${mindCtx}
APP USAGE TODAY: ${appUsageCtx}
LIFECYCLE NOTES: ${lifeCanvasMd.slice(0, 500)}
RECENT LOGS: ${recentHistoryMd.slice(0, 400)}

QUESTION: ${query}`;

    try {
        const answer = await fetchLlm(prompt, apiKeyEl ? 'groq' : 'ollama', apiKey, document.getElementById('ollamaModel')?.value || '');
        showToast(answer.trim().slice(0, 500), 10000);
    } catch (e) {
        showToast('❌ Ask failed: ' + e.message, 4000);
    }
}

// ==============================================================
// ===== PREDICT TIMELINE =====
// ==============================================================
document.getElementById('predictBtn').addEventListener('click', predictTimeline);

async function predictTimeline() {
    const apiKey = apiKeyEl.value.trim();
    if (!apiKey) { showToast('❌ Need Groq API Key to predict.', 4000); return; }

    const btn = document.getElementById('predictBtn');
    btn.disabled = true;
    btn.innerText = '⟳';
    showToast('🔮 Predicting your future timeline...', 4000);

    // Clear old phantoms
    cy.remove('.phantom');
    phantomGanttBars = [];

    const now = new Date();
    const nowH = now.getHours() + now.getMinutes() / 60;

    const lifeCtx = cy.nodes()
        .filter(n => !n.hasClass('phantom') && n.data('type') !== 'MARK' && n.data('type') !== 'START')
        .map(n => `${n.data('name')} (${n.data('type')})`)
        .join(', ');

    const prompt = `You are a life prediction AI. Based on the user's data, predict the NEXT 4-6 likely events for today.
Current time: ${now.toLocaleTimeString()} (${nowH.toFixed(2)} hours into the day)
Life Tree: ${lifeCtx.slice(0, 400)}
Mind Twin: ${cyMind.nodes().map(n=>n.data('name')).join(', ')}
Notes: ${lifeCanvasMd.slice(0,300)}
Recent: ${recentHistoryMd.slice(0,200)}

Output ONLY valid JSON — no markdown, no explanation:
{"predictions":[{"name":"...","hoursFromNow":1.5,"durationHours":0.5,"type":"HABIT","color":"#hex","ganttApp":"Chrome"}]}
Rules: hoursFromNow > 0 and < 12. type = GOAL|EVENT|HABIT|INSIGHT. ganttApp must be one of: Screen,Messages,Chrome,Instagram,YouTube,WhatsApp,Spotify (or omit).`;

    try {
        const raw = await fetchLlm(prompt, 'groq', apiKey, '');
        const parsed = parseLlmJson(raw);

        const preds = parsed?.predictions || [];
        if (!preds.length) { showToast('🤔 No predictions generated. Try adding more logs first.', 5000); return; }

        preds.forEach(pred => {
            const futureH = nowH + (pred.hoursFromNow || 1);
            const graphX = 100 + futureH * 200;
            const graphY = 200 + (Math.random() * 120 - 60);
            const id = `phantom_${Date.now()}_${Math.random().toString(36).slice(2,6)}`;
            const color = pred.color || '#bf5af2';

            cy.add({
                group: 'nodes',
                classes: 'phantom',
                data: {
                    id, name: pred.name,
                    type: pred.type || 'EVENT',
                    importance: 30,
                    color,
                    phantomTs: Date.now() + pred.hoursFromNow * 3600000,
                    chronoX: graphX,
                    chronoY: graphY
                },
                position: { x: graphX, y: graphY }
            });

            // Add Gantt phantom bar
            if (pred.ganttApp && GANTT_ROWS.includes(pred.ganttApp)) {
                phantomGanttBars.push({
                    app: pred.ganttApp,
                    startH: futureH,
                    endH: futureH + (pred.durationHours || 0.5),
                    color
                });
            }
        });

        renderGanttChart();
        showToast(`🔮 ${preds.length} future events predicted! Dotted nodes show on the timeline. They vanish as NOW sweeps past.`, 7000);
    } catch (e) {
        showToast('❌ Prediction failed: ' + e.message, 4000);
    } finally {
        btn.disabled = false;
        btn.innerText = '🔮 PREDICT';
    }
}

async function fetchLlm(prompt, source, apiKey, model) {
    let cleanApiKey = apiKey.trim();
    if (cleanApiKey.includes('=')) {
        cleanApiKey = cleanApiKey.split('=')[1].replace(/['"]/g, '').trim();
    }

    if (source === 'groq') {
        const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json", "Authorization": `Bearer ${cleanApiKey}` },
            body: JSON.stringify({
                model: "llama-3.3-70b-versatile",
                messages: [{ role: "user", content: prompt }]
            })
        });
        const data = await response.json();
        if (!response.ok) {
            throw new Error(data.error?.message || `Groq Error: ${response.status}`);
        }
        if (!data.choices || !data.choices[0]) {
            throw new Error("Invalid response format from Groq (missing choices)");
        }
        return data.choices[0].message.content;
    } else {
        const response = await fetch("http://localhost:11434/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model, messages: [{ role: "user", content: prompt }] })
        });
        const data = await response.json();
        if (!response.ok) {
            throw new Error(data.error?.message || `Ollama Error: ${response.status}`);
        }
        if (!data.choices || !data.choices[0]) {
            throw new Error("Invalid response format from Ollama (missing choices)");
        }
        return data.choices[0].message.content;
    }
}
