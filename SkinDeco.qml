import QtQuick
import QtQuick.Shapes
import "Hud.js" as Hud

// ART DECO: stepped corners, a double line border, a centred title between rules and
// diamonds with a small sunburst fan under it. Lines are the theme foreground and line colours.
Item {
  id: f
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property real st: Math.round(5 * u)             // one step
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real bodyX: Math.round(18 * u)
  readonly property bool compact: height < Math.round(150 * u)     // short panels give the chrome less room
  readonly property real bodyY: Math.round(compact ? 32 * u : 44 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(compact ? 12 * u : 26 * u)

  function outline(i, w, h) {      // stepped-corner polygon, inset by i
    var s = f.st, pts = []
    pts.push(Qt.point(i + 3 * s, i), Qt.point(w - i - 3 * s, i), Qt.point(w - i - 3 * s, i + s), Qt.point(w - i - 2 * s, i + s), Qt.point(w - i - 2 * s, i + 2 * s), Qt.point(w - i - s, i + 2 * s), Qt.point(w - i - s, i + 3 * s), Qt.point(w - i, i + 3 * s))
    pts.push(Qt.point(w - i, h - i - 3 * s), Qt.point(w - i - s, h - i - 3 * s), Qt.point(w - i - s, h - i - 2 * s), Qt.point(w - i - 2 * s, h - i - 2 * s), Qt.point(w - i - 2 * s, h - i - s), Qt.point(w - i - 3 * s, h - i - s), Qt.point(w - i - 3 * s, h - i))
    pts.push(Qt.point(i + 3 * s, h - i), Qt.point(i + 3 * s, h - i - s), Qt.point(i + 2 * s, h - i - s), Qt.point(i + 2 * s, h - i - 2 * s), Qt.point(i + s, h - i - 2 * s), Qt.point(i + s, h - i - 3 * s), Qt.point(i, h - i - 3 * s))
    pts.push(Qt.point(i, i + 3 * s), Qt.point(i + s, i + 3 * s), Qt.point(i + s, i + 2 * s), Qt.point(i + 2 * s, i + 2 * s), Qt.point(i + 2 * s, i + s), Qt.point(i + 3 * s, i + s), Qt.point(i + 3 * s, i))
    return pts
  }
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: f.v ? Hud.rgba(f.v.bg, 0.62) : "#000"
      strokeColor: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.8); strokeWidth: Math.max(1.5, 1.5 * f.u)
      PathPolyline { path: f.outline(Math.round(1 * f.u), f.width, f.height) }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.32); strokeWidth: 1
      PathPolyline { path: f.outline(Math.round(7 * f.u), f.width, f.height) }
    }
    // sunburst fan under the title
    ShapePath {
      fillColor: "transparent"
      strokeColor: f.v ? Hud.rgba(f.v.line, 0.45) : "#0ff"; strokeWidth: 1
      PathMultiline {
        paths: {
          var out = [], cx = f.width / 2, y0 = Math.round(27 * f.u), L = Math.round(11 * f.u)
          for (var a = -70; a <= 70; a += 20) {
            var r = a * Math.PI / 180
            out.push([Qt.point(cx, y0), Qt.point(cx + Math.sin(r) * L * 1.8, y0 + Math.cos(r) * L)])
          }
          return out
        }
      }
    }
  }
  // title with rules and diamonds
  Text { textFormat: Text.PlainText;
    id: title
    anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(9 * f.u)
    width: Math.max(0, Math.min(implicitWidth, f.width - Math.round(110 * f.u)))
    text: panel ? panel.title : ""; color: f.v ? f.v.ink : "#ccc"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(9, Math.round(11.5 * f.u)); font.letterSpacing: 3 * f.u
  }
  Repeater { model: 2
    delegate: Item { required property int index
      readonly property real edge: index === 0 ? title.x - Math.round(10 * f.u) : title.x + title.width + Math.round(10 * f.u)
      Rectangle { x: index === 0 ? Math.round(20 * f.u) : parent.edge + Math.round(8 * f.u); y: Math.round(16 * f.u)
                  width: index === 0 ? parent.edge - Math.round(28 * f.u) : f.width - Math.round(20 * f.u) - (parent.edge + Math.round(8 * f.u)); height: 1
                  color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.55) }
      Rectangle { x: parent.edge - width / 2 + (index === 0 ? 0 : Math.round(0 * f.u)); y: Math.round(16 * f.u) - height / 2; width: Math.round(6 * f.u); height: width; rotation: 45
                  color: f.v ? f.v.accent : "#0ff" } }
  }
  // tag, centred at the foot between rules
  Text { textFormat: Text.PlainText;
    id: tagText
    visible: !f.compact
    anchors.horizontalCenter: parent.horizontalCenter; y: f.height - Math.round(21 * f.u)
    width: Math.max(0, Math.min(implicitWidth, f.width - Math.round(120 * f.u)))
    text: panel ? panel.tag : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "sans-serif"; font.pixelSize: Math.max(8, Math.round(9 * f.u)); font.letterSpacing: 2 * f.u
  }
}
