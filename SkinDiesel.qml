import QtQuick
import "Hud.js" as Hud

// DIESELPUNK: a bevelled steel plate with riveted edges and a stencilled data-plate tab.
// Steel is the theme background and foreground at partial opacity; shadows are neutral black.
Item {
  id: f
  TextMetrics { id: tmTitle; text: panel ? panel.title : ""; font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(9, Math.round(11 * f.u)); font.bold: true; font.letterSpacing: 3.4 * f.u; font.italic: false }
  TextMetrics { id: tmTag; text: panel ? panel.tag : ""; font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(8, Math.round(9 * f.u)); font.bold: true; font.letterSpacing: 1.2 * f.u; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real bodyX: Math.round(20 * u)
  readonly property real bodyY: Math.round(38 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(20 * u)
  readonly property real rs: Math.round(24 * u)              // rivet spacing
  readonly property real plateW: Math.min(width * 0.62, tmTitle.advanceWidth + Math.round(46 * u))

  Rectangle { anchors.fill: parent; radius: Math.round(2 * f.u); color: f.v ? Hud.rgba(f.v.bg, 0.72) : "#000"
              border.width: Math.max(2, Math.round(3 * f.u)); border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.42) }
  // bevel: light top/left, dark bottom/right
  Rectangle { x: Math.round(3 * f.u); y: Math.round(3 * f.u); width: f.width - Math.round(6 * f.u); height: 1; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.55) }
  Rectangle { x: Math.round(3 * f.u); y: Math.round(3 * f.u); width: 1; height: f.height - Math.round(6 * f.u); color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.4) }
  Rectangle { x: Math.round(3 * f.u); y: f.height - Math.round(4 * f.u); width: f.width - Math.round(6 * f.u); height: 1; color: Qt.rgba(0, 0, 0, 0.45) }
  Rectangle { x: f.width - Math.round(4 * f.u); y: Math.round(3 * f.u); width: 1; height: f.height - Math.round(6 * f.u); color: Qt.rgba(0, 0, 0, 0.45) }
  // rivets: bottom row, then the two sides
  Repeater { model: Math.max(2, Math.floor((f.width - Math.round(36 * f.u)) / f.rs) + 1)
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(6 * f.u); a: 0.6
      x: Math.round(18 * f.u) + index * ((f.width - Math.round(36 * f.u)) / Math.max(1, Math.floor((f.width - Math.round(36 * f.u)) / f.rs))) - d / 2
      y: f.height - Math.round(11 * f.u) } }
  Repeater { model: Math.max(2, Math.floor((f.height - Math.round(60 * f.u)) / f.rs) + 1)
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(6 * f.u); a: 0.6
      x: Math.round(6 * f.u)
      y: Math.round(40 * f.u) + index * ((f.height - Math.round(60 * f.u)) / Math.max(1, Math.floor((f.height - Math.round(60 * f.u)) / f.rs))) - d / 2 } }
  Repeater { model: Math.max(2, Math.floor((f.height - Math.round(60 * f.u)) / f.rs) + 1)
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(6 * f.u); a: 0.6
      x: f.width - Math.round(12 * f.u)
      y: Math.round(40 * f.u) + index * ((f.height - Math.round(60 * f.u)) / Math.max(1, Math.floor((f.height - Math.round(60 * f.u)) / f.rs))) - d / 2 } }
  // stencilled data plate
  Rectangle {
    x: Math.round(14 * f.u); y: Math.round(7 * f.u); width: f.plateW; height: Math.round(23 * f.u); radius: Math.round(3 * f.u)
    color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.9)
    Rectangle { x: Math.round(5 * f.u); anchors.verticalCenter: parent.verticalCenter; width: Math.round(5 * f.u); height: width; radius: width / 2; color: f.v ? f.v.bg : "#000" }
    Rectangle { x: parent.width - width - Math.round(5 * f.u); anchors.verticalCenter: parent.verticalCenter; width: Math.round(5 * f.u); height: width; radius: width / 2; color: f.v ? f.v.bg : "#000" }
    Text { textFormat: Text.PlainText; id: title; x: Math.round(16 * f.u); width: parent.width - Math.round(32 * f.u); height: parent.height; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
           text: panel ? panel.title : ""; color: f.v ? f.v.bg : "#000"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(9, Math.round(11 * f.u)); font.bold: true; font.letterSpacing: 3.4 * f.u }
  }
  Rectangle { visible: tmTag.text !== ""; anchors.right: parent.right; anchors.rightMargin: Math.round(16 * f.u); y: Math.round(10 * f.u)
              height: Math.round(17 * f.u); width: Math.max(0, Math.min(f.width * 0.34, tmTag.advanceWidth + Math.round(14 * f.u), f.width - Math.round(14 * f.u) - f.plateW - Math.round(36 * f.u))); radius: Math.round(3 * f.u); color: "transparent"
              border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.55)
    Text { textFormat: Text.PlainText; id: tagTxt; anchors.fill: parent; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
           text: panel ? panel.tag : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight; font.bold: true
           font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(8, Math.round(9 * f.u)); font.letterSpacing: 1.2 * f.u } }
}
