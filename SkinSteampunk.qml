import QtQuick
import QtQuick.Shapes
import "Hud.js" as Hud

// STEAMPUNK: a heavy riveted plate, a double border, a title banner with a gear and bolts.
// "Brass" is the theme foreground at partial opacity, never a fixed gold.
Item {
  id: f
  TextMetrics { id: tmTitle; text: panel ? panel.title : ""; font.family: f.v ? f.v.mono : "serif"; font.pixelSize: Math.max(9, Math.round(11.5 * f.u)); font.bold: true; font.letterSpacing: 1.2 * f.u; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real bodyX: Math.round(18 * u)
  readonly property real bodyY: Math.round(36 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(18 * u)
  readonly property real bannerW: Math.min(width * 0.78, tmTitle.advanceWidth + Math.round(58 * u))

  Rectangle { anchors.fill: parent; radius: Math.round(10 * f.u); color: f.v ? Hud.rgba(f.v.bg, 0.64) : "#000"
              border.width: Math.max(2, Math.round(3 * f.u)); border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.5) }
  Rectangle { x: Math.round(6 * f.u); y: Math.round(6 * f.u); width: f.width - 2 * x; height: f.height - 2 * y; radius: Math.round(6 * f.u)
              color: "transparent"; border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.28) }
  // rivets along the four edges
  Repeater { model: Math.max(0, Math.floor((f.width - Math.round(60 * f.u)) / Math.round(30 * f.u)) + 1)
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(6 * f.u); a: 0.6
      x: Math.round(30 * f.u) + index * ((f.width - Math.round(60 * f.u)) / Math.max(1, Math.floor((f.width - Math.round(60 * f.u)) / Math.round(30 * f.u)))) - d / 2
      y: f.height - Math.round(11 * f.u) } }
  Repeater { model: Math.max(0, Math.floor((f.height - Math.round(80 * f.u)) / Math.round(30 * f.u)) + 1)
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(6 * f.u); a: 0.6
      x: Math.round(5 * f.u)
      y: Math.round(44 * f.u) + index * ((f.height - Math.round(80 * f.u)) / Math.max(1, Math.floor((f.height - Math.round(80 * f.u)) / Math.round(30 * f.u)))) - d / 2 } }
  Repeater { model: Math.max(0, Math.floor((f.height - Math.round(80 * f.u)) / Math.round(30 * f.u)) + 1)
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(6 * f.u); a: 0.6
      x: f.width - Math.round(11 * f.u)
      y: Math.round(44 * f.u) + index * ((f.height - Math.round(80 * f.u)) / Math.max(1, Math.floor((f.height - Math.round(80 * f.u)) / Math.round(30 * f.u)))) - d / 2 } }
  // corner studs
  Repeater { model: 4
    delegate: SkinRivet { required property int index; v: f.v; d: Math.round(13 * f.u); a: 0.7; slot: true
      x: (index % 2) ? f.width - width - Math.round(3 * f.u) : Math.round(3 * f.u)
      y: index > 1 ? f.height - height - Math.round(3 * f.u) : Math.round(3 * f.u) } }
  // title banner
  Rectangle {
    x: Math.round(20 * f.u); y: Math.round(8 * f.u); width: f.bannerW; height: Math.round(22 * f.u); radius: Math.round(4 * f.u)
    color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.88)
    SkinRivet { x: Math.round(5 * f.u); anchors.verticalCenter: parent.verticalCenter; v: f.v ? ({ ink: f.v.bg, bg: f.v.ink }) : null; d: Math.round(5 * f.u); a: 0.8 }
    SkinRivet { x: parent.width - width - Math.round(5 * f.u); anchors.verticalCenter: parent.verticalCenter; v: f.v ? ({ ink: f.v.bg, bg: f.v.ink }) : null; d: Math.round(5 * f.u); a: 0.8 }
    Shape {   // gear
      x: Math.round(16 * f.u); y: parent.height / 2
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: f.v ? f.v.bg : "#000"; strokeColor: "transparent"
        PathPolyline {
          path: {
            var pts = [], teeth = 8, ro = 7 * f.u, ri = 5 * f.u
            for (var i = 0; i < teeth; i++) {
              var a0 = (i / teeth) * 2 * Math.PI, a1 = a0 + 0.25 * Math.PI / teeth * 2, a2 = a0 + 0.5 * Math.PI / teeth * 2, a3 = a0 + 0.75 * Math.PI / teeth * 2
              pts.push(Qt.point(Math.cos(a0) * ri, Math.sin(a0) * ri), Qt.point(Math.cos(a1) * ro, Math.sin(a1) * ro), Qt.point(Math.cos(a2) * ro, Math.sin(a2) * ro), Qt.point(Math.cos(a3) * ri, Math.sin(a3) * ri))
            }
            pts.push(pts[0])
            return pts
          }
        }
      }
    }
    Text { textFormat: Text.PlainText;
      id: title
      x: Math.round(30 * f.u); width: parent.width - x - Math.round(14 * f.u); height: parent.height; verticalAlignment: Text.AlignVCenter
      text: panel ? panel.title : ""; color: f.v ? f.v.bg : "#000"; elide: Text.ElideRight
      font.family: f.v ? f.v.mono : "serif"; font.pixelSize: Math.max(9, Math.round(11.5 * f.u)); font.bold: true; font.letterSpacing: 1.2 * f.u
    }
  }
  Text { textFormat: Text.PlainText;
    anchors.right: parent.right; anchors.rightMargin: Math.round(22 * f.u); y: Math.round(13 * f.u)
    width: Math.max(0, f.width - f.bannerW - Math.round(60 * f.u)); horizontalAlignment: Text.AlignRight
    text: panel ? panel.tag : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight; font.italic: true
    font.family: f.v ? f.v.mono : "serif"; font.pixelSize: Math.max(8, Math.round(9.5 * f.u))
  }
}
