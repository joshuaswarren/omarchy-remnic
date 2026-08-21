import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"

// Remnic Recall panel: recall search, recent memories, and the daily briefing.
// Hosted by omarchy-shell; summoned with
//   omarchy-shell shell toggle io.github.joshuaswarren.remnic '<payload>'
// Payload: { tab: "recall"|"recent"|"briefing", query, anchor: { edge, x, y } }
Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property var shell: null
  property var manifest: null

  // The host reads `opened` to decide whether `toggle` summons or hides, so
  // this stays truthful even when the panel dismisses itself.
  property bool opened: false

  readonly property string pluginId: "io.github.joshuaswarren.remnic"
  readonly property int maxResults: 20

  // ------------------------------------------------------------- geometry
  readonly property int contentWidth: Style.space(480)
  readonly property int gap: Style.gapsOut
  readonly property int margin: Style.gapsOut
  readonly property int padding: Style.spacing.popupPadding
  readonly property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
    Math.max(1, Style.space(2)))

  readonly property real screenW: window.screen ? window.screen.width : 0
  readonly property real screenH: window.screen ? window.screen.height : 0

  readonly property int cardWidth: root.contentWidth + root.padding * 2
    + Border.left(root.borderSpec) + Border.right(root.borderSpec)
  readonly property int cardHeight: body.implicitHeight + root.padding * 2
    + Border.top(root.borderSpec) + Border.bottom(root.borderSpec)

  // The tab body keeps one height across tabs so switching never resizes the
  // window. `chrome` is a static allowance for header + tabs + footer; measuring
  // them instead would make the body's height depend on the column that
  // contains it.
  readonly property int contentAreaHeight: {
    var chrome = Style.space(150)
    var available = root.screenH > 0
      ? root.screenH - root.barSize - root.gap - root.margin * 2 - chrome
      : 0
    if (available <= 0) return Style.space(360)
    return Math.max(Style.space(160), Math.min(Style.space(360), Math.round(available)))
  }

  // The chip reports the bar edge and its own position so the panel opens
  // beside it. IPC deep-links carry no anchor and center on the bar instead.
  property string anchorEdge: ""
  property real anchorAlong: -1

  readonly property string barEdge: {
    if (root.anchorEdge !== "") return root.anchorEdge
    if (root.shell && root.shell.bar && root.shell.bar.position) return String(root.shell.bar.position)
    return "top"
  }
  readonly property bool barVertical: root.barEdge === "left" || root.barEdge === "right"
  readonly property int barSize: root.shell && root.shell.bar && root.shell.bar.barSize > 0
    ? root.shell.bar.barSize
    : (root.barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal)

  readonly property point cardOrigin: {
    var w = root.screenW
    var h = root.screenH
    var cw = root.cardWidth
    var ch = root.cardHeight
    if (w <= 0 || h <= 0) return Qt.point(root.margin, root.margin)

    var along = root.anchorAlong
    var x = 0
    var y = 0
    if (root.barEdge === "bottom") {
      x = (along >= 0 ? along : w / 2) - cw / 2
      y = h - root.barSize - root.gap - ch
    } else if (root.barEdge === "left") {
      x = root.barSize + root.gap
      y = (along >= 0 ? along : h / 2) - ch / 2
    } else if (root.barEdge === "right") {
      x = w - root.barSize - root.gap - cw
      y = (along >= 0 ? along : h / 2) - ch / 2
    } else {
      x = (along >= 0 ? along : w / 2) - cw / 2
      y = root.barSize + root.gap
    }
    x = Math.max(root.margin, Math.min(x, w - cw - root.margin))
    y = Math.max(root.margin, Math.min(y, h - ch - root.margin))
    return Qt.point(Math.round(x), Math.round(y))
  }

  // ------------------------------------------------------------- engine
  PanelSettings { id: panelSettings }

  RemnicClient {
    id: client
    settings: panelSettings.value
  }

  readonly property bool offline: client.mode === "offline"
  readonly property bool connecting: client.mode === "connecting"
  // Blocks tab content: the offline card or the connecting spinner owns the area.
  readonly property bool blocking: offline || connecting
  readonly property int recentLimit: {
    var configured = Number(panelSettings.value ? panelSettings.value.recentLimit : NaN)
    return (isFinite(configured) && configured > 0) ? Math.round(configured) : 30
  }
  readonly property string footerLine: {
    var line = String(client.healthLine || "")
    var ns = String(client.namespace || "")
    if (ns !== "") line = line === "" ? "ns " + ns : line + " · ns " + ns
    return line
  }
  readonly property var headerBadges: {
    var out = []
    if (client.mode === "demo") out.push({ label: "DEMO", tone: "accent" })
    else if (client.mode === "offline") out.push({ label: "OFFLINE", tone: "urgent" })
    var ns = String(client.namespace || "")
    if (ns !== "") out.push({ label: ns, tone: "muted" })
    return out
  }

  function badgeColor(tone) {
    if (tone === "urgent") return Color.urgent
    if (tone === "accent") return Color.accent
    return Qt.darker(Color.popups.text, 1.35)
  }

  // ------------------------------------------------------------- clock
  //
  // Relative times re-read this instead of Date.now() so a panel left open
  // keeps telling the truth, and every row moves on the same tick.
  property double nowMs: Date.now()

  Timer {
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.nowMs = Date.now()
  }

  readonly property double midnightMs: {
    var day = new Date(root.nowMs)
    day.setHours(0, 0, 0, 0)
    return day.getTime()
  }

  function relTime(iso) {
    var ms = new Date(String(iso || "")).getTime()
    if (!isFinite(ms)) return ""
    var seconds = Math.max(0, Math.round((root.nowMs - ms) / 1000))
    if (seconds < 45) return "just now"
    var minutes = Math.max(1, Math.floor(seconds / 60))
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.max(1, Math.floor(minutes / 60))
    if (hours < 24) return hours + "h ago"
    var days = Math.max(1, Math.floor(hours / 24))
    if (days < 30) return days + "d ago"
    return Math.max(1, Math.floor(days / 30)) + "mo ago"
  }

  // ------------------------------------------------------------- tabs
  property string tab: "recall"

  // Live mode drops the Briefing tab once the engine has told us it has no
  // briefing command; demo mode always has one.
  property bool briefingProbed: false
  property bool briefingAvailable: true
  readonly property bool briefingTabVisible: client.mode === "demo" || !root.briefingProbed || root.briefingAvailable

  readonly property var tabModel: {
    var out = [{ key: "recall", label: "Recall" }, { key: "recent", label: "Recent" }]
    if (root.briefingTabVisible) out.push({ key: "briefing", label: "Briefing" })
    return out
  }

  function showTab(key) {
    var next = String(key || "")
    var model = root.tabModel
    var known = false
    for (var i = 0; i < model.length; i++) if (model[i].key === next) known = true
    if (!known) return

    root.tab = next
    root.expandedId = ""
    root.selectedIndex = root.activeRows.length > 0 ? 0 : -1

    if (next === "recall") {
      Qt.callLater(root.focusSearch)
      return
    }
    keyNav.forceActiveFocus()
    if (next === "briefing" && root.briefing === null && !root.briefingPending) root.loadBriefing()
  }

  function cycleTab(direction) {
    var model = root.tabModel
    var index = 0
    for (var i = 0; i < model.length; i++) if (model[i].key === root.tab) index = i
    var next = ((index + direction) % model.length + model.length) % model.length
    root.showTab(model[next].key)
  }

  // ------------------------------------------------------------- recall
  property string query: ""
  property var results: []
  property bool searching: false
  // Bumped on every query change so a slow response for an abandoned query
  // cannot overwrite the current results.
  property int searchSerial: 0
  property bool searchFailed: false

  Timer {
    id: searchDebounce
    interval: 300
    onTriggered: root.runSearch()
  }

  function queueSearch(text) {
    root.query = String(text || "")
    if (root.query.trim().length < 3) {
      searchDebounce.stop()
      root.searchSerial++
      root.searching = false
      root.searchFailed = false
      root.results = []
      root.selectedIndex = -1
      root.expandedId = ""
      return
    }
    searchDebounce.restart()
  }

  function runSearch() {
    searchDebounce.stop()
    var trimmed = root.query.trim()
    if (trimmed.length < 3) return

    // A search fired while the client is still settling would race the first
    // poll on the daemon; park it and re-run when the mode resolves.
    if (client.mode === "connecting") {
      root.searching = true
      root.pendingSearch = true
      return
    }
    root.pendingSearch = false

    root.searching = true
    var serial = ++root.searchSerial
    client.search(trimmed, function(rows, ok) {
      if (serial !== root.searchSerial) return
      root.searching = false
      root.searchFailed = ok === false
      root.results = Array.isArray(rows) ? rows.slice(0, root.maxResults) : []
      root.selectedIndex = root.results.length > 0 ? 0 : -1
      root.expandedId = ""
    })
  }

  property bool pendingSearch: false

  Connections {
    target: client
    function onModeChanged() {
      if (!root.pendingSearch) return
      if (client.mode === "connecting") return
      if (client.mode === "offline") {
        root.pendingSearch = false
        root.searching = false
        root.searchFailed = true
        return
      }
      root.runSearch()
    }
  }

  function focusSearch() {
    if (!root.opened || root.tab !== "recall" || root.offline) return
    searchField.forceActiveFocus()
  }

  // ------------------------------------------------------------- recent
  readonly property var recentItems: {
    var list = client.recent
    if (!Array.isArray(list)) return []
    return list.slice(0, root.recentLimit)
  }

  // First row that is no longer from today; -1 when every row is. Drives the
  // "Today" / "Earlier" section headers.
  readonly property int earlierStart: {
    var items = root.recentItems
    for (var i = 0; i < items.length; i++) {
      var ms = new Date(String(items[i] ? items[i].created : "")).getTime()
      if (!isFinite(ms) || ms < root.midnightMs) return i
    }
    return -1
  }

  // ------------------------------------------------------------- briefing
  property var briefing: null
  property bool briefingPending: false
  readonly property string briefingMarkdown: root.briefing ? String(root.briefing.markdown || "") : ""

  function loadBriefing() {
    if (root.briefingPending) return
    root.briefingPending = true
    client.fetchBriefing(function(result) {
      root.briefingPending = false
      root.briefingProbed = true
      root.briefing = result || null
      root.briefingAvailable = !!(result && result.available)
      if (!root.briefingAvailable && root.tab === "briefing") root.showTab("recall")
    })
  }

  function scrollBriefing(direction) {
    var limit = Math.max(0, briefingFlick.contentHeight - briefingFlick.height)
    var next = briefingFlick.contentY + direction * Style.space(48)
    briefingFlick.contentY = Math.max(0, Math.min(limit, next))
  }

  // ------------------------------------------------------------- selection
  property int selectedIndex: -1
  property string expandedId: ""

  readonly property var activeRows: root.tab === "recall"
    ? root.results
    : (root.tab === "recent" ? root.recentItems : [])

  function selectedRow() {
    var rows = root.activeRows
    if (root.selectedIndex < 0 || root.selectedIndex >= rows.length) return null
    return rows[root.selectedIndex]
  }

  function moveSelection(delta) {
    var rows = root.activeRows
    if (rows.length === 0) {
      root.selectedIndex = -1
      return
    }
    var next = root.selectedIndex < 0
      ? (delta > 0 ? 0 : rows.length - 1)
      : root.selectedIndex + delta
    root.selectedIndex = Math.max(0, Math.min(rows.length - 1, next))
    if (root.tab === "recall") resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    else if (root.tab === "recent") recentList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function setExpanded(expand) {
    var row = root.selectedRow()
    if (!row) return
    var id = String(row.id || "")
    root.expandedId = expand ? id : (root.expandedId === id ? "" : root.expandedId)
  }

  function activateRow(index) {
    if (index !== root.selectedIndex) {
      root.selectedIndex = index
      return
    }
    var row = root.selectedRow()
    var id = row ? String(row.id || "") : ""
    root.expandedId = root.expandedId === id ? "" : id
  }

  // ------------------------------------------------------------- clipboard
  property bool copied: false

  Timer {
    id: copyToastTimer
    interval: 1500
    onTriggered: root.copied = false
  }

  function copySelected() {
    var row = root.selectedRow()
    if (!row) return
    var text = String(row.summary || "")
    if (text === "" || copyProcess.running) return

    copyProcess.payload = text
    // stdinEnabled is read when the process starts, so re-arm it before every
    // copy — the previous run closed the channel to commit the paste.
    copyProcess.stdinEnabled = true
    copyProcess.running = true
    root.copied = true
    copyToastTimer.restart()
  }

  // The only subprocess in the panel. Memory text goes to stdin, never argv,
  // and only on an explicit Enter (DESIGN.md security invariant 1).
  Process {
    id: copyProcess

    property string payload: ""

    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      copyProcess.write(copyProcess.payload)
      // wl-copy reads until EOF; closing stdin is what commits the copy.
      copyProcess.stdinEnabled = false
    }
  }

  // ------------------------------------------------------------- lifecycle
  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(String(payloadJson || "") || "{}") } catch (e) { payload = ({}) }
    if (payload === null || typeof payload !== "object") payload = ({})

    if (payload.anchor && typeof payload.anchor === "object") {
      var edge = String(payload.anchor.edge || "")
      if (edge === "top" || edge === "bottom" || edge === "left" || edge === "right") root.anchorEdge = edge
      // The chip's coordinates are local to its own screen, so the window
      // must map on that screen or the clamp math lands on the wrong output.
      var screenName = String(payload.anchor.screen || "")
      if (screenName !== "") {
        for (var s = 0; s < Quickshell.screens.length; s++) {
          if (Quickshell.screens[s].name === screenName) { window.screen = Quickshell.screens[s]; break }
        }
      }
      // The chip sends both screen coordinates; which one runs along the bar
      // depends on the edge.
      var along = Number(root.barVertical ? payload.anchor.y : payload.anchor.x)
      root.anchorAlong = isFinite(along) ? along : -1
    }

    root.nowMs = Date.now()
    root.opened = true

    if (payload.tab !== undefined) root.showTab(String(payload.tab || ""))

    if (payload.query !== undefined) {
      root.showTab("recall")
      searchField.text = String(payload.query || "")
      // Assigning text arms the as-you-type debounce; stop it so the
      // deep-linked query runs exactly once, immediately.
      searchDebounce.stop()
      root.runSearch()
    }

    if (root.tab === "recall") Qt.callLater(root.focusSearch)
  }

  function close() {
    root.opened = false
    searchDebounce.stop()
    root.copied = false
  }

  // Esc and outside-click release the host's open state too, so it does not
  // keep a hidden panel it still believes is up.
  //
  // Deferred on purpose: without `keepLoaded` in the manifest, shell.hide()
  // deactivates this plugin's Loader and destroys the component. Doing that
  // from inside a key handler would delete the object whose function is still
  // on the stack.
  function dismiss() {
    root.close()
    Qt.callLater(root.releaseHost)
  }

  function releaseHost() {
    if (root.opened) return
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || root.pluginId)
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.dismiss()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      root.cycleTab((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
      var step = event.key === Qt.Key_Down ? 1 : -1
      if (root.tab === "briefing") root.scrollBriefing(step)
      else root.moveSelection(step)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Right) {
      // In the search field the caret has first claim; expansion only takes
      // over once the caret has nowhere left to go.
      if (searchField.activeFocus && searchField.cursorPosition < searchField.text.length) return
      root.setExpanded(true)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Left) {
      if (searchField.activeFocus && searchField.cursorPosition > 0) return
      root.setExpanded(false)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.copySelected()
      event.accepted = true
      return
    }
  }

  // ------------------------------------------------------------- lock guard
  //
  // Third-party pattern (as in hancore.bongocat): read the first-party lock
  // service so a panel full of memory text can never map over the lock screen.
  // `shell` arrives after Component.onCompleted and the service registers
  // lazily, so resolve on a timer until it appears.
  property var lockService: null
  readonly property bool sessionLocked: root.lockService !== null && root.lockService.locked === true

  Timer {
    id: lockServiceResolve
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      if (root.lockService !== null) {
        lockServiceResolve.stop()
        return
      }
      if (root.shell && typeof root.shell.serviceFor === "function") {
        var service = root.shell.serviceFor("omarchy.lock")
        if (service !== null && service !== undefined) root.lockService = service
      }
    }
  }

  // ------------------------------------------------------------- focus prime
  //
  // Layer-shell grants focus when the surface maps under OnDemand, but not when
  // an already-mapped surface flips back to it. A brief Exclusive prime covers
  // both, so a keyboard-summoned panel types immediately; OnDemand then releases
  // compositor-wide pointer capture. Copied from qs.Ui.KeyboardPanel, which
  // cannot be reused here because it requires a bar reference this standalone
  // panel does not have.
  property bool focusPrimed: false

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  function beginFocusPrime() {
    if (root.opened && window.backingWindowVisible) focusPrimeTimer.restart()
  }

  onOpenedChanged: {
    if (root.opened) {
      root.focusPrimed = false
      root.beginFocusPrime()
      Qt.callLater(function() {
        if (!root.opened) return
        if (root.tab === "recall") root.focusSearch()
        else keyNav.forceActiveFocus()
      })
    } else {
      focusPrimeTimer.stop()
      root.focusPrimed = false
    }
  }

  // ------------------------------------------------------------- window
  PanelWindow {
    id: window

    visible: root.opened && !root.sessionLocked
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-remnic-panel"
    WlrLayershell.layer: WlrLayer.Top
    // Follows `opened`, not `visible`: ownership must release the moment the
    // logical close fires.
    WlrLayershell.keyboardFocus: root.opened
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    onBackingWindowVisibleChanged: root.beginFocusPrime()

    // Full-screen surface with the card placed inside at `cardOrigin`; the
    // uncovered area is what makes outside-click dismissal work.
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      acceptedButtons: Qt.AllButtons
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card

      x: root.cardOrigin.x
      y: root.cardOrigin.y
      width: root.cardWidth
      height: root.cardHeight
      color: Color.popups.background
      borderSpec: root.borderSpec
      padding: root.padding
      radius: Style.cornerRadius
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.97

      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      // Swallow clicks on the card so they never reach the dismissal area.
      // Declared first so every control below sits above it.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Item {
        id: keyNav

        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        // Sees keys the focused search field did not consume, and is the focus
        // holder on the tabs that have no editor.
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handleKey(event) }

        Column {
          id: body

          width: parent.width
          spacing: Style.spacing.md

          // ---------------------------------------------------------- header
          Item {
            width: parent.width
            height: Math.max(titleRow.implicitHeight, refreshButton.implicitHeight)

            Row {
              id: titleRow

              anchors.left: parent.left
              anchors.right: refreshButton.left
              anchors.rightMargin: Style.spacing.controlGap
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.controlGap

              Text {
                text: "Remnic Recall"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Repeater {
                model: root.headerBadges

                delegate: Rectangle {
                  id: badge

                  required property var modelData

                  readonly property color tint: root.badgeColor(String(modelData.tone || ""))

                  width: badgeLabel.implicitWidth + Style.spacing.md * 2
                  height: badgeLabel.implicitHeight + Style.spacing.xxs * 2
                  radius: Style.cornerRadius > 0 ? Style.cornerRadius : Math.round(height / 2)
                  color: Style.selectedFillFor(badge.tint, badge.tint)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    id: badgeLabel

                    anchors.centerIn: parent
                    text: String(badge.modelData.label || "")
                    textFormat: Text.PlainText
                    color: badge.tint
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }

            Button {
              id: refreshButton

              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑐"
              tooltipText: "Refresh"
              onClicked: client.refresh()
            }
          }

          PanelSeparator { width: parent.width }

          // ---------------------------------------------------------- tabs
          TabBar {
            width: parent.width
            visible: !root.offline
            tabs: root.tabModel
            current: root.tab
            onSelected: function(key) { root.showTab(key) }
          }

          // ---------------------------------------------------------- content
          Item {
            width: parent.width
            height: root.contentAreaHeight
            clip: true

            // -- offline card -------------------------------------------------
            Column {
              anchors.centerIn: parent
              width: parent.width - Style.spacing.panelPadding * 2
              visible: root.offline
              spacing: Style.spacing.md

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰅙"
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.displayLarge
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Remnic engine unreachable"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                text: String(client.healthLine || "")
                textFormat: Text.PlainText
                color: Qt.darker(Color.popups.text, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: doctorHint.implicitWidth + Style.spacing.xl * 2
                height: doctorHint.implicitHeight + Style.spacing.sm * 2
                radius: Style.cornerRadius
                color: Style.normalFillFor(Color.popups.text, Color.accent)

                Text {
                  id: doctorHint

                  anchors.centerIn: parent
                  text: "remnic doctor"
                  color: Qt.darker(Color.popups.text, 1.2)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Retry"
                bordered: true
                onClicked: client.refresh()
              }
            }

            // -- connecting card ----------------------------------------------
            Column {
              anchors.centerIn: parent
              width: parent.width - Style.spacing.panelPadding * 2
              visible: root.connecting
              spacing: Style.spacing.md

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰑐"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.displayLarge

                RotationAnimation on rotation {
                  from: 0
                  to: 360
                  duration: 1200
                  loops: Animation.Infinite
                  running: root.connecting && root.opened
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Connecting to Remnic\u2026"
                color: Qt.darker(Color.popups.text, 1.2)
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
              }
            }

            // -- recall -------------------------------------------------------
            Column {
              anchors.fill: parent
              visible: root.tab === "recall" && !root.blocking
              spacing: Style.spacing.md

              TextField {
                id: searchField

                width: parent.width
                placeholderText: "Search your agents' memory…"
                // Priority BeforeItem so Tab, Enter, and the arrow keys reach
                // the panel's key map before TextInput's own handling.
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { root.handleKey(event) }
                onTextChanged: root.queueSearch(text)
              }

              Item {
                width: parent.width
                height: parent.height - searchField.height - parent.spacing

                Column {
                  anchors.centerIn: parent
                  spacing: Style.spacing.md
                  visible: root.query.trim().length < 3 && !root.searching

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰧑"
                    color: Style.selectedFillFor(Color.popups.text, Color.accent)
                    font.family: Style.font.family
                    font.pixelSize: Style.space(56)
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Type to recall"
                    color: Qt.darker(Color.popups.text, 1.5)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                }

                Text {
                  anchors.centerIn: parent
                  visible: root.searching
                  text: "󰑐"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.display
                  transformOrigin: Item.Center

                  RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.searching
                  }
                }

                Text {
                  anchors.centerIn: parent
                  visible: !root.searching && root.query.trim().length >= 3 && root.results.length === 0
                  text: root.searchFailed ? "Search failed — the engine did not answer" : "No memories match"
                  color: Qt.darker(Color.popups.text, 1.5)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }

                ListView {
                  id: resultList

                  anchors.fill: parent
                  visible: !root.searching && root.results.length > 0
                  clip: true
                  spacing: Style.spacing.xxs
                  boundsBehavior: Flickable.StopAtBounds
                  model: root.tab === "recall" ? root.results : []
                  currentIndex: root.selectedIndex

                  delegate: MemoryRow {
                    required property var modelData
                    required property int index

                    width: resultList.width
                    memory: modelData
                    timeText: root.relTime(modelData ? modelData.created : "")
                    selected: index === root.selectedIndex
                    expanded: root.expandedId !== "" && modelData
                      && String(modelData.id || "") === root.expandedId
                    onClicked: root.activateRow(index)
                  }
                }
              }
            }

            // -- recent -------------------------------------------------------
            Item {
              anchors.fill: parent
              visible: root.tab === "recent" && !root.blocking

              Text {
                anchors.centerIn: parent
                visible: root.recentItems.length === 0
                text: "No memories captured yet"
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              ListView {
                id: recentList

                anchors.fill: parent
                visible: root.recentItems.length > 0
                clip: true
                spacing: Style.spacing.xxs
                boundsBehavior: Flickable.StopAtBounds
                model: root.tab === "recent" ? root.recentItems : []
                currentIndex: root.selectedIndex

                delegate: Column {
                  id: recentEntry

                  required property var modelData
                  required property int index

                  readonly property bool earlier: root.earlierStart >= 0 && index >= root.earlierStart

                  width: recentList.width
                  spacing: Style.spacing.xs

                  PanelSectionHeader {
                    visible: recentEntry.index === 0 || recentEntry.index === root.earlierStart
                    text: recentEntry.earlier ? "Earlier" : "Today"
                    leftPadding: Style.spacing.rowPaddingX
                    // Keeps the glyph-overshoot reserve PanelSectionHeader adds
                    // while spacing a mid-list header off the row above it.
                    topPadding: (recentEntry.index === 0 ? 0 : Style.spacing.lg)
                      + Math.ceil(Style.font.caption * 0.15)
                  }

                  MemoryRow {
                    width: parent.width
                    memory: recentEntry.modelData
                    timeText: root.relTime(recentEntry.modelData ? recentEntry.modelData.created : "")
                    selected: recentEntry.index === root.selectedIndex
                    expanded: root.expandedId !== "" && recentEntry.modelData
                      && String(recentEntry.modelData.id || "") === root.expandedId
                    onClicked: root.activateRow(recentEntry.index)
                  }
                }
              }
            }

            // -- briefing -----------------------------------------------------
            Item {
              anchors.fill: parent
              visible: root.tab === "briefing" && !root.blocking

              Flickable {
                id: briefingFlick

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: briefingFooter.top
                anchors.bottomMargin: Style.spacing.md
                visible: root.briefingMarkdown !== ""
                clip: true
                contentWidth: width
                contentHeight: briefingText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Text {
                  id: briefingText

                  width: briefingFlick.width
                  text: root.briefingMarkdown
                  // The briefing is engine-generated prose, not memory content,
                  // so rendering its markdown carries no injection surface.
                  // Memory rows stay on PlainText.
                  textFormat: Text.MarkdownText
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }
              }

              Text {
                anchors.centerIn: parent
                visible: root.briefingPending && root.briefingMarkdown === ""
                text: "󰑐"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.display
                transformOrigin: Item.Center

                RotationAnimation on rotation {
                  from: 0
                  to: 360
                  duration: 900
                  loops: Animation.Infinite
                  running: root.briefingPending
                }
              }

              Text {
                anchors.centerIn: parent
                width: parent.width - Style.spacing.panelPadding * 2
                visible: !root.briefingPending && root.briefingMarkdown === ""
                text: root.briefingProbed
                  ? "No briefing available. Try remnic briefing from a terminal."
                  : "Loading the briefing…"
                textFormat: Text.PlainText
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }

              Item {
                id: briefingFooter

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(briefingStamp.implicitHeight, briefingRefresh.implicitHeight)

                Text {
                  id: briefingStamp

                  anchors.left: parent.left
                  anchors.right: briefingRefresh.left
                  anchors.rightMargin: Style.spacing.controlGap
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    if (!root.briefing) return ""
                    var stamp = root.relTime(root.briefing.generatedAt)
                    return stamp === "" ? "" : "Generated " + stamp
                  }
                  textFormat: Text.PlainText
                  color: Qt.darker(Color.popups.text, 1.5)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Button {
                  id: briefingRefresh

                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "󰑐"
                  text: "Refresh"
                  fontSize: Style.font.caption
                  iconSpinning: root.briefingPending
                  onClicked: root.loadBriefing()
                }
              }
            }
          }

          PanelSeparator { width: parent.width }

          // ---------------------------------------------------------- footer
          Item {
            width: parent.width
            height: Math.max(healthLabel.implicitHeight, demoChip.height)

            Text {
              id: healthLabel

              anchors.left: parent.left
              anchors.right: demoChip.visible ? demoChip.left : parent.right
              anchors.rightMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              text: root.footerLine
              textFormat: Text.PlainText
              color: Qt.darker(Color.popups.text, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Rectangle {
              id: demoChip

              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: client.mode === "demo"
              width: demoLabel.implicitWidth + Style.spacing.md * 2
              height: demoLabel.implicitHeight + Style.spacing.xxs * 2
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : Math.round(height / 2)
              color: Style.normalFillFor(Color.accent, Color.accent)

              Text {
                id: demoLabel

                anchors.centerIn: parent
                text: "DEMO DATA"
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.7)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }
      }

      // ---------------------------------------------------------- copy toast
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: card.contentBottomInset + Style.spacing.xxxl
        width: copyToastRow.implicitWidth + Style.spacing.xl * 2
        height: copyToastRow.implicitHeight + Style.spacing.md * 2
        radius: Style.cornerRadius
        color: Style.selectedFillFor(Color.accent, Color.accent)
        opacity: root.copied ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Row {
          id: copyToastRow

          anchors.centerIn: parent
          spacing: Style.spacing.sm

          Text {
            text: "󰆏"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "Copied"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
