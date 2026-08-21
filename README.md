# Remnic Recall

Your AI agents' memory, in the [Omarchy](https://omarchy.org) bar.

Omarchy's marketplace tracks what your agents *cost* — nothing tracks what they *remember*. Remnic Recall surfaces the [Remnic](https://remnic.com) memory engine on the desktop: live capture activity in the bar, instant recall search, recent memories, and your daily briefing in a panel. Built by Remnic's author.

![Remnic Recall demo](docs/screenshots/demo.gif)

## Features

- **Bar chip** — memories captured today, a single accent pulse when a new one lands, a warning dot when the engine stops answering, and a `demo` badge in demo mode. Horizontal and vertical bars.
- **Recall tab** — search-as-you-type over your memory store (300 ms debounce, 3-character minimum). Rows expand to full text; Enter copies the memory to the clipboard.
- **Recent tab** — the latest captures, newest first, grouped into Today and Earlier, each with a connector badge and relative timestamp.
- **Briefing tab** — the engine's daily briefing, rendered read-only with its generation time and a refresh action.
- **Demo mode** — no Remnic installed? The full UI runs on a bundled sample dataset with a visible DEMO watermark. Contest judges need 30 seconds, not a setup guide.
- **IPC deep-linking** — open the panel pre-searched from scripts or keybinds.
- **Honest states** — `connecting` while the first probe is in flight, an offline card with a retry when the engine is unreachable. No crashes, no error spam.
- Theme-aware via Omarchy semantic tokens: switch themes and the chip and panel recolor live.

| Recall | Recent | Briefing |
|---|---|---|
| ![Recall search](docs/screenshots/recall-search.png) | ![Recent](docs/screenshots/recent.png) | ![Briefing](docs/screenshots/briefing.png) |

## Install

```bash
omarchy plugin add https://github.com/joshuaswarren/omarchy-remnic
omarchy plugin enable io.github.joshuaswarren.remnic
```

That is enough for demo mode. For live data you need a [Remnic](https://remnic.com) engine:

```bash
npm install -g @remnic/cli
remnic init
remnic daemon start
remnic token generate omarchy
```

The plugin reads the daemon URL from its settings (default `http://127.0.0.1:4318`) and the token from `~/.remnic/tokens.json` — both are where a standard Remnic install puts them, so a local setup usually needs zero configuration.

## Settings

Settings live inline on the plugin entry in `~/.config/omarchy/shell.json` (`bar.layout` section). They hot-apply; no shell restart.

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
  "demoMode": "auto",
  "allowInsecureToken": false
}
```

- `daemonUrl` — the Remnic access daemon. A remote daemon works too; use a token that daemon issued.
- `token` / `tokenPath` — inline token wins; otherwise the first entry of the token store is used.
- `allowInsecureToken` — the bearer token is only sent to `https://` or a loopback address. Set this to `true` to also send it over plaintext HTTP to a remote daemon (the plugin still works without it; it just runs unauthenticated and will read as unreachable if the daemon requires auth).
- `namespace` — empty uses the daemon's default namespace.
- `demoMode` — `auto` (demo only when no engine is present), `on`, `off`.

## Usage

- **Left-click** the chip: toggle the panel on the Recall tab. **Right-click**: Recent tab.
- **Keyboard**: `Tab`/`Shift+Tab` cycles tabs, `↑`/`↓` selects a row, `→`/`←` expands and collapses, `Enter` copies the memory text, `Esc` closes.
- **Deep-link** from scripts or Hyprland keybinds:

```bash
omarchy-shell shell toggle io.github.joshuaswarren.remnic '{"tab":"recall","query":"postgres"}'
omarchy-shell shell summon io.github.joshuaswarren.remnic '{"tab":"briefing"}'
```

The payload takes `tab` (`recall` | `recent` | `briefing`) and an optional `query`.

## States

| State | Chip | Panel |
|---|---|---|
| Live | glyph + today count | tabs with live data, footer `engine ok · qmd <state> · ns <namespace>` |
| Connecting | glyph only | spinner card while the first probe runs |
| Offline | warning dot, tooltip shows last-seen | offline card with `remnic doctor` hint and Retry |
| Demo | `demo` badge | DEMO badge + watermark, sample dataset |

## Security & privacy

Memory content is sensitive. This plugin is read-only by contract:

- All live reads go to Remnic's existing daemon HTTP API (`GET /engram/v1/health`, `GET /engram/v1/memories`); no mutating endpoint is ever called.
- The plugin itself spawns exactly two processes: `remnic briefing --format json` (fixed argv, no shell) and `wl-copy` (memory text via stdin, never in argv, only on explicit Enter). Audit them with `grep -n "Process {" -r .`. Clicking the chip additionally asks the *host* to run `omarchy-shell shell toggle …` through Omarchy's own `bar.run`, which is how every third-party widget opens its panel.
- The bearer token is read from disk, sent only as an `Authorization` header to `daemonUrl`, never logged, never rendered, never placed in a URL, an argv, or the clipboard.
- Memory text renders as plain text (`Text.PlainText`). The briefing is the one markdown surface, and it is treated as untrusted because the engine assembles it from memory content: inline HTML, image syntax, and link syntax are all neutralized, so nothing in a memory can embed markup or cause a remote fetch. A bare URL may still render as an inert link — the plugin installs no link handler, so it cannot be opened or followed. Headings, emphasis, and lists survive.
- Responses are size-capped before parsing and the memory array is length-capped, so a misbehaving daemon cannot stall or exhaust the shell process.
- No network access besides `daemonUrl`. No telemetry. Nothing written to disk.

Two settings deserve care because they point the plugin at things you choose: `daemonUrl` is where the bearer token gets sent (use loopback, or HTTPS/a trusted network for a remote daemon), and `tokenPath` is read whole into the shell process, so point it at a token file rather than something large.

## Development

```bash
git clone https://github.com/joshuaswarren/omarchy-remnic
rsync -a --exclude .git ./ ~/.config/omarchy/plugins/io.github.joshuaswarren.remnic/
omarchy plugin validate ~/.config/omarchy/plugins/io.github.joshuaswarren.remnic
```

Entry-point QML hot-reloads on save. Edits under `components/` may keep stale instances until `omarchy restart shell`. Shell logs: `journalctl --user -t omarchy-shell -f`.

Design decisions and the acceptance criteria are in [docs/DESIGN.md](docs/DESIGN.md) and [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

## Compatibility

- Omarchy 4 / Quattro shell (developed and verified on 4.0.0.r1758).
- Remnic `@remnic/cli` 9.x; any daemon exposing the `/engram/v1` read API.

## Troubleshooting

- **Panel says offline but the daemon runs** — check `daemonUrl` and that the token was issued by *that* daemon: `curl -H "Authorization: Bearer <token>" <daemonUrl>/engram/v1/health`.
- **Briefing tab is missing in live mode** — the `remnic` binary is not on the shell's PATH or the briefing command failed; run `remnic briefing --format json` in a terminal.
- **Everything shows demo** — the plugin found no daemon response and no token; set `demoMode` to `off` to see the offline card instead, or configure `daemonUrl`/`token`.

## License

[MIT](LICENSE)
