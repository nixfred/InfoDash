import QtQuick
import "Hud.js" as Hud

// 8-BIT: a chunky two-layer pixel border with notched corners, a hard drop shadow and an
// inverse title block, all on a pixel size derived from the HUD scale.
Item {
  id: f
  TextMetrics { id: tmTitle; text: panel ? panel.title : ""; font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(10.5 * f.u)); font.bold: true; font.letterSpacing: 1 * f.u; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property real p: Math.max(2, Math.round(3 * u))
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real titleH: 6 * p
  readonly property real bodyX: 4 * p
  readonly property real bodyY: titleH + 3 * p
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - 4 * p

  // hard shadow
  Rectangle { x: f.p; y: f.p + 1; width: f.width - 1; height: f.height - 1; color: Qt.rgba(0, 0, 0, 0.35) }
  // fill (two overlapping rects leave the corner notches)
  Rectangle { x: f.p; y: 0; width: f.width - 2 * f.p; height: f.height; color: f.v ? Hud.rgba(f.v.bg, 0.88) : "#000" }
  Rectangle { x: 0; y: f.p; width: f.width; height: f.height - 2 * f.p; color: f.v ? Hud.rgba(f.v.bg, 0.88) : "#000" }
  // outer border layer
  Rectangle { x: f.p; y: 0; width: f.width - 2 * f.p; height: f.p; color: f.ink }
  Rectangle { x: f.p; y: f.height - f.p; width: f.width - 2 * f.p; height: f.p; color: f.ink }
  Rectangle { x: 0; y: f.p; width: f.p; height: f.height - 2 * f.p; color: f.ink }
  Rectangle { x: f.width - f.p; y: f.p; width: f.p; height: f.height - 2 * f.p; color: f.ink }
  // inner border layer (dimmer)
  Rectangle { x: 2 * f.p; y: f.p; width: f.width - 4 * f.p; height: f.p; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.4) }
  Rectangle { x: 2 * f.p; y: f.height - 2 * f.p; width: f.width - 4 * f.p; height: f.p; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.4) }
  Rectangle { x: f.p; y: 2 * f.p; width: f.p; height: f.height - 4 * f.p; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.4) }
  Rectangle { x: f.width - 2 * f.p; y: 2 * f.p; width: f.p; height: f.height - 4 * f.p; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.4) }
  // inverse title block
  Rectangle {
    x: 3 * f.p; y: 2 * f.p; height: f.titleH - f.p; width: Math.min(f.width * 0.66, tmTitle.advanceWidth + 4 * f.p); color: f.ink
    Text { textFormat: Text.PlainText; id: title; x: 2 * f.p; width: parent.width - 3 * f.p; height: parent.height; verticalAlignment: Text.AlignVCenter
           text: panel ? panel.title : ""; color: f.v ? f.v.bg : "#000"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(10.5 * f.u)); font.bold: true; font.letterSpacing: 1 * f.u }
  }
  // block cursor after the title
  Rectangle { x: 3 * f.p + Math.min(f.width * 0.66, tmTitle.advanceWidth + 4 * f.p) + f.p; y: 2 * f.p; width: f.p * 2; height: f.titleH - f.p; color: f.v ? f.v.accent : "#0ff"
              SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0.0; duration: 500 } NumberAnimation { to: 1.0; duration: 500 } } }
  Text { textFormat: Text.PlainText;
    anchors.right: parent.right; anchors.rightMargin: 4 * f.p; y: 2 * f.p; height: f.titleH - f.p; verticalAlignment: Text.AlignVCenter
    width: f.width * 0.3; horizontalAlignment: Text.AlignRight
    text: panel ? panel.tag : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9 * f.u)); font.bold: true
  }
}
