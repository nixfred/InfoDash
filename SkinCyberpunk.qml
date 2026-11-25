import QtQuick
import QtQuick.Shapes
import "Hud.js" as Hud

// CYBERPUNK: chamfered corners, a double neon edge, a solid title tab cut at the corner,
// a hazard-stripe run and corner ticks. All colour comes from the Omarchy theme.
Item {
  id: f
  TextMetrics { id: tmTitle; text: panel ? panel.title : ""; font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(11 * f.u)); font.bold: true; font.letterSpacing: 2.2 * f.u; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property real cut: Math.round(16 * u)
  readonly property real cut2: Math.round(6 * u)
  readonly property real tabH: Math.round(20 * u)
  readonly property real tabW: Math.min(width * 0.7, tmTitle.advanceWidth + Math.round(34 * u))
  readonly property real bodyX: Math.round(14 * u)
  readonly property real bodyY: tabH + Math.round(12 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(14 * u)

  // wide soft underlay, then the crisp edge
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: f.v ? Hud.rgba(f.v.bg, 0.62) : "#000"
      strokeColor: f.v ? Hud.rgba(f.v.glow, 0.20) : "#0ff"; strokeWidth: Math.max(4, Math.round(5 * f.u))
      startX: f.cut; startY: 0
      PathLine { x: f.width - f.cut2; y: 0 }
      PathLine { x: f.width; y: f.cut2 }
      PathLine { x: f.width; y: f.height - f.cut }
      PathLine { x: f.width - f.cut; y: f.height }
      PathLine { x: f.cut2; y: f.height }
      PathLine { x: 0; y: f.height - f.cut2 }
      PathLine { x: 0; y: f.cut }
      PathLine { x: f.cut; y: 0 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: f.v ? Hud.rgba(f.v.line, 0.95) : "#0ff"; strokeWidth: Math.max(1.5, 1.5 * f.u)
      startX: f.cut; startY: 0
      PathLine { x: f.width - f.cut2; y: 0 }
      PathLine { x: f.width; y: f.cut2 }
      PathLine { x: f.width; y: f.height - f.cut }
      PathLine { x: f.width - f.cut; y: f.height }
      PathLine { x: f.cut2; y: f.height }
      PathLine { x: 0; y: f.height - f.cut2 }
      PathLine { x: 0; y: f.cut }
      PathLine { x: f.cut; y: 0 }
    }
    // solid title tab, bottom-right corner cut
    ShapePath {
      fillColor: f.v ? f.v.accent : "#0ff"; strokeColor: "transparent"
      startX: f.cut + Math.round(4 * f.u); startY: 0
      PathLine { x: f.cut + Math.round(4 * f.u) + f.tabW; y: 0 }
      PathLine { x: f.cut + Math.round(4 * f.u) + f.tabW; y: f.tabH - Math.round(7 * f.u) }
      PathLine { x: f.cut + Math.round(4 * f.u) + f.tabW - Math.round(7 * f.u); y: f.tabH }
      PathLine { x: f.cut + Math.round(4 * f.u); y: f.tabH }
    }
    // hazard run, bottom edge
    ShapePath {
      fillColor: f.v ? f.v.yellow : "#fc0"; strokeColor: "transparent"
      PathMultiline {
        paths: {
          var out = [], sw = Math.round(7 * f.u), sk = Math.round(4 * f.u), y0 = f.height - Math.round(8 * f.u), y1 = f.height - Math.round(4 * f.u)
          var x0 = f.cut + Math.round(6 * f.u)
          var nStripes = Math.max(0, Math.min(8, Math.floor((f.width - x0 - f.cut2 * 2) / (sw * 1.8))))
          for (var i = 0; i < nStripes; i++) {
            var x = x0 + i * sw * 1.8
            out.push([Qt.point(x, y1), Qt.point(x + sw, y1), Qt.point(x + sw + sk, y0), Qt.point(x + sk, y0), Qt.point(x, y1)])
          }
          return out
        }
      }
    }
  }
  Text { textFormat: Text.PlainText;
    id: titleText
    x: f.cut + Math.round(4 * f.u) + Math.round(10 * f.u); y: 0; height: f.tabH; verticalAlignment: Text.AlignVCenter
    width: f.tabW - Math.round(16 * f.u)
    text: panel ? panel.title : ""; color: f.v ? f.v.bg : "#000"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(11 * f.u)); font.bold: true; font.letterSpacing: 2.2 * f.u
  }
  Text { textFormat: Text.PlainText;
    anchors.right: parent.right; anchors.rightMargin: f.cut2 + Math.round(12 * f.u); y: Math.round(5 * f.u)
    width: Math.max(0, f.width - (f.cut + Math.round(4 * f.u) + f.tabW) - f.cut2 - Math.round(24 * f.u)); horizontalAlignment: Text.AlignRight
    text: panel ? panel.tag : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9.5 * f.u))
  }
  // corner ticks
  Rectangle { x: f.width - Math.round(14 * f.u); y: f.cut2 + Math.round(4 * f.u); width: Math.round(8 * f.u); height: 2; color: f.v ? f.v.glow : "#0ff" }
  Rectangle { x: f.width - Math.round(8 * f.u); y: f.cut2 + Math.round(4 * f.u); width: 2; height: Math.round(8 * f.u); color: f.v ? f.v.glow : "#0ff" }
  Rectangle { x: Math.round(6 * f.u); y: f.height - Math.round(14 * f.u); width: 2; height: Math.round(8 * f.u); color: f.v ? f.v.glow : "#0ff" }
}
