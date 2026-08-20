# Remnic Recall

Your AI agents' memory, in the [Omarchy](https://omarchy.org) bar.

Omarchy's marketplace tracks what your agents *cost* — nothing tracks what they *remember*. Remnic Recall surfaces the [Remnic](https://remnic.com) memory engine on the desktop: live capture activity in the bar, instant recall search, recent memories, and your daily briefing in a panel. Built by Remnic's author.

> **Status: specification phase.** The plugin contract, UX, integration surface, and acceptance criteria are fully defined in [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md). Implementation has not started. Watch the repo if you want the working version.

## Planned features

- Bar chip: memories captured today, with a pulse when a new one lands
- Panel tabs: **Recall** search · **Recent** captures · daily **Briefing**
- Engine health at a glance: reachable, index freshness, last sync
- **Demo mode**: no Remnic installed? The full UI runs on a bundled sample dataset
- IPC deep-linking: open the panel pre-searched from scripts or keybinds
- Strictly read-only against Remnic's existing CLI/MCP surface — no new API, no mutations
- Theme-aware via Omarchy semantic tokens

## Plugin contract

- **ID:** `io.github.joshuaswarren.remnic`
- **Kinds:** `bar-widget` + `panel`
- **Compatibility target:** Omarchy 4 / Quattro shell

## Requirements

- [Remnic](https://remnic.com) installed and healthy (`remnic doctor`) — or nothing at all, in demo mode

## Installation (once implemented)

```bash
omarchy plugin add https://github.com/joshuaswarren/omarchy-remnic
```

## Configuration

Settings live inline on the plugin entry in `~/.config/omarchy/shell.json` — see [docs/REQUIREMENTS.md §5](docs/REQUIREMENTS.md#5-settings-inline-on-the-shelljson-plugin-entry).

## Security & privacy

Memory content is sensitive. This plugin is read-only by contract, renders memories on screen only, writes nothing to disk, logs nothing, and has no network access of its own. Details in [docs/REQUIREMENTS.md §7](docs/REQUIREMENTS.md#7-security--privacy).

## License

[MIT](LICENSE)
