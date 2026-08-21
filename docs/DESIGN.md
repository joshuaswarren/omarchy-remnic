# Remnic Recall — Design (frozen contract v1)

Companion to [REQUIREMENTS.md](REQUIREMENTS.md). This pins every decision the spec left open, grounded in the installed Omarchy 4 contract on esper (4.0.0.r1758) and the Remnic source at HEAD `0e6701c5a`.

## 1. Engine access architecture (settles REQUIREMENTS §6/§10)

Three modes, one state machine: `live | demo | offline`.

**Live reads go over HTTP to the local Remnic daemon**, not per-call CLI spawns. Evidence: the CLI itself is an HTTP client of the daemon; a node CLI spawn per debounced keystroke adds ~0.5-1s cold start and the CLI has **no** recent-memories command at all — browse exists only on the daemon (`GET /engram/v1/memories`). The daemon HTTP API is Remnic's existing read-only surface, so G5 holds.

Pinned endpoints (verified against a live daemon):

| Need | Call | Notes |
|---|---|---|
| Health (G3) | `GET /engram/v1/health` | `{ok, defaultNamespace, qmd:{active,degraded,…}, replica:{polledAt}}`; 503 while warming; 401 without token |
| Recent + today count | `GET /engram/v1/memories?sort=created_desc&limit=100[&namespace=]` | `{count,total,memories:[{id,path,category,status,created,updated,tags,preview}]}`; one call serves both: Recent shows first `recentLimit`, chip counts `created >=` local midnight (cap display "99+") |
| Recall search | `GET /engram/v1/memories?q=<query>&sort=updated_desc&limit=20[&namespace=]` | substring browse; verified returning ranked-enough hits. `POST /engram/v1/memories/search` returned 0 for every probe on a live store — do NOT use it |
| Full text of one memory | `preview` field (180 chars) + expandable row fetch is **not** available over browse; Enter copies `preview` + `path` reference. v1 renders preview text; full-text fetch is a v2 item |
| Briefing | subprocess: `[remnicCommand, "briefing", "--format", "json"]` | The daemon has no briefing endpoint. This is the ONLY subprocess in the plugin (A6 allowlist = exactly this argv shape). ENOENT or non-zero → hide Briefing tab (spec §6 degradation) |

**Auth resolution** (in order): inline setting `token` → `tokenPath` JSON (default `~/.remnic/tokens.json`, real shape `{"tokens": [{connector, token, …}]}`; accept a bare array fallback), first entry's token. `daemonUrl` setting defaults to `http://127.0.0.1:4318` (Remnic's `agentAccessHttp` default). README documents `remnic token generate omarchy` as the setup step. Note: a token is only valid on the daemon that issued it — pointing `daemonUrl` at a remote daemon requires that daemon's token via the `token` setting.

**Transport in QML:** `XMLHttpRequest` (available in Quickshell's QML runtime). If it proves unavailable on-device, fallback is a fixed-argv `curl` Process (still read-only, still allowlisted); implementer verifies XHR on esper before building on it.

**Mode selection** (`demoMode` setting: `auto|on|off`):
- `on` → demo. `off` → never demo (offline card when unreachable).
- `auto`: engine "present" when health responds OR a token resolves OR `remnicCommand` exists on PATH. Present-but-unreachable → `offline`. Absent → `demo`.

## 2. Plugin architecture (host contract, from esper source)

Dual-kind (pattern B, as `io.github.joshuaswarren.ytmini`): the shell instantiates `Panel.qml` standalone and injects `shell` + `manifest`; `BarWidget.qml` is hosted by the bar and injected `bar`, `moduleName`, `settings`.

- Chip → panel toggle: `bar.run("omarchy-shell shell toggle io.github.joshuaswarren.remnic '<json>'")`. The chip includes its bar edge + screen x in the payload (`{"anchor":{"edge":"top","x":1234}}`) so the panel opens adjacent to the chip; payloads without `anchor` (IPC deep-links) center near the bar edge.
- Panel owns its window: `PanelWindow` (WlrLayer.Top) with the KeyboardPanel focus-prime pattern (brief `WlrKeyboardFocus.Exclusive` → `OnDemand`) so search-as-you-type works when keyboard-summoned. Esc closes. Outside-click dismisses.
- Settings: bar widget uses injected `settings` (live-updated). The panel is NOT injected settings (host contract): it reads the plugin entry from `~/.config/omarchy/shell.json` via `Quickshell.Io.FileView` (watch + re-parse). Shared parsing lives in `components/RemnicClient.qml`, instantiated separately in each entry point (stateless HTTP; no shared mutable state).
- Theming: only `qs.Commons` semantic tokens (`Color.background/foreground/accent/urgent`, `Color.popups.*`, `Style.cornerRadius`, `Style.space()`, `Style.spacing.*`, `Border.surfaceSpec`) and `qs.Ui` shared components where the panel window allows. No hard-coded colors. Both bar orientations (use `bar.vertical`/`barSize`).

## 3. File layout

```
manifest.json
BarWidget.qml              # chip (thin; visual states + toggle)
Panel.qml                  # panel window + tabs (thin composition)
components/
  RemnicClient.qml         # THE engine boundary: modes, health, fetch, briefing Process, settings resolution
  DemoData.qml             # loads assets/demo/*.json, same output shapes as RemnicClient
  MemoryRow.qml            # one result/recent row (expandable)
  TabBar.qml               # Recall | Recent | Briefing
assets/demo/memories.json  # ~25 sample memories, EngramAccessMemorySummary shape
assets/demo/briefing.json  # {markdown, generatedAt}
```

`RemnicClient` public contract (both UIs code against this; demo/live/offline are internal):

```qml
property string mode            // "live" | "demo" | "offline"
property bool  healthy
property string healthLine      // footer text: "engine ok · qmd active · ns generalist" / last-seen
property string namespace
property int   todayCount
property var   recent           // [{id, summary, source, created, tags, category}]
signal newMemories(int delta)   // chip pulse
function search(query, cb)      // cb([{id, summary, source, created, tags, category}])
function fetchBriefing(cb)      // cb({markdown, generatedAt, available})
function refresh()              // re-poll now
```

`source` = derived badge: first tag matching a known connector, else `category`.

## 4. UX spec

**Chip**: Remnic glyph (nerd-font brain/archive glyph) + today count. States per REQUIREMENTS §4.1: muted idle; single accent pulse on `newMemories` (scale+glow ~600ms, once); warning dot (Color.urgent) when offline with tooltip "last seen HH:MM"; small "demo" badge text in demo mode. Vertical bar: glyph above count, no badge text (dot instead).

**Panel**: ~`Style.space(480)` wide, max-height ~`Style.space(560)`, bar-adjacent. Header: title "Remnic Recall" + namespace chip + demo/offline badge + refresh button. TabBar: Recall / Recent / Briefing (Briefing hidden when unavailable in live mode; always present in demo). Content:
- Recall: TextField autofocused, placeholder "Search your agents' memory…"; ≥3 chars + 300ms debounce; ≤20 rows; row = summary (2-line ellipsis), source badge, relative time; click/→ expands full preview; Enter on selected row copies text to clipboard with a subtle "Copied" toast; empty query → centered hint (glyph + "Type to recall"), zero hits → "No memories match".
- Recent: same rows, newest first, `recentLimit` items, section header "Today" / "Earlier".
- Briefing: rendered markdown-ish text (read-only), generation timestamp, refresh re-runs the CLI with a spinner.
- Footer: health line + namespace; offline mode replaces content with a card: warning glyph, "Remnic engine unreachable", last-seen, `remnic doctor` hint, Retry button. Demo mode shows a persistent translucent "DEMO DATA" watermark chip in the footer.
- Keyboard: Tab cycles tabs; ↑/↓ move row selection; → expands; Enter copies; Esc closes.

## 5. Security invariants (A6 audit points)

1. Exactly TWO `Process` call sites in the whole tree (the A6 allowlist):
   - briefing runner in `RemnicClient.qml`, argv `[remnicCommand, "briefing", "--format", "json"]` — no shell, no user-influenced argv beyond `remnicCommand` (settings-provided binary path, execvp semantics, never parsed by a shell);
   - clipboard copy in the panel, argv `["wl-copy"]` with the memory text written to stdin (never in argv), spawned only on explicit Enter.
2. Token read from disk is never logged, never rendered, sent only as `Authorization` header to `daemonUrl`.
3. No writes anywhere except the clipboard on explicit Enter.
4. Memory text renders with `textFormat: Text.PlainText`. The briefing body is the single `MarkdownText` surface and is treated as untrusted, because the engine assembles it from memory content: `sanitizeBriefingMarkdown` escapes `\`, `<`, `[`, `]`, and `|` on the verbatim path, and `escapeMarkdown` renders section items fully inert. **What that guarantees:** no inline HTML, no image (so no remote fetch), no link syntax, no table. **What it does not:** a bare URL can still be auto-linked by the GFM parser into an inert anchor — the plugin installs no `onLinkActivated`, so it cannot be opened or followed. Headings, emphasis, lists, and code spans survive by design.
5. Responses are bounded before parsing (`maxResponseChars`, `maxMemoriesParsed`, `maxBriefingChars`) so a hostile or broken engine cannot stall the shell's GUI thread.
6. The connection identity used for change detection is a `Qt.md5` digest, not a stored copy of the token.
7. The bearer token is released only to an `https://` or loopback `daemonUrl` (userinfo is stripped before the host is judged, so `http://127.0.0.1:pw@elsewhere` does not qualify); plaintext-remote requires the explicit `allowInsecureToken` opt-in. A response whose final URL is a different origin than the one authorized is discarded — note this is defense-in-depth, not prevention: QML's `XMLHttpRequest` follows redirects itself and exposes no way to refuse them, so the header may already have been sent before the check runs.
8. `remnicCommand` is accepted only as a bare name or an absolute path without `..`; anything else falls back to the default rather than being executed.
9. Every daemon-supplied string that reaches text layout is length-clamped (`maxSummaryChars`, badge/tag `clampLabel`, `safeNamespace`), the tag list is count-capped, the briefing is bounded by characters *and* lines, and `extractJson` caps its candidate scans.
10. Demo content is gated inside `loadDemo()`/`fetchBriefing` and marked by `showingDemo`, so bundled sample memories *or* the sample briefing can never render without the DEMO badge.

## 6. Settings (final; supersedes REQUIREMENTS §5 draft)

```json
{
  "id": "io.github.joshuaswarren.remnic",
  "daemonUrl": "http://127.0.0.1:4318",
  "token": "",
  "tokenPath": "~/.remnic/tokens.json",
  "remnicCommand": "remnic",
  "namespace": "",
  "pollSeconds": 60,
  "recentLimit": 30,
  "demoMode": "auto"
}
```

## 7. Open items tracked to closure

- XHR availability in Quickshell QML — verify first on esper (fallback pinned above).
- Briefing latency/API-key needs on a fresh machine — Briefing tab must degrade gracefully (hidden live / spinner timeout 30s → inline error).
- Full-text expansion beyond 180-char preview — v2.
