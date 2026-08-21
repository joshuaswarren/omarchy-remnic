# Napkin — omarchy-remnic

## Works
- esper: `ssh esper 'cmd'`; Omarchy 4.0.0.r1758; shell source at /usr/share/omarchy/shell (read-only); plugins hot-reload from ~/.config/omarchy/plugins/ (entry points only — components/ edits need `omarchy restart shell`).
- Wayland env for ssh commands: WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 (+HYPRLAND_INSTANCE_SIGNATURE from /proc/$(pgrep -n quickshell)/environ). `omarchy`/`omarchy-shell` need a login shell or OMARCHY_PATH=/usr/share/omarchy.
- remnic CLI on esper: `npm i -g --prefix ~/.local @remnic/cli`.
- Token store shape: {"tokens":[{connector,token}]}; a token only works on the daemon that issued it.
- Reference mirror: /tmp/omarchy-ref (shell Ui/Commons + ytmini).

## Mistakes / corrections
- 2026-08-21: an ssh jq-edit pipeline truncated esper ~/.config/omarchy/shell.json to 0 bytes (recovered from shell.json.bak-hardstop, made by the hardstop agent). Lesson: remote config edits go through a scp'd python script that os.replace()s atomically.
- Two other agents develop plugins on esper concurrently (shiplog, hardstop): expect shell restarts, focus steals, and shell.json rewrites you did not make. Gate IPC on `omarchy-shell shell ping`; recapture rather than debug phantom closes.

## Gotchas
- Plugin validate forbids symlinks in the plugin dir — deploy with rsync.
- grim -g syntax is "X,Y WxH" (x between W and H).
- Hyprland lock crash leaves the session probe (`omarchy-hyprland-session-locked`) stuck locked and quickshell PAM looping every 30s; `loginctl unlock-session` clears it. Panels bound to sessionLocked hide while it lingers.
- poteto-mode principle-* leaf skills not installed on this host; applied inlined summaries from SKILL.md.
