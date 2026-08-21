# Operating theory — Remnic Recall implementation

## What we are building and why
docs/REQUIREMENTS.md is a complete spec (v0.1.0) for a read-only Omarchy 4 Quickshell plugin: a bar chip (today's memory count, pulse, health) + a 3-tab panel (Recall search, Recent, Briefing), backed by the Remnic CLI, with a bundled demo dataset so the full UI works with no engine installed. The spec's acceptance criteria A1–A8 are the exit predicate.

## Strategy
Orchestrator (this session) owns design, integration, verification. Implementation is delegated to sub-agent sessions. Sequencing follows the spec's milestones M1–M4, but the load-bearing early decision is the **engine adapter contract**: one QML/JS boundary that every UI piece consumes, with three interchangeable sources (live CLI, demo dataset, offline). Freeze that contract before UI fan-out so bar chip and panel can be built in parallel.

The domain model: a single `EngineState` (mode: live|demo|offline; health; todayCount) plus three read-only query surfaces (search(query) → [Memory], recent(limit) → [Memory], briefing() → {text, generatedAt}). `Memory {id, text, summary, source, timestamp}`. All subprocess calls go through one allowlisted spawn site (A6).

## Verification theory
The plugin only proves itself on a real Omarchy surface: rsync repo → esper ~/.config/omarchy/plugins/, hot-reload, drive via IPC, capture screenshots/recordings per state (live, demo, offline, both bar orientations, ≥2 themes). `omarchy plugin validate` is necessary but not sufficient.

## Current status
Recon in flight: Omarchy plugin contract (from esper's installed shell source) and Remnic CLI JSON surface (from ~/src/remnic). Key unknown: the real user-facing Remnic CLI command name and its JSON flags — the spec left these "to be pinned at implementation time".
