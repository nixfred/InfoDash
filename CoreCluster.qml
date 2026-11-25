import QtQuick
import "Hud.js" as Hud

// One small speedometer per logical CPU, in a grid with no orphan row. All the
// faces share one canvas that repaints only on a size, count or colour change.
Item {
  id: cc
  property var v: null
  property var values: []             // busy percent per logical CPU
  property real warn: 0.85
  readonly property real u: v ? v.u : 1
  readonly property int count: values ? values.length : 0
  readonly property var grid: Hud.gridFit(count, width, height)
  readonly property real cellW: grid.cols ? width / grid.cols : 0
  readonly property real cellH: grid.rows ? height / grid.rows : 0
  readonly property real d: Math.max(0, Math.min(cellW, cellH) - Math.round(3 * u))
  readonly property real r: Math.max(0, d / 2 - 1)

  Canvas {
    id: faces
    anchors.fill: parent
    readonly property string key: cc.count + ":" + cc.grid.cols + ":" + width + "x" + height + ":" + cc.d
    onKeyChanged: requestPaint()
    Connections { target: cc.v; function onLineChanged() { faces.requestPaint() } function onDangerChanged() { faces.requestPaint() } function onInkChanged() { faces.requestPaint() } }
    onPaint: {
      var ctx = getContext("2d"); ctx.reset()
      if (!cc.v || !(cc.r > 5)) return
      var a0 = 0.75 * Math.PI, sw = 1.5 * Math.PI
      for (var n = 0; n < cc.count; n++) {
        var cx = (n % cc.grid.cols + 0.5) * cc.cellW, cy = (Math.floor(n / cc.grid.cols) + 0.5) * cc.cellH
        ctx.lineWidth = Math.max(1.5, 2 * cc.u); ctx.strokeStyle = Hud.css(cc.v.line, 0.5)
        ctx.beginPath(); ctx.arc(cx, cy, cc.r, a0, a0 + sw); ctx.stroke()
        ctx.strokeStyle = Hud.css(cc.v.danger, 0.9)
        ctx.beginPath(); ctx.arc(cx, cy, cc.r, a0 + sw * cc.warn, a0 + sw); ctx.stroke()
        ctx.lineWidth = 1; ctx.strokeStyle = Hud.css(cc.v.ink, 0.5)
        for (var i = 0; i <= 4; i++) {
          var a = a0 + sw * i / 4
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * (cc.r - 4 * cc.u), cy + Math.sin(a) * (cc.r - 4 * cc.u)); ctx.lineTo(cx + Math.cos(a) * (cc.r - 1), cy + Math.sin(a) * (cc.r - 1)); ctx.stroke()
        }
      }
    }
  }

  // The model is the CPU count, so the needles live across readings and can move.
  Repeater {
    model: cc.count
    Item {
      id: cell
      required property int index
      readonly property real busy: cc.values && cc.values[index] !== undefined ? cc.values[index] : 0
      readonly property bool hot: busy / 100 > cc.warn
      x: (index % cc.grid.cols) * cc.cellW; y: Math.floor(index / cc.grid.cols) * cc.cellH
      width: cc.cellW; height: cc.cellH
      T { visible: cc.d >= 22 * cc.u; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height / 2 + cc.r * 0.3
          text: Hud.num(cell.busy); sz: Math.max(8, cc.d / cc.u * 0.17); u: cc.u; mono: cc.v ? cc.v.mono : "monospace"
          c: cc.v ? (cell.hot ? cc.v.danger : cc.v.ink) : "#fff"; elide: Text.ElideNone }
      Item {
        x: parent.width / 2; y: parent.height / 2
        rotation: 135 + 270 * Hud.clamp(cell.busy / 100, 0, 1)
        Behavior on rotation { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
        Rectangle { x: -2 * cc.u; y: -height / 2; width: Math.max(0, cc.r - 2 * cc.u); height: Math.max(1.5, 1.8 * cc.u); radius: height / 2; antialiasing: true
                    color: cc.v ? (cell.hot ? cc.v.danger : cc.v.accent) : "#4cf" }
      }
      Rectangle { anchors.centerIn: parent; width: Math.max(3, Math.round(4 * cc.u)); height: width; radius: width / 2; antialiasing: true; color: cc.v ? cc.v.ink : "#fff" }
    }
  }
}
