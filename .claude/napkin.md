# Napkin — omarchy-remnic

## Works
- esper reachable: `ssh esper 'cmd'` (Omarchy 4.0.0.r1758). Shell source read-only at /usr/share/omarchy/shell; third-party plugins hot-reload from ~/.config/omarchy/plugins/.
- Reference third-party plugin on esper: ~/.config/omarchy/plugins/io.github.joshuaswarren.ytmini.
- Remnic source: ~/src/remnic (workspace pkg `remnic-workspace`, bin `engram-access`). No `remnic` binary installed locally or on esper.

## Mistakes / corrections

## esper test-harness facts
- Wayland env for ssh commands: WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 HYPRLAND_INSTANCE_SIGNATURE=<from /proc/$(pgrep -n quickshell)/environ>. grim works with these.
- `omarchy` CLI over ssh needs a login shell (`bash -lc`) or OMARCHY_PATH is unset.
- esper token store: ~/.remnic/tokens.json shape {"tokens":[{connector,token}]}; esper-issued tokens are 401 on the central daemon (192.168.3.200:4318) — live tests use the omp token inline in the shell.json plugin entry.
- remnic CLI on esper: `npm i -g --prefix ~/.local @remnic/cli` (system npm prefix /usr is root-owned).
- (none yet)

- 2026-08-21: an ssh jq-edit pipeline truncated esper ~/.config/omarchy/shell.json to 0 bytes (recovered from shell.json.bak-hardstop). Lesson: NEVER pipe a file-rewriting command chain at a remote config; write a python script that os.replace()s atomically, scp it, run it.
- poteto-mode principle-* leaf skills not installed on this host; applying inlined summaries from SKILL.md (noted via agent-note).
- Plugin validate forbids symlinks anywhere in the plugin dir — deploy to esper with rsync, not symlink.
