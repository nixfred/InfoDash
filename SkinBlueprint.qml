import QtQuick
import QtQuick.Shapes
import "Hud.js" as Hud

// BLUEPRINT: hairline outline, registration crosses, a faint drafting grid, a title block
// for the tag, and a dimension line with arrowheads that reports the panel's real width.
Item {
  id: f
  TextMetrics { id: tmTag; text: panel ? panel.tag : ""; font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(7, Math.round(8.5 * f.u)); font.bold: false; font.letterSpacing: 0; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real bodyX: Math.round(14 * u)
  readonly property real bodyY: Math.round(34 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(24 * u)
  readonly property real blockW: Math.max(Math.round(118 * u), tmTag.advanceWidth + Math.round(20 * u))

  Rectangle { anchors.fill: parent; color: f.v ? Hud.rgba(f.v.bg, 0.5) : "#000"; border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.5) }
  Canvas {   // drafting grid
    anchors.fill: parent
    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
    Connections { target: f.v; function onLineChanged() { requestPaint() } }
    onPaint: {
      var c = getContext("2d"); c.reset()
      if (!f.v) return
      c.strokeStyle = Hud.css(f.v.line, 0.10); c.lineWidth = 1
      var s = Math.round(20 * f.u)
      c.beginPath()
      for (var x = s; x < width; x += s) { c.moveTo(x + 0.5, 0); c.lineTo(x + 0.5, height) }
      for (var y = s; y < height; y += s) { c.moveTo(0, y + 0.5); c.lineTo(width, y + 0.5) }
      c.stroke()
    }
  }
  // registration crosses
  Repeater { model: 4
    delegate: Item { required property int index
      x: (index % 2) ? f.width - Math.round(12 * f.u) : Math.round(2 * f.u); y: index > 1 ? f.height - Math.round(12 * f.u) : Math.round(2 * f.u)
      width: Math.round(10 * f.u); height: width
      Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: f.v ? f.v.line : "#0ff" }
      Rectangle { anchors.centerIn: parent; width: 1; height: parent.height; color: f.v ? f.v.line : "#0ff" } }
  }
  // dimension line along the foot
  Shape {
    anchors.fill: parent
    ShapePath {
      fillColor: "transparent"; strokeColor: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.7); strokeWidth: 1
      PathMultiline {
        paths: {
          var y = f.height - Math.round(11 * f.u), x0 = Math.round(14 * f.u), x1 = f.width - Math.round(14 * f.u), a = Math.round(6 * f.u), t = Math.round(4 * f.u)
          return [[Qt.point(x0, y), Qt.point(x1, y)],
                  [Qt.point(x0 + a, y - t), Qt.point(x0, y), Qt.point(x0 + a, y + t)],
                  [Qt.point(x1 - a, y - t), Qt.point(x1, y), Qt.point(x1 - a, y + t)],
                  [Qt.point(x0, y - Math.round(7 * f.u)), Qt.point(x0, y + Math.round(7 * f.u))],
                  [Qt.point(x1, y - Math.round(7 * f.u)), Qt.point(x1, y + Math.round(7 * f.u))]]
        }
      }
    }
  }
  Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: f.height - Math.round(11 * f.u) - height / 2; width: dim.implicitWidth + Math.round(10 * f.u); height: Math.round(12 * f.u); color: f.v ? f.v.bg : "#000"
    Text { textFormat: Text.PlainText; id: dim; anchors.centerIn: parent; text: Math.round(f.width / f.u) + " U  /  " + Math.round(f.height / f.u); color: f.v ? f.v.dim : "#888"
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(7, Math.round(8.5 * f.u)); elide: Text.ElideNone } }
  // title with a drafting underline
  Text { textFormat: Text.PlainText;
    id: title
    x: Math.round(14 * f.u); y: Math.round(8 * f.u); width: Math.max(0, f.width - f.blockW - Math.round(36 * f.u))
    text: panel ? panel.title : ""; color: f.v ? f.v.ink : "#ccc"; elide: Text.ElideRight
    font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(11 * f.u)); font.letterSpacing: 1.6 * f.u
  }
  Rectangle { x: Math.round(14 * f.u); y: Math.round(24 * f.u); width: Math.min(title.implicitWidth, title.width); height: 1; color: f.v ? f.v.accent : "#0ff" }
  // title block (tag + sheet id)
  Rectangle {
    x: f.width - f.blockW - Math.round(10 * f.u); y: Math.round(6 * f.u); width: f.blockW; height: Math.round(22 * f.u); color: "transparent"
    border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.6)
    Rectangle { x: 0; y: parent.height / 2; width: parent.width; height: 1; color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.4) }
    Text { textFormat: Text.PlainText; id: tag; x: Math.round(5 * f.u); width: parent.width - Math.round(8 * f.u); height: parent.height / 2; verticalAlignment: Text.AlignVCenter
           text: panel ? panel.tag : ""; color: f.v ? f.v.ink : "#ccc"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(7, Math.round(8.5 * f.u)) }
    Text { textFormat: Text.PlainText; x: Math.round(5 * f.u); y: parent.height / 2; width: parent.width - Math.round(8 * f.u); height: parent.height / 2; verticalAlignment: Text.AlignVCenter
           text: "SHT " + String(panel ? panel.slot : "").toUpperCase() + "  REV C"; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(7, Math.round(7.5 * f.u)) }
  }
}
