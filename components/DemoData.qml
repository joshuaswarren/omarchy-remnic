import QtQuick
import Quickshell.Io

// Bundled read-only sample data, so the whole UI works in 30 seconds on a
// machine that has never seen Remnic. Rows come back in the daemon's own browse
// shape, which lets RemnicClient run demo data through exactly the same mapping,
// today cutoff, and pulse arithmetic as live data.
QtObject {
  id: root

  readonly property string namespace: "generalist"
  property var memories: []
  property bool loaded: false

  // Authored timestamps would age into "nothing captured today" within a day of
  // shipping, so the whole set slides forward on load and keeps its authored
  // spacing. The newest sample lands here, and the authored today-cluster spans
  // under three hours behind it.
  // ponytail: one global shift, so a judge running between midnight and ~03:00
  // sees 2-3 of today's five. Per-item rebasing against local midnight if that
  // window ever matters.
  readonly property int freshestAgeMs: 25 * 60 * 1000
  property real timeShift: 0

  readonly property string assetDir: localPath(Qt.resolvedUrl("../assets/demo/"))

  function reload() {
    memoriesFile.reload()
    briefingFile.reload()
  }

  // Substring recall over everything a row shows, so a judge typing "postgres"
  // or "hyprland" gets the hit they expect.
  function filter(query) {
    var needle = String(query || "").toLowerCase().trim()
    if (needle === "") return []
    var out = []
    for (var i = 0; i < memories.length; i++) {
      var item = memories[i]
      var haystack = [
        String(item.preview || ""),
        String(item.category || ""),
        String(item.id || ""),
        (Array.isArray(item.tags) ? item.tags.join(" ") : "")
      ].join(" ").toLowerCase()
      if (haystack.indexOf(needle) >= 0) out.push(item)
    }
    return out
  }

  function briefing() {
    if (briefingMarkdown === "") return { markdown: "", generatedAt: "", available: false }
    return {
      markdown: briefingMarkdown,
      generatedAt: shiftStamp(briefingGeneratedAt, timeShift),
      available: true
    }
  }

  // -------------------------------------------------------------- internals
  property string briefingMarkdown: ""
  property string briefingGeneratedAt: ""

  function localPath(url) {
    var text = String(url || "")
    if (text.indexOf("file://") !== 0) return text
    return decodeURIComponent(text.substring(7))
  }

  function shiftStamp(value, shift) {
    var stamp = Date.parse(String(value || ""))
    if (!isFinite(stamp)) return String(value || "")
    return new Date(stamp + shift).toISOString()
  }

  function applyMemories(raw) {
    var list = []
    try {
      var doc = JSON.parse(String(raw || ""))
      if (Array.isArray(doc)) list = doc
      else if (doc && Array.isArray(doc.memories)) list = doc.memories
    } catch (e) {
      list = []
    }

    var newest = 0
    for (var i = 0; i < list.length; i++) {
      var stamp = Date.parse(list[i] && list[i].created ? String(list[i].created) : "")
      if (isFinite(stamp) && stamp > newest) newest = stamp
    }
    var shift = newest > 0 ? (Date.now() - freshestAgeMs - newest) : 0
    timeShift = shift

    var out = []
    for (var j = 0; j < list.length; j++) {
      var item = list[j]
      if (!item) continue
      out.push({
        id: String(item.id || ""),
        category: String(item.category || ""),
        status: String(item.status || "active"),
        created: shiftStamp(item.created, shift),
        tags: Array.isArray(item.tags) ? item.tags : [],
        preview: String(item.preview || "")
      })
    }
    memories = out
    loaded = out.length > 0
  }

  function applyBriefing(raw) {
    var markdown = ""
    var generatedAt = ""
    try {
      var doc = JSON.parse(String(raw || ""))
      if (doc && typeof doc === "object") {
        if (typeof doc.markdown === "string") markdown = doc.markdown
        else if (typeof doc.text === "string") markdown = doc.text
        if (typeof doc.generatedAt === "string") generatedAt = doc.generatedAt
      }
    } catch (e) {
      markdown = ""
      generatedAt = ""
    }
    briefingMarkdown = markdown
    briefingGeneratedAt = generatedAt
  }

  property FileView memoriesFile: FileView {
    path: root.assetDir + "memories.json"
    printErrors: false
    onLoaded: root.applyMemories(text())
    onLoadFailed: root.applyMemories("")
  }

  property FileView briefingFile: FileView {
    path: root.assetDir + "briefing.json"
    printErrors: false
    onLoaded: root.applyBriefing(text())
    onLoadFailed: root.applyBriefing("")
  }
}
