## Context Agent

**Purpose**  
Builds a coherent, short-horizon world state from noisy raw inputs so downstream agents reason on a clean, structured snapshot instead of ad‑hoc values.

**Inputs**  
- Raw device signals: battery %, charging state, screen state, network type.  
- Time + calendar: current time, upcoming events, event locations, durations.  
- Location + mobility: GPS location, motion/activity hints, typical commute corridors.  
- Notification metadata: app names, categories, timestamps, importance levels.  
- Recent actions: last interventions taken, last app foregrounded, last unlock time.  

**Outputs**  
- `world_state` object for the next few hours, e.g.:  
  - Current context (home/office/transit), time pressure, known deadlines.  
  - For each upcoming event: start time, latest safe arrival, venue, travel window.  
  - Derived signals: “in meeting soon”, “end of day”, “sleep window”, “commute in 45m”.  
  - Confidence scores / missing-data flags per field.  

**Failure cases**  
- Sparse / missing signals (no calendar, flaky GPS, user denies permissions).  
- Contradictory inputs (calendar says WFH but GPS at office; multiple overlapping events).  
- Clock skew or timezone errors leading to wrong horizon.  
- Overfitting to noise (treating a one‑off late night as new permanent pattern).  
- Producing an overconfident world_state without marking low-confidence fields.

---

## Memory Agent

**Purpose**  
Retrieve and assemble the most relevant historical patterns and recent episodes from `memory/` so Chrona can personalize risk and planning to this specific user.[web:224][web:226][web:233]

**Inputs**  
- `world_state` from Context Agent.  
- Memory store: files like `episodes/*.md`, `patterns.yaml`, `preferences.json`, replay traces.  
- Query spec: which horizon (next 3–6 hours), which risk types (lateness, battery, overload, comms).  

**Outputs**  
- `memory_context` bundle, e.g.:  
  - Typical commute durations and variability for this route/time.  
  - User preferences (tolerance for being early/late, notification sensitivity, preferred transport).  
  - Past disruptions (missed meetings, low‑battery incidents, overload days).  
  - What interventions worked before for similar situations.  

**Failure cases**  
- Memory miss (no useful episodes yet, cold start).  
- Stale or poisoned memory (old behavior, changed job/office, or corrupted logs).[web:311][web:315][web:316]  
- Over-retrieval (too much irrelevant history bloating prompts / compute).  
- Biased retrieval (overemphasizing unusual edge cases; one bad day dominates patterns).  
- Schema drift between stored memory format and current agent expectations.

---

## Risk Agent

**Purpose**  
Quantify how likely things are to go wrong in the near future, across multiple dimensions, so planning is based on explicit risk trade‑offs instead of heuristics.

**Inputs**  
- `world_state` from Context Agent.  
- `memory_context` from Memory Agent.  
- Domain models: commute time distributions, battery drain models, cognitive load thresholds, communication SLAs.  
- Policies/thresholds: what counts as “high risk” for lateness, battery, overload, comms.  

**Outputs**  
- `risk_profile` object, including at least:  
  - `lateness_risk` (0–1) with driving factors and latest safe departure.  
  - `battery_risk` (0–1) with projected % at key times and risk explanation.  
  - `overload_risk` (0–1) based on meeting density, focus blocks, fragmentation.  
  - `communication_delay_risk` (0–1) based on upcoming offline windows vs. expected replies.  
  - Ranked list of top 3–5 risk chains (e.g. “low battery → ride‑hail app failure → missed train → late arrival”).  

**Failure cases**  
- Garbage‑in: incorrect world_state or memory causes misleading risk scores.[web:313][web:319]  
- Overconfidence from incomplete data (strong score with weak evidence, no uncertainty).  
- Ignoring cross‑dependencies (treating battery and commute as independent).  
- Oscillation (risk estimates thrashing on minor signal changes).  
- Silent failure: returning “low risk” when there is clearly an upcoming hard deadline.

---

## Planner Agent

**Purpose**  
Turn the `risk_profile` into 1–3 concrete, ranked interventions that could reduce risk with minimal disruption to the user.

**Inputs**  
- `world_state` from Context Agent.  
- `memory_context` from Memory Agent.  
- `risk_profile` from Risk Agent.  
- Action capabilities: what Chrona is allowed to do (notify, draft messages, suggest route, adjust app behavior, etc.).  
- User preferences and constraints (do-not-disturb rules, max interventions per hour, channels).  

**Outputs**  
- `plan_set` with 1–3 candidate interventions, each including:  
  - Action description (e.g. “Leave 10 minutes earlier via metro line 2”).  
  - Action type(s) (suggestion, draft message, route change, low‑power mode prompt).  
  - Target channels (on‑device card, notification, message draft).  
  - Estimated risk reduction and disruption cost.  
  - Preconditions and required confirmations.  

**Failure cases**  
- Trivial or redundant plans (telling the user what they already obviously know).  
- Overly aggressive plans (e.g. rescheduling meetings without sufficient confidence or consent).  
- Ignoring user preferences (suggesting commute modes the user avoids, bad times, wrong channels).  
- Non‑actionable plans (requires capabilities Chrona does not have on device).  
- Too many options (overwhelming planner output instead of a small, ranked set).

---

## Guardian Agent

**Purpose**  
Act as the safety and UX gatekeeper that decides **how** interventions are delivered: auto‑act, suggest, ask first, or block entirely.[web:313][web:317][web:315]

**Inputs**  
- `plan_set` from Planner Agent.  
- Policy rules: safety constraints, privacy rules, escalation rules, consent requirements.  
- User control model: what is allowed to auto‑act, what always requires ask‑first.  
- Contextual sensitivity: driving, in a meeting, asleep, in focus mode, etc.  
- System state: previous interventions in the last N minutes (to avoid spam).  

**Outputs**  
- Final `decision` per candidate plan, for example:  
  - `mode`: one of `auto_act`, `suggest`, `ask_first`, `block`.  
  - `approved_actions`: filtered, sanitized actions ready for execution.  
  - `rationale`: short explanation for logs and debugging.  
  - `audit_record`: entry for trace/memory so future agents can learn what was allowed.  

**Failure cases**  
- Over‑permissive behavior (auto‑acting where ask‑first or block was required).  
- Over‑cautious behavior (blocking or always asking for low‑risk, high‑value actions).  
- Inconsistent decisions across similar situations, confusing user trust.  
- Policy drift or misconfiguration (outdated rules, conflicting rule sets between versions).  
- Failure to respect critical contexts (e.g. sending non‑urgent prompts while driving or in focus time).