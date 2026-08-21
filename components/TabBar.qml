import QtQuick
import qs.Commons

// Recall | Recent | Briefing. Equal-width text tabs with an accent underline
// on the active one. The panel owns `current` and the Tab-key cycling; this
// component only reports clicks so both input paths stay in one state machine.
Item {
  id: root

  // [{ key, label }] — the panel drops the Briefing entry when the engine
  // has no briefing command, so the tab count is not fixed at three.
  property var tabs: []
  property string current: ""
  property color foreground: Color.popups.text
  property color accent: Color.accent

  signal selected(string key)

  readonly property int count: tabs ? tabs.length : 0
  readonly property int underline: Math.max(1, Style.space(2))

  implicitHeight: Style.spacing.controlHeight + underline
  height: implicitHeight

  // Tile the row on integer boundaries instead of rounding each tab to the
  // same width: equal rounding leaves a seam of unclaimed pixels on the right.
  function edgeAt(index) {
    return root.count > 0 ? Math.round(root.width * index / root.count) : 0
  }

  Row {
    anchors.fill: parent
    spacing: 0

    Repeater {
      model: root.tabs

      delegate: Item {
        id: tab

        required property var modelData
        required property int index

        readonly property bool active: root.current === modelData.key

        width: root.edgeAt(index + 1) - root.edgeAt(index)
        height: root.height

        Rectangle {
          anchors.fill: parent
          anchors.bottomMargin: root.underline
          color: tab.active
            ? Style.selectedFillFor(root.foreground, root.accent)
            : (tabMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
          radius: Style.cornerRadius

          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -Math.round(root.underline / 2)
          text: String(tab.modelData.label || "")
          color: tab.active ? root.accent : Qt.darker(root.foreground, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: tab.active
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.round(tab.width * 0.6)
          height: root.underline
          color: root.accent
          opacity: tab.active ? 1 : 0

          Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.selected(String(tab.modelData.key || ""))
        }
      }
    }
  }
}
