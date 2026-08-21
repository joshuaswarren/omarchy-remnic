# Operating theory — Remnic Recall

## What this is
A read-only Omarchy 4 Quickshell plugin: bar chip (today's memory count, pulse, health) + 3-tab panel (Recall search, Recent, Briefing) over the Remnic daemon HTTP API, with a bundled demo dataset. docs/REQUIREMENTS.md (A1–A8) is the acceptance contract; docs/DESIGN.md pins the as-built decisions.

## Load-bearing decisions
- **HTTP, not CLI, for live reads.** The CLI is itself an HTTP client, adds node cold-start per call, and has no recent-memories command. Browse (`GET /engram/v1/memories`) serves Recent, the today count, and search (`?q=`) in one surface. `POST /memories/search` returned zero for every probe on a live store — avoided.
- **One engine boundary.** `components/RemnicClient.qml` owns modes (`live|demo|offline|connecting`), polling, auth, and the only two subprocess sites (briefing, wl-copy in the panel). Demo data replays through the same mapping pipeline as live data, so shapes cannot drift.
- **Modes are evidence-based.** `connecting` until a probe under the *current settings generation* resolves (the first probe against a 100k-memory store takes ~8 s; claiming OFFLINE during it was a lie users would see on every open). Presence evidence (`everResponded`, tokens) resets when settings change.
- **Dual-kind pattern B** (as ytmini): standalone panel summoned by `omarchy-shell shell toggle <id> '<json>'`, chip passes an anchor in the payload; panel replicates KeyboardPanel's focus-prime (Exclusive → OnDemand) for type-immediately behavior.

## Verification theory
Everything was proven on esper against the real shell: hot-reload deploys, IPC deep-links, wtype-driven keyboard flows, grim captures of every state (live, demo, offline, connecting, both bar orientations, two themes), clipboard read-back via wl-paste. `omarchy plugin validate` passes. The demo GIF and screenshots in docs/screenshots are the durable evidence.

## Known upstream findings (not plugin defects)
- Remnic daemon browse served stale results on the central deployment (memory_store succeeded but never appeared; total frozen) — cache version not bumped by access-layer writes.
- `remnic briefing --format json` interleaves log lines with the JSON payload on stdout, and its JSON carries no markdown field — the plugin extracts the trailing JSON document and renders `sections` itself.
- Quickshell hot reload keeps stale component instances (entry points reload; `components/` edits need `omarchy restart shell`).
