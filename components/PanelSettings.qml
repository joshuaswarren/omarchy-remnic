import QtQuick
import Quickshell
import Quickshell.Io

// The plugin's own entry out of ~/.config/omarchy/shell.json.
//
// The host injects `settings` into bar widgets but not into standalone panels,
// so the panel reads the file itself. Watched, so `omarchy bar set` and hand
// edits land without a shell restart.
QtObject {
  id: root

  property string pluginId: "io.github.joshuaswarren.remnic"

  // Always a plain object. RemnicClient owns the defaults for missing keys.
  property var value: ({})

  function isPlainObject(candidate) {
    return candidate !== null && typeof candidate === "object" && !Array.isArray(candidate)
  }

  function entryIn(list) {
    if (!Array.isArray(list)) return null
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (isPlainObject(entry) && String(entry.id || "") === root.pluginId) return entry
    }
    return null
  }

  // shell.json keeps settings inline on the entry, but a hand-written file may
  // carry an id-keyed block instead. Accept both rather than silently ignoring
  // a user's settings.
  function blockIn(config) {
    var maps = [config.pluginSettings, config.settings, config.plugins]
    for (var i = 0; i < maps.length; i++) {
      if (isPlainObject(maps[i]) && isPlainObject(maps[i][root.pluginId])) return maps[i][root.pluginId]
    }
    return null
  }

  function layoutEntry(config) {
    if (!isPlainObject(config.bar) || !isPlainObject(config.bar.layout)) return null
    var layout = config.bar.layout
    for (var section in layout) {
      var entry = entryIn(layout[section])
      if (entry) return entry
    }
    return null
  }

  function apply(raw) {
    var next = ({})
    try {
      var config = JSON.parse(String(raw || "").trim() || "{}")
      if (isPlainObject(config)) {
        var block = blockIn(config)
        var entry = entryIn(config.plugins) || layoutEntry(config)
        // Inline entry values win: that is where the shell persists per-instance
        // settings, and an id-keyed block is only a fallback shape.
        if (block) for (var blockKey in block) next[blockKey] = block[blockKey]
        if (entry) for (var entryKey in entry) next[entryKey] = entry[entryKey]
      }
    } catch (e) {
      // Missing or half-written shell.json: run on RemnicClient's defaults
      // instead of tearing down the panel.
    }
    root.value = next
  }

  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.apply(text())
    // text() is stale inside the change signal, so route every path through
    // reload() -> onLoaded.
    onFileChanged: reload()
    onLoadFailed: root.apply("")
  }
}
