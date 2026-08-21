# Development

## Work on it in place

The fastest loop is to install the plugin, then edit it where Omarchy loaded it
from:

```bash
omarchy plugin add https://github.com/joshuaswarren/omarchy-remnic
cd ~/.config/omarchy/plugins/io.github.joshuaswarren.remnic
```

Entry-point QML (`BarWidget.qml`, `Panel.qml`) hot-reloads on save. Edits under
`components/` may keep stale instances alive until you restart the shell:

```bash
omarchy restart shell
```

To contribute a change back, fork the repository on GitHub, add your fork as a
remote in that directory, and push a branch.

## Validate and lint

```bash
omarchy plugin validate ~/.config/omarchy/plugins/io.github.joshuaswarren.remnic
qmllint -I /usr/share/omarchy/shell Panel.qml BarWidget.qml components/*.qml
```

`qmllint` reports unresolvable-host-type advisories for `qs.Ui`, `qs.Commons`,
and the first-party components when run outside the shell process. Those are
expected. Syntax errors and binding loops are not.

## Watch the shell

```bash
journalctl --user -t omarchy-shell -f
```

A clean run of this plugin produces no `error`, `TypeError`, or binding-loop
lines. Treat any of those as a defect.

Two failure modes on a development machine are worth knowing, because both look
like a plugin bug and are not:

- **Two `quickshell` processes.** A restart that races a dying shell can leave a
  duplicate. The bar you see belongs to one instance and your plugin may have
  loaded into the other, so the chip appears to vanish. Kill every `quickshell`
  process, then start one.
- **A stranded lock screen.** If Hyprland's lock surface crashed, screen capture
  is blocked and the shell re-arms the lock on every restart. Clear it with
  `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`.

## Never lint or stage inside the plugins directory

Omarchy watches `~/.config/omarchy/plugins/` and reloads on any change. Copying
a scratch tree in there fires a reload storm in the live shell. Stage scratch
copies under `/tmp` instead.

## Layout

```
manifest.json              # plugin id, kinds, entry points
BarWidget.qml              # the bar chip
Panel.qml                  # the panel window, tabs, and key handling
components/
  RemnicClient.qml         # the engine boundary: modes, health, HTTP, briefing, settings
  DemoData.qml             # loads assets/demo/*.json into the same shapes
  MemoryRow.qml            # one memory row, expandable
  TabBar.qml               # Recall | Recent | Briefing
  PanelSettings.qml        # reads the plugin entry from shell.json
assets/demo/               # the bundled sample dataset
docs/screenshots/          # README images, demo GIF and MP4
preview.png                # marketplace card image
```

Both entry points instantiate `RemnicClient` separately. It holds no shared
mutable state, so the chip and the panel cannot desynchronize through it.
