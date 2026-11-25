import QtQuick
import QtQuick.Shapes
import "Hud.js" as Hud

// STAR TREK (LCARS): a rounded elbow wraps the top-left corner, a flat top bar carries the
// title, a pill carries the tag, the side strip is cut into segments, a slim bar closes the
// bottom. Blocks take the Omarchy theme's accent, blue, yellow and cyan.
Item {
  id: f
  TextMetrics { id: tmTag; text: panel ? panel.tag : ""; font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(8, Math.round(9.5 * f.u)); font.bold: true; font.letterSpacing: 0; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property real tb: Math.round(22 * u)          // top bar thickness
  readonly property real ls: Math.round(20 * u)          // side strip width
  readonly property real er: Math.round(26 * u)           // outer elbow radius
  readonly property real ri: Math.round(9 * u)           // inner elbow radius
  readonly property real gap: Math.round(4 * u)
  readonly property color c1: v ? v.accent : "#fa0"
  readonly property color c2: v ? v.blue : "#99f"
  readonly property color c3: v ? v.yellow : "#fc6"
  readonly property color c4: v ? v.cyan : "#6cf"
  readonly property real pillW: tmTag.text === "" ? 0 : Math.min(width * 0.46, tmTag.advanceWidth + Math.round(26 * u))
  readonly property real barEnd: width - (pillW > 0 ? pillW + gap : 0) - (pillW > 0 ? 0 : 0)

  // content rectangle for HudPanel
  readonly property real bodyX: ls + Math.round(12 * u)
  readonly property real bodyY: tb + Math.round(10 * u)
  readonly property real bodyW: width - bodyX - Math.round(12 * u)
  readonly property real bodyH: height - bodyY - Math.round(14 * u)

  // dark LCARS field behind the content
  Rectangle { x: f.ls; y: f.tb; width: f.width - f.ls; height: f.height - f.tb; color: f.v ? Hud.rgba(f.v.bg, 0.55) : "#000" }

  // the elbow: side strip + top bar in one filled outline
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: f.c1; strokeColor: "transparent"
      startX: 0; startY: f.height
      PathLine { x: 0; y: f.er }
      PathArc { x: f.er; y: 0; radiusX: f.er; radiusY: f.er; direction: PathArc.Clockwise }
      PathLine { x: f.barEnd - f.tb / 2; y: 0 }
      PathArc { x: f.barEnd - f.tb / 2; y: f.tb; radiusX: f.tb / 2; radiusY: f.tb / 2; direction: PathArc.Clockwise }
      PathLine { x: f.ls + f.ri; y: f.tb }
      PathArc { x: f.ls; y: f.tb + f.ri; radiusX: f.ri; radiusY: f.ri; direction: PathArc.Counterclockwise }
      PathLine { x: f.ls; y: f.height }
      PathLine { x: 0; y: f.height }
    }
  }
  // cut the strip into segments, colour the last one
  Rectangle { x: 0; y: f.height * 0.46; width: f.ls; height: f.gap; color: f.v ? f.v.bg : "#000" }
  Rectangle { x: 0; y: f.height * 0.74; width: f.ls; height: f.gap; color: f.v ? f.v.bg : "#000" }
  Rectangle { x: 0; y: f.height * 0.74 + f.gap; width: f.ls; height: f.height - (f.height * 0.74 + f.gap); color: f.c2 }
  Rectangle { x: 0; y: f.height * 0.46 + f.gap; width: f.ls; height: f.height * 0.28 - f.gap; color: f.c4 }

  // tag pill, right end of the top bar
  Rectangle {
    visible: f.pillW > 0
    x: f.width - f.pillW; y: 0; width: f.pillW; height: f.tb; radius: f.tb / 2; color: f.c3
    Text { textFormat: Text.PlainText; id: tagText; anchors.centerIn: parent; text: panel ? panel.tag : ""; color: f.v ? f.v.bg : "#000"
           font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(8, Math.round(9.5 * f.u)); font.bold: true
           width: Math.max(0, parent.width - Math.round(16 * f.u)); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
  }
  // title, set in the top bar in the background colour
  Text { textFormat: Text.PlainText;
    x: f.ls + f.ri + Math.round(10 * f.u); y: 0; height: f.tb; verticalAlignment: Text.AlignVCenter
    width: Math.max(0, f.barEnd - x - f.gap)
    text: panel ? panel.title : ""; color: f.v ? f.v.bg : "#000"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(9, Math.round(11.5 * f.u)); font.bold: true
    font.letterSpacing: 2 * f.u
  }
  // slim bottom bar with a rounded end
  Rectangle { x: f.ls + f.gap; y: f.height - Math.round(7 * f.u); width: f.width - x - Math.round(26 * f.u) - f.gap; height: Math.round(5 * f.u); color: f.c3; opacity: 0.85 }
  Rectangle { x: f.width - Math.round(26 * f.u); y: f.height - Math.round(7 * f.u); width: Math.round(26 * f.u); height: Math.round(5 * f.u); radius: height / 2; color: f.c1 }
}
