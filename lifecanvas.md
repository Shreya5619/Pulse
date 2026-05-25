# LifeCanvas — Master Blueprint

## Core Vision

LifeCanvas is not a journaling app.

It is:

```text
An AI-powered evolving cognitive map of a human life.
```

The system continuously:

* listens to life logs
* understands meaning
* retrieves related memories
* reasons about emotional/contextual relationships
* restructures a living memory graph over time

The result is:

```text
A neural-network-like visualization of identity, growth, relationships, habits, emotional cycles, and life progression.
```

---

# Core Philosophy

Traditional journaling:

```text
Linear storage of memories
```

LifeCanvas:

```text
Dynamic semantic memory network
```

The app should feel like:

* a second brain
* a life graph
* a cognitive mirror
* a memory galaxy
* an evolving neural system

NOT:

* notes app
* diary
* timeline app

---

# Fundamental Architecture

## Core Flow

```text
Voice/Text Input
        ↓
Transcription Layer
        ↓
Embedding + Indexing
        ↓
Context Retrieval Engine
        ↓
LLM Reasoning Loop
        ↓
Graph Operations Engine
        ↓
Life Graph Update
        ↓
Visualization Engine
```

---

# Memory Model

## Nodes = Life Events

Every memory becomes a structured node.

Example:

```json
{
  "id": "event_203",
  "timestamp": "2026-05-20",
  "title": "Started AI appliance vision",
  "summary": "Realized infrastructure platform direction",
  "emotion": "excited",
  "themes": [
    "AI",
    "systems",
    "Linux",
    "ambition"
  ],
  "people": [
    "mentor"
  ],
  "importance": 0.87,
  "embedding": [...]
}
```

---

# Relationship Model

## Edges = Meaningful Connections

Connections are NOT only chronological.

Possible edge types:

```text
caused_by
inspired_by
emotionally_related
identity_shift
habit_cycle
career_progression
relationship_influence
trauma_link
goal_alignment
creative_pattern
```

Example:

```json
{
  "source": "event_14",
  "target": "event_203",
  "relation": "career_inspiration",
  "strength": 0.84
}
```

---

# AI Reasoning System

## Core Insight

LifeCanvas uses the SAME orchestration pattern as autonomous AI agents.

```text
observe
→ retrieve context
→ reason
→ decide operations
→ update world state
```

The graph itself becomes:

```text
the evolving memory state
```

---

# LLM Orchestration Loop

## Input Example

Voice note:

```text
"I realized my obsession with Linux and infrastructure started when I first used Ubuntu in school."
```

## Agentic Reasoning Loop

### 1. Retrieve Context

System retrieves:

* school memories
* Linux-related logs
* career ambition events
* related emotional clusters

### 2. Reason

LLM infers:

* causal identity relationship
* long-term passion emergence
* thematic continuity

### 3. Generate Operations

Example:

```json
{
  "operation": "connect",
  "source": "school_linux_event",
  "target": "infrastructure_project_event",
  "reason": "origin_of_technical_identity",
  "confidence": 0.89
}
```

### 4. Apply Graph Mutations

The orchestration engine validates:

* duplication
* confidence
* graph consistency

Then updates Neo4j graph.

---

# CRITICAL DESIGN RULE

## LLM NEVER Directly Controls Graph

Bad:

```text
LLM directly edits graph database
```

Correct:

```text
LLM proposes operations
→ orchestration layer validates
→ graph updates occur
```

This prevents:

* hallucinated connections
* graph corruption
* semantic drift

---

# Retrieval Architecture

This is the MOST important system.

## Hybrid Memory Retrieval

### 1. Vector Retrieval

Semantic similarity.

Example:

```text
"feeling isolated"
```

retrieves:

```text
"felt disconnected from everyone"
```

even if wording differs.

Use:

* embeddings
* cosine similarity

---

### 2. Temporal Retrieval

Retrieves nearby events in time.

Example:

```text
events around major breakup
events before startup launch
```

---

### 3. Graph Traversal Retrieval

Neo4j semantic querying.

Example:

```cypher
Find all events connected to:
- creativity
- loneliness
- career shifts
```

---

# Multi-Layer Memory Hierarchy

Human memory is hierarchical.

LifeCanvas should evolve toward:

```text
Raw Logs
    ↓
Events
    ↓
Themes
    ↓
Identity Arcs
    ↓
Life Epochs
```

Example:

```text
"School Era"
    ├── Linux discovery
    ├── isolation
    ├── first coding project
    └── ambition emergence
```

---

# Visualization System

## Option 1 — Temporal Neural River

Left-to-right evolving timeline.

```text
past ------------------> present
```

Features:

* major events become large nodes
* related memories branch outward
* recurring themes create clusters
* emotional intensity changes glow/color

Best for:

* progression
* causality
* life evolution

---

# SPECIAL IDEA — Galaxy Neural Network

This is potentially the signature visual identity.

## Structure

```text
Center = core self/identity

Orbiting systems:
- family
- career
- relationships
- creativity
- fears
- ambitions
- obsessions
```

Important memories:

```text
stars
```

Minor recurring memories:

```text
particles/satellites
```

Connections:

```text
gravitational lines
```

Clusters slowly:

* orbit
* evolve
* reshape over time

The graph becomes:

```text
a living memory universe
```

---

# Emotional & Identity Intelligence

## Emergent Pattern Detection

Periodic reflection loops.

The AI periodically reasons over the ENTIRE graph.

Examples:

```text
"You tend to start ambitious projects after isolation periods."

"Your confidence spikes correlate strongly with creative output."

"Most major life shifts followed periods of uncertainty."
```

This transforms LifeCanvas into:

```text
an introspective cognitive mirror
```

---

# Voice Intelligence Layer

## Voice Journaling

Pipeline:

```text
Voice Note
→ Whisper transcription
→ semantic extraction
→ emotional analysis
→ graph reasoning
→ graph update
```

Voice is critical because:

* more natural
* emotionally authentic
* faster than typing
* captures raw cognition

---

# Recommended Tech Stack

## Frontend

```text
React
Cytoscape.js
react-force-graph
Framer Motion
Three.js (later)
```

---

## Backend

```text
Node.js
Express/Fastify
Python microservices optional
```

---

## Databases

### Neo4j

Primary memory graph engine.

Stores:

* nodes
* relationships
* semantic structure

### MongoDB

Stores:

* raw logs
* voice transcripts
* metadata
* snapshots

---

## AI Layer

### LLMs

* Ollama local models
* cloud fallback

### Embeddings

* nomic-embed
* bge-small
* e5-small

### Voice

* Whisper
* faster-whisper

---

# Long-Term Evolution

## Phase 1

Basic journaling + graph

## Phase 2

Semantic retrieval + AI connections

## Phase 3

Identity arcs + pattern detection

## Phase 4

Galaxy visualization engine

## Phase 5

Autonomous reflection system

## Phase 6

Full cognitive operating system

---

# Final Core Identity

LifeCanvas is:

```text
A continuously evolving semantic map of human existence.
```

Not merely:

* memory storage
* journaling
* productivity

But:

```text
A living neural representation of a person’s evolving identity, memories, relationships, and internal universe.
```