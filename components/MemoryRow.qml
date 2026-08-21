import QtQuick
import qs.Commons

// One memory: summary, source badge, relative time. Collapsed
// it shows two elided lines; expanded it shows the whole summary plus tags.
//
// Every Text carrying memory content pins textFormat to PlainText. Memory text
// is captured from arbitrary sources, and Qt's default StyledText would let a
// stray tag re-style the panel (DESIGN.md security invariant 4).
Item {
  id: root

  // { id, summary, source, created, tags, category }
  property var memory: null
  // Rendered by the panel so one relTime() implementation serves rows and the
  // briefing footer alike, and so every row re-reads the clock together.
  property string timeText: ""
  property bool selected: false
  property bool expanded: false
  property color foreground: Color.popups.text
  property color accent: Color.accent

  signal clicked()

  readonly property string summary: memory ? String(memory.summary || "") : ""
  readonly property string source: memory ? String(memory.source || "") : ""
  readonly property var allTags: memory && Array.isArray(memory.tags) ? memory.tags : []
  // The daemon supplies these; a pathological memory with thousands of tags
  // would otherwise build thousands of delegates and stall the shell.
  readonly property int maxTagsShown: 8
  readonly property var tags: allTags.length > maxTagsShown ? allTags.slice(0, maxTagsShown) : allTags
  readonly property int hiddenTagCount: allTags.length - tags.length

  // Badge and tag strings size their own chips, so a very long one would drive
  // the row's geometry. Clamp what is drawn; the full text lives in the summary.
  function clampLabel(text, limit) {
    var value = String(text)
    return value.length > limit ? value.substring(0, limit) + "\u2026" : value
  }

  implicitHeight: layout.implicitHeight + Style.spacing.controlPaddingY * 2
  height: implicitHeight

  Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    color: root.selected
      ? Style.selectedFillFor(root.accent, root.accent)
      : (rowMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
    radius: Style.cornerRadius

    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Column {
    id: layout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Style.spacing.rowPaddingX
    anchors.rightMargin: Style.spacing.rowPaddingX
    anchors.topMargin: Style.spacing.controlPaddingY
    spacing: Style.spacing.xs

    Text {
      width: parent.width
      text: root.summary
      textFormat: Text.PlainText
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: root.selected
      wrapMode: Text.WordWrap
      elide: root.expanded ? Text.ElideNone : Text.ElideRight
      maximumLineCount: root.expanded ? 24 : 2
    }

    Row {
      spacing: Style.spacing.sm

      Rectangle {
        visible: root.source !== ""
        width: sourceLabel.implicitWidth + Style.spacing.sm * 2
        height: sourceLabel.implicitHeight + Style.spacing.xxs * 2
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Math.round(height / 2)
        color: Style.normalFillFor(root.accent, root.accent)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: sourceLabel
          anchors.centerIn: parent
          text: root.clampLabel(root.source, 18).toUpperCase()
          textFormat: Text.PlainText
          color: Qt.darker(root.foreground, 1.35)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        text: root.timeText
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Flow {
      width: parent.width
      visible: root.expanded && root.tags.length > 0
      spacing: Style.spacing.sm

      Repeater {
        model: root.expanded ? root.tags : []

        delegate: Text {
          required property var modelData

          text: "#" + root.clampLabel(modelData, 24)
          textFormat: Text.PlainText
          color: Qt.darker(root.foreground, 1.35)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        visible: root.hiddenTagCount > 0
        text: "+" + root.hiddenTagCount
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
