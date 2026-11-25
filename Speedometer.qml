import QtQuick
import "Hud.js" as Hud

// A speedometer: numbered 270-degree scale, redline, and a needle on a spring.
// The face is painted only when size or colours change; the needle is a rotated
// item, so a new reading costs no repaint.
Item {
  id: s
  property var v: null
  property real value: 0              // 0..100
  property bool known: true
  property real warn: 0.85
  property string unit: "%"
  property string label: ""
  property string sub: ""
  property color subColor: v ? v.dim : "#888"
  readonly property real u: v ? v.u : 1
  readonly property real labelH: Math.round(34 * u)
  readonly property real frac: known ? Hud.clamp(value / 100, 0, 1) : 0
  property real shown: frac
  Behavior on shown { SpringAnimation { spring: 2.4; damping: 0.24; epsilon: 0.002 } }

  Item {
    id: dial
    width: Math.max(0, Math.min(s.width, s.height - s.labelH)); height: width
    anchors.horizontalCenter: parent.horizontalCenter
    readonly property real r: Math.max(0, width / 2 - 4 * s.u)

    Canvas {
      id: face
      anchors.fill: parent
      onWidthChanged: requestPaint()
      Connections { target: s.v; function onAccentChanged() { face.requestPaint() } function onLineChanged() { face.requestPaint() } function onDangerChanged() { face.requestPaint() } function onInkChanged() { face.requestPaint() } function onMonoChanged() { face.requestPaint() } }
      onPaint: {
        var ctx = getContext("2d"); ctx.reset()
        var cx = width / 2, cy = height / 2, r = dial.r
        if (!s.v || !(r > 12)) return
        var a0 = 0.75 * Math.PI, sw = 1.5 * Math.PI, i, a
        ctx.lineCap = "butt"
        ctx.lineWidth = 3 * s.u; ctx.strokeStyle = Hud.css(s.v.line, 0.45)
        ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sw); ctx.stroke()
        ctx.lineWidth = 6 * s.u; ctx.strokeStyle = Hud.css(s.v.danger, 0.85)
        ctx.beginPath(); ctx.arc(cx, cy, r - 3 * s.u, a0 + sw * s.warn, a0 + sw); ctx.stroke()
        for (i = 0; i <= 50; i++) {
          a = a0 + sw * i / 50
          var big = i % 5 === 0, t = r - (big ? 10 : 5) * s.u
          ctx.strokeStyle = Hud.css(i / 50 >= s.warn ? s.v.danger : s.v.ink, big ? 0.95 : 0.45); ctx.lineWidth = big ? Math.max(1.4, 1.6 * s.u) : 1
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * t, cy + Math.sin(a) * t); ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); ctx.stroke()
        }
        ctx.fillStyle = Hud.css(s.v.ink, 0.95); ctx.textAlign = "center"; ctx.textBaseline = "middle"
        ctx.font = Math.max(7, Math.round(8.5 * s.u)) + "px \"" + s.v.mono + "\""
        var tr = r - 20 * s.u
        if (tr > 14 * s.u) for (i = 0; i <= 5; i++) { a = a0 + sw * i / 5; ctx.fillText(String(i * 20), cx + Math.cos(a) * tr, cy + Math.sin(a) * tr) }
      }
    }
    // digital readout, in the gap at the bottom of the scale
    T { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.5 + dial.r * 0.48
        text: s.known ? Hud.num(s.value) + s.unit : "--"; sz: 20; u: s.u; mono: s.v ? s.v.mono : "monospace"
        c: s.v ? (s.frac > s.warn ? s.v.danger : s.v.ink) : "#fff"; font.bold: true; elide: Text.ElideNone }
    Item {
      x: dial.width / 2; y: dial.height / 2
      rotation: 135 + 270 * Math.max(-0.02, Math.min(1.02, s.shown))
      Rectangle { x: -dial.r * 0.16; y: -height / 2; width: dial.r * 1.06; height: Math.max(2, 3 * s.u); radius: height / 2; antialiasing: true
                  color: s.v ? (s.frac > s.warn ? s.v.danger : s.v.accent) : "#4cf" }
    }
    Rectangle { anchors.centerIn: parent; width: Math.round(12 * s.u); height: width; radius: width / 2; antialiasing: true
                color: s.v ? s.v.ink : "#fff"; border.width: Math.max(1, 2 * s.u); border.color: s.v ? s.v.accent : "#4cf" }
  }
  T { anchors { top: dial.bottom; topMargin: Math.round(2 * s.u); horizontalCenter: parent.horizontalCenter }
      width: parent.width; horizontalAlignment: Text.AlignHCenter
      text: s.label; sz: 11; u: s.u; mono: s.v ? s.v.mono : "monospace"; c: s.v ? s.v.ink : "#fff"; font.letterSpacing: 1.2 * s.u }
  T { anchors { top: dial.bottom; topMargin: Math.round(18 * s.u); horizontalCenter: parent.horizontalCenter }
      width: parent.width; horizontalAlignment: Text.AlignHCenter
      text: s.sub; sz: 9; u: s.u; mono: s.v ? s.v.mono : "monospace"; c: s.subColor }
}
