import QtQuick
import "Hud.js" as Hud

// CASSETTE-FUTURISM: a moulded bezel with screws, a recessed screen, a label-maker strip for
// the title and an indicator lamp for the tag. Plastic is the theme foreground at low opacity.
Item {
  id: f
  TextMetrics { id: tmTitle; text: panel ? panel.title : ""; font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9.5 * f.u)); font.bold: true; font.letterSpacing: 1.6 * f.u; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real stripW: Math.min(width * 0.62, tmTitle.advanceWidth + Math.round(18 * u))
  readonly property real sx: Math.round(10 * u)
  readonly property real sy: Math.round(24 * u)
  readonly property real bodyX: sx + Math.round(8 * u)
  readonly property real bodyY: sy + Math.round(6 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(18 * u)

  Rectangle { anchors.fill: parent; radius: Math.round(9 * f.u); color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.11)
              border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.45) }
  Rectangle { x: 1; y: 1; width: parent.width - 2; height: parent.height - 2; radius: Math.round(8 * f.u); color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07) }
  // recessed screen
  Rectangle { x: f.sx; y: f.sy; width: f.width - 2 * f.sx; height: f.height - f.sy - Math.round(12 * f.u); radius: Math.round(4 * f.u)
              color: f.v ? Hud.rgba(f.v.bg, 0.88) : "#000"; border.width: 2; border.color: Qt.rgba(0, 0, 0, 0.45) }
  Rectangle { x: f.sx + 2; y: f.sy + 2; width: f.width - 2 * f.sx - 4; height: f.height - f.sy - Math.round(12 * f.u) - 4; radius: Math.round(3 * f.u); color: "transparent"; border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.12) }
  // screws
  Repeater { model: 4
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(8 * f.u); a: 0.5; slot: true
      x: (index % 2) ? f.width - width - Math.round(6 * f.u) : Math.round(6 * f.u)
      y: index > 1 ? f.height - height - Math.round(3 * f.u) : Math.round(6 * f.u) } }
  // label-maker strip
  Rectangle {
    x: Math.round(24 * f.u); y: Math.round(4 * f.u); height: Math.round(15 * f.u); radius: Math.round(3 * f.u)
    width: f.stripW; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.9)
    Text { textFormat: Text.PlainText; id: title; x: Math.round(9 * f.u); width: parent.width - Math.round(12 * f.u); height: parent.height; verticalAlignment: Text.AlignVCenter
           text: panel ? panel.title : ""; color: f.v ? f.v.bg : "#000"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9.5 * f.u)); font.bold: true; font.letterSpacing: 1.6 * f.u }
  }
  // lamp + tag
  Rectangle { anchors.right: parent.right; anchors.rightMargin: Math.round(26 * f.u); y: Math.round(7 * f.u); width: Math.round(8 * f.u); height: width; radius: width / 2
              color: f.v ? f.v.ok : "#5f5"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5)
              Rectangle { anchors.centerIn: parent; width: parent.width * 2.2; height: width; radius: width / 2; color: f.v ? Hud.rgba(f.v.ok, 0.22) : "#0f0"; z: -1 } }
  Text { textFormat: Text.PlainText;
    anchors.right: parent.right; anchors.rightMargin: Math.round(40 * f.u); y: Math.round(5 * f.u); height: Math.round(13 * f.u); verticalAlignment: Text.AlignVCenter
    width: Math.max(0, f.width - Math.round(24 * f.u) - f.stripW - Math.round(48 * f.u)); horizontalAlignment: Text.AlignRight
    text: panel ? panel.tag : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9 * f.u))
  }
}
