import QtQuick
import Quickshell
import qs.Commons
import "components"

// Remnic Recall bar chip: brain glyph plus the number of memories your agents
// captured today. Left-click opens the panel on Recall, right-click on Recent.
// A single accent pulse marks each new capture; a warning dot marks an engine
// that stopped answering.
Item {
  id: root

  // Injected by omarchy-shell.
  property var bar: null
  property string moduleName: "io.github.joshuaswarren.remnic"
  property var settings: ({})

  readonly property bool vertical: root.bar ? root.bar.vertical === true : false
  readonly property int barSize: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
  readonly property color foreground: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family

  readonly property string countLabel: client.todayCount > 99 ? "99+" : String(client.todayCount)
  readonly property bool showDot: client.mode === "offline" || (client.mode === "demo" && root.vertical)
  readonly property bool showBadge: client.mode === "demo" && !root.vertical
  readonly property string tooltipLabel: "Remnic Recall \u00b7 " + (client.mode === "offline"
    ? client.healthLine
    : root.countLabel + " today \u00b7 " + client.healthLine)

  // Bar.qml paints a tooltip only while its target reports the pointer itself.
  readonly property bool tooltipHovered: mouse.containsMouse

  // 0 at rest, 1 at the top of a capture pulse. One value drives scale,
  // brightness, and the accent tint so the whole chip animates together.
  property real pulse: 0
  readonly property color tinted: Qt.tint(root.foreground,
    Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, root.pulse))

  implicitWidth: root.vertical ? root.barSize : layout.implicitWidth + Style.spacing.controlPaddingX * 2
  implicitHeight: root.vertical ? layout.implicitHeight + Style.spacing.controlPaddingY * 2 : root.barSize

  RemnicClient {
    id: client
    settings: root.settings
    onNewMemories: function() { pulseAnimation.restart() }
  }

  SequentialAnimation {
    id: pulseAnimation
    NumberAnimation { target: root; property: "pulse"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "pulse"; to: 0; duration: 450; easing.type: Easing.InOutCubic }
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: mouse.containsPress
      ? Style.pressedFillFor(root.foreground, Color.accent, Color.urgent)
      : (mouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent, Color.urgent) : "transparent")

    // One positioner for both orientations: a single row on a horizontal bar,
    // glyph stacked over count on a vertical one. The demo badge is a third
    // cell that the positioner drops when it is hidden.
    Grid {
      id: layout
      anchors.centerIn: parent
      columns: root.vertical ? 1 : 3
      columnSpacing: Style.spacing.xs
      rowSpacing: 0
      horizontalItemAlignment: Grid.AlignHCenter
      verticalItemAlignment: Grid.AlignVCenter
      scale: 1 + root.pulse * 0.18
      opacity: 0.85 + root.pulse * 0.15

      Text {
        id: glyphText
        text: "󰧑"
        color: root.tinted
        font.family: root.fontFamily
        font.pixelSize: Style.bar.iconFont

        // Child of the glyph so it can anchor to it; Text ignores children when
        // it reports its implicit size, so the positioner layout is unaffected.
        Rectangle {
          visible: root.showDot
          width: Style.space(4)
          height: width
          radius: width / 2
          color: client.mode === "offline" ? Color.urgent : Color.accent
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.rightMargin: -Style.space(1)
          anchors.topMargin: Style.space(1)
        }
      }

      Text {
        text: root.countLabel
        color: root.tinted
        font.family: root.fontFamily
        font.pixelSize: root.vertical ? Style.font.caption : Style.font.bodySmall
      }

      Text {
        visible: root.showBadge
        text: "demo"
        color: Color.accent
        opacity: 0.8
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipLabel)
      onExited: if (root.bar) root.bar.hideTooltip(root)
      onClicked: function(event) {
        if (root.bar) root.bar.hideTooltip(root)
        root.togglePanel(event.button === Qt.RightButton ? "recent" : "recall")
      }
    }
  }

  // The panel owns its own window, so it needs the chip's bar edge and screen
  // position to open adjacent to the chip instead of centred on the bar.
  function anchorInfo() {
    if (!root.bar) return null
    var info = ({})
    var edge = String(root.bar.position || "")
    if (edge !== "") info.edge = edge
    var window = root.QsWindow ? root.QsWindow.window : null
    if (window && window.screen && typeof root.bar.windowScreenPoint === "function") {
      var point = root.bar.windowScreenPoint(root.mapToItem(null, root.width / 2, root.height / 2), window)
      info.x = Math.round(point.x)
      info.y = Math.round(point.y)
    }
    return (info.edge !== undefined || info.x !== undefined) ? info : null
  }

  function togglePanel(tab) {
    if (!root.bar || typeof root.bar.run !== "function") return
    var payload = { tab: tab }
    var anchor = anchorInfo()
    if (anchor !== null) payload.anchor = anchor
    // bar.run hands this string to a shell and the payload is single-quoted
    // there, so a stray apostrophe would end the quoting. Nothing that can
    // legitimately appear in the payload contains one.
    var json = JSON.stringify(payload).replace(/'/g, "")
    root.bar.run("omarchy-shell shell toggle io.github.joshuaswarren.remnic '" + json + "'")
  }
}
