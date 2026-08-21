# Remnic Recall — Requirements

Status: **implemented** (v0.1.0; kept as the binding spec — see [DESIGN.md](DESIGN.md) for the as-built decisions)
Target: Omarchy 4 / Quattro shell (Quickshell plugin API)
Plugin ID: `io.github.joshuaswarren.remnic`
Kinds: `bar-widget` + `panel`

## 1. Problem

Omarchy treats AI agents as first-class citizens, and the marketplace tracks their *quota* (Agent Bar, AI Usage, CodexBar) — but nothing tracks their *memory*. [Remnic](https://remnic.com) gives coding agents a persistent memory engine; Remnic Recall puts that memory on the desktop: live capture activity in the bar, instant recall search, and a briefing panel, without opening a terminal.

## 2. Goals

- G1: Bar chip showing memory liveness: count of memories captured today, subtle pulse when a new memory lands.
- G2: Panel with three tabs:
  - **Recall** — search box querying Remnic recall; results show summary, source, timestamp; Enter copies the memory text, Ctrl+Enter opens it in the default agent as a prompt seed.
  - **Recent** — latest captured memories, newest first.
  - **Briefing** — the current Remnic briefing (daily digest) rendered as read-only text.
- G3: Health surfacing: engine reachable/unreachable, index freshness, last sync time.
- G4: **Demo mode** — with no Remnic installed, the plugin runs against a bundled read-only sample dataset so anyone (including contest judges) can experience the full UI in 30 seconds.
- G5: All reads go through Remnic's existing read-only surface (CLI with JSON output / read-only MCP tools such as `recall`, `briefing`, `memory_search`). The plugin adds no new API.
- G6: Theme-aware via Omarchy semantic tokens.

## 3. Non-goals

- NOT a memory editor. v1 is strictly read-only: no create, no forget, no tier changes. (Write actions are a possible v2 behind an explicit opt-in.)
- NOT a Remnic installer or configurator; `remnic doctor` and `remnic setup` remain the canonical path, and the panel links to the docs when the engine is absent.
- NOT an agent-usage/quota widget — the built-in agents panel and existing plugins own that.
- No telemetry of any kind. Memory content never leaves the machine through this plugin.

## 4. UX specification

### 4.1 Bar chip

| State | Appearance |
|---|---|
| Healthy, idle | Remnic glyph + today's capture count, muted |
| New memory captured | Single accent pulse |
| Engine unreachable | Glyph with warning dot; tooltip: last-seen time |
| Demo mode | Glyph with small "demo" badge |

Left-click: toggle panel (opens on Recall tab). Right-click: refresh / switch tab shortcuts.

### 4.2 Panel

- 480px-class floating panel per first-party panel conventions; `open(payloadJson)` may carry `{"tab": "recall", "query": "..."}` so other tools can deep-link a search.
- Recall tab: debounced-as-you-type search (≥3 chars, 300ms), max 20 results, each row expandable to full text. Empty query shows a hint, not an error.
- Recent tab: 30 most recent memories with relative timestamps; source badge (which connector/agent captured it).
- Briefing tab: renders the latest briefing; a refresh action re-invokes it; timestamp of generation shown.
- Footer: engine health line (G3) + namespace indicator when multiple namespaces exist.
- Keyboard: Tab cycles tabs, arrows navigate results, Esc closes.

## 5. Settings (inline on the `shell.json` plugin entry)

```json
{
  "id": "io.github.joshuaswarren.remnic",
  "remnicCommand": "remnic",
  "namespace": "",
  "pollSeconds": 60,
  "recentLimit": 30,
  "demoMode": "auto"
}
```

- `remnicCommand`: binary name or absolute path; resolved once, never through a shell.
- `namespace`: empty = default namespace.
- `demoMode`: `auto` (demo when engine absent), `on`, `off`.

## 6. Data & integration

- ~~All engine access via subprocess calls to the Remnic CLI~~ **superseded during implementation** — see [DESIGN.md §1](DESIGN.md#1-engine-access-architecture-settles-requirements-610). Live reads go over HTTP to the Remnic daemon (`GET /engram/v1/health`, `GET /engram/v1/memories`); the CLI remains the surface for the briefing only. The CLI is itself an HTTP client of that daemon and has no recent-memories command, so the daemon is the narrower, faster surface.
- Capture-count polling every `pollSeconds`; search calls are on-demand only.
- Demo dataset: ~25 hand-written sample memories + one sample briefing in `assets/demo/`, loaded from disk, clearly watermarked in the UI.
- Defensive parsing throughout: engine version drift degrades features (hide the Briefing tab if the command is missing) rather than erroring the whole panel.

## 7. Security & privacy

- Read-only by contract (G5, N1): the plugin never invokes mutating Remnic commands (`forget`, `purge`, capture, migrate).
- Memory content is sensitive by nature: it renders on screen only inside the panel, is never written to disk by the plugin, never logged, and clipboard copy happens only on explicit user action (Enter).
- The plugin contacts exactly one network endpoint: the `daemonUrl` it is configured with (loopback by default). It is an HTTP client of the Remnic daemon, so the search query and the bearer token are sent to that endpoint; the token is withheld unless the destination is loopback or HTTPS (or the user sets `allowInsecureToken`). Nothing is sent anywhere else, and memory content is never transmitted outward — it only travels from the engine to the panel.
- Subprocess: fixed argument arrays; the only user-influenced values (`query`, `namespace`) are passed as discrete argv entries.

## 8. Acceptance criteria

- A1: With Remnic running, the chip shows today's capture count within one poll cycle of a new memory.
- A2: Recall search returns results for a known memory in <1s on a warm engine; Enter copies the memory text to the clipboard.
- A3: `open('{"tab":"recall","query":"omarchy"}')` via `omarchy-shell` IPC opens the panel pre-searched.
- A4: With Remnic stopped, the chip shows the warning state and the panel shows a helpful offline card — no crash, no error spam.
- A5: On a machine with no `remnic` binary and `demoMode: auto`, the full UI works against the demo dataset with a visible demo badge.
- A6: No mutating command is ever spawned (verify by auditing the subprocess call sites — there must be exactly one allowlist of subcommands).
- A7: Theme switch recolors chip and panel with no restart; horizontal and vertical bars both render.
- A8: `omarchy plugin validate .` passes.

## 9. Milestones

- M1: Engine adapter + demo dataset + bar chip (A1, A4, A5).
- M2: Panel — Recall + Recent tabs (A2, A6).
- M3: Briefing tab + IPC deep-link (A3).
- M4: Polish — theming, vertical bar, README screenshots and demo GIF (A7, A8).

## 10. Open questions

- Pin minimum Remnic version, or feature-detect per command? (Lean: feature-detect; the engine moves fast.)
- Should Ctrl+Enter "send to default agent" ship in v1? It's the best demo moment (`omarchy agent prompt` exists for exactly this) but adds a security-review surface. (Lean: yes, behind a setting, off by default.)
