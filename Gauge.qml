import QtQuick
import "Hud.js" as Hud

// A 270-degree dial: track, tick ring, value arc, danger zone, big number inside,
// label and sub-label underneath. Redrawn only when value or colours change.
Item {
  id: g
  property var v: null
  property real value: 0
  property bool known: true
  property real minV: 0
  property real maxV: 100
  property real warn: 0.85            // fraction where the danger zone starts
  property int decimals: 0
  property string label: ""
  property string sub: ""
  property string unit: ""
  readonly property real u: v ? v.u : 1
  readonly property real frac: known && maxV > minV ? Hud.clamp((value - minV) / (maxV - minV), 0, 1) : 0
  // dial art comes from the active skin: ring | arc | needle | knob | seg | fan | draft | ascii
  readonly property string style: v && v.skin ? v.skin.gauge : "arc"
  property real shown: frac            // the needle gets a spring so it overshoots like a real one
  Behavior on shown { enabled: g.style === "needle"; SpringAnimation { spring: 2.4; damping: 0.2; epsilon: 0.002 } }
  onShownChanged: cv.requestPaint()
  onStyleChanged: cv.requestPaint()
  onWidthChanged: cv.requestPaint()
  onHeightChanged: cv.requestPaint()
  Connections { target: g.v; function onAccentChanged() { cv.requestPaint() } function onLineChanged() { cv.requestPaint() } function onDangerChanged() { cv.requestPaint() } function onInkChanged() { cv.requestPaint() } }

  readonly property real labelH: Math.round(34 * u)
  Canvas {
    id: cv
    width: Math.max(0, Math.min(g.width, g.height - g.labelH)); height: width
    anchors.horizontalCenter: parent.horizontalCenter
    onPaint: {
      var ctx = getContext("2d"); ctx.reset()
      if (!g.v) return
      var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 12 * g.u
      if (!(r > 2)) return                                              // panel resized too small to draw a dial
      var a0 = 0.75 * Math.PI, sw = 1.5 * Math.PI, f = g.shown, hot = f > g.warn
      var lit = hot ? Hud.css(g.v.danger, 1) : Hud.css(g.v.accent, 1)
      ctx.lineCap = "butt"
      var i, a
      switch (g.style) {
      case "ring": {                                                    // LCARS: thick flat ring, rounded caps
        r = Math.min(cx, cy) - 8 * g.u
        ctx.lineWidth = 9 * g.u; ctx.lineCap = "round"
        ctx.strokeStyle = Hud.css(g.v.line, 0.25)
        ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sw); ctx.stroke()
        ctx.strokeStyle = Hud.css(g.v.danger, 0.5)
        ctx.beginPath(); ctx.arc(cx, cy, r, a0 + sw * g.warn, a0 + sw); ctx.stroke()
        if (f > 0.005) { ctx.strokeStyle = lit; ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sw * f); ctx.stroke() }
        break }
      case "needle": {                                                  // analog dial with a swinging needle
        ctx.lineWidth = 2 * g.u; ctx.strokeStyle = Hud.css(g.v.ink, 0.55)
        ctx.beginPath(); ctx.arc(cx, cy, r + 5 * g.u, 0, 2 * Math.PI); ctx.stroke()
        ctx.lineWidth = 1; ctx.strokeStyle = Hud.css(g.v.ink, 0.3)
        ctx.beginPath(); ctx.arc(cx, cy, r + 8 * g.u, 0, 2 * Math.PI); ctx.stroke()
        ctx.lineWidth = 3 * g.u; ctx.strokeStyle = Hud.css(g.v.danger, 0.55)
        ctx.beginPath(); ctx.arc(cx, cy, r - 2 * g.u, a0 + sw * g.warn, a0 + sw); ctx.stroke()
        for (i = 0; i <= 40; i++) {
          a = a0 + sw * i / 40; var big = i % 5 === 0, t1 = r - (big ? 9 : 5) * g.u
          ctx.strokeStyle = Hud.css(g.v.ink, big ? 0.85 : 0.45); ctx.lineWidth = big ? 1.6 : 1
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * t1, cy + Math.sin(a) * t1); ctx.lineTo(cx + Math.cos(a) * (r + 1 * g.u), cy + Math.sin(a) * (r + 1 * g.u)); ctx.stroke()
        }
        a = a0 + sw * Math.max(-0.05, Math.min(1.05, f))
        ctx.lineWidth = 2.6 * g.u; ctx.strokeStyle = lit; ctx.lineCap = "round"
        ctx.beginPath(); ctx.moveTo(cx - Math.cos(a) * 7 * g.u, cy - Math.sin(a) * 7 * g.u); ctx.lineTo(cx + Math.cos(a) * (r - 4 * g.u), cy + Math.sin(a) * (r - 4 * g.u)); ctx.stroke()
        ctx.fillStyle = Hud.css(g.v.ink, 0.85); ctx.beginPath(); ctx.arc(cx, cy, 4.5 * g.u, 0, 2 * Math.PI); ctx.fill()
        break }
      case "knob": {                                                    // rotary knob with a lit tick scale
        for (i = 0; i <= 24; i++) {
          a = a0 + sw * i / 24; var on = i / 24 <= f + 0.001 && f > 0.005, bg = i % 6 === 0
          ctx.strokeStyle = on ? lit : Hud.css(g.v.ink, 0.35); ctx.lineWidth = bg ? 2.4 : 1.4
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * (r + 2 * g.u), cy + Math.sin(a) * (r + 2 * g.u)); ctx.lineTo(cx + Math.cos(a) * (r + (bg ? 11 : 8) * g.u), cy + Math.sin(a) * (r + (bg ? 11 : 8) * g.u)); ctx.stroke()
        }
        ctx.fillStyle = Hud.css(g.v.ink, 0.12); ctx.beginPath(); ctx.arc(cx, cy, r * 0.82, 0, 2 * Math.PI); ctx.fill()
        ctx.lineWidth = 2 * g.u; ctx.strokeStyle = Hud.css(g.v.ink, 0.5); ctx.stroke()
        ctx.lineWidth = 1; ctx.strokeStyle = Hud.css(g.v.ink, 0.25); ctx.beginPath(); ctx.arc(cx, cy, r * 0.62, 0, 2 * Math.PI); ctx.stroke()
        a = a0 + sw * f
        ctx.lineWidth = 3.2 * g.u; ctx.lineCap = "round"; ctx.strokeStyle = lit
        ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r * 0.4, cy + Math.sin(a) * r * 0.4); ctx.lineTo(cx + Math.cos(a) * r * 0.76, cy + Math.sin(a) * r * 0.76); ctx.stroke()
        break }
      case "seg": {                                                     // 8-bit: a chain of square blocks
        var n = 18, sz = Math.max(3, Math.round(6 * g.u))
        for (i = 0; i < n; i++) {
          a = a0 + sw * (i + 0.5) / n
          var bx = cx + Math.cos(a) * r - sz / 2, by = cy + Math.sin(a) * r - sz / 2, onb = (i + 0.5) / n <= f
          if (onb) { ctx.fillStyle = (i + 0.5) / n > g.warn ? Hud.css(g.v.danger, 1) : Hud.css(g.v.accent, 1); ctx.fillRect(Math.round(bx), Math.round(by), sz, sz) }
          else { ctx.strokeStyle = Hud.css(g.v.line, 0.4); ctx.lineWidth = 1; ctx.strokeRect(Math.round(bx) + 0.5, Math.round(by) + 0.5, sz - 1, sz - 1) }
        }
        break }
      case "fan": {                                                     // Art Deco: radiating spokes
        var m = 36
        ctx.lineWidth = Math.max(1.5, 2 * g.u)
        for (i = 0; i < m; i++) {
          a = a0 + sw * i / (m - 1); var onf = i / (m - 1) <= f && f > 0.005
          ctx.strokeStyle = onf ? ((i / (m - 1)) > g.warn ? Hud.css(g.v.danger, 1) : Hud.css(g.v.accent, 1)) : Hud.css(g.v.ink, 0.22)
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r * 0.62, cy + Math.sin(a) * r * 0.62); ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); ctx.stroke()
        }
        ctx.lineWidth = 1; ctx.strokeStyle = Hud.css(g.v.ink, 0.5)
        ctx.beginPath(); ctx.arc(cx, cy, r * 0.54, a0, a0 + sw); ctx.stroke()
        ctx.beginPath(); ctx.arc(cx, cy, r + 4 * g.u, a0, a0 + sw); ctx.stroke()
        break }
      case "draft": {                                                   // Blueprint: thin lines and a leader
        ctx.lineWidth = 1; ctx.strokeStyle = Hud.css(g.v.ink, 0.6)
        ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sw); ctx.stroke()
        for (i = 0; i <= 27; i++) {
          a = a0 + sw * i / 27
          ctx.strokeStyle = Hud.css(g.v.ink, i % 3 === 0 ? 0.7 : 0.35)
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * (r - (i % 3 === 0 ? 6 : 3) * g.u), cy + Math.sin(a) * (r - (i % 3 === 0 ? 6 : 3) * g.u)); ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); ctx.stroke()
        }
        a = a0 + sw * f
        ctx.lineWidth = 2 * g.u; ctx.strokeStyle = lit
        ctx.beginPath(); ctx.arc(cx, cy, r - 9 * g.u, a0, a0 + sw * Math.max(0.0001, f)); ctx.stroke()
        ctx.lineWidth = 1; ctx.strokeStyle = Hud.css(g.v.accent, 0.8)
        if (ctx.setLineDash) ctx.setLineDash([4, 3])
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(a) * (r + 6 * g.u), cy + Math.sin(a) * (r + 6 * g.u)); ctx.stroke()
        if (ctx.setLineDash) ctx.setLineDash([])
        ctx.fillStyle = lit; ctx.beginPath(); ctx.arc(cx + Math.cos(a) * (r - 9 * g.u), cy + Math.sin(a) * (r - 9 * g.u), 3 * g.u, 0, 2 * Math.PI); ctx.fill()
        break }
      case "ascii": {                                                   // Nostromo: a row of text-cell blocks
        var cells = 20, bw = width * 0.86, cw = bw / cells, bh = Math.max(5, Math.round(8 * g.u)), bxs = (width - bw) / 2, bys = cy + r * 0.52
        for (i = 0; i < cells; i++) {
          var onc = (i + 0.5) / cells <= f
          ctx.fillStyle = onc ? ((i + 0.5) / cells > g.warn ? Hud.css(g.v.danger, 1) : Hud.css(g.v.accent, 1)) : Hud.css(g.v.ink, 0.18)
          ctx.fillRect(Math.round(bxs + i * cw) + 1, Math.round(bys), Math.max(2, Math.round(cw) - 2), bh)
        }
        ctx.strokeStyle = Hud.css(g.v.ink, 0.6); ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(bxs - 3, bys - 2); ctx.lineTo(bxs - 5, bys - 2); ctx.lineTo(bxs - 5, bys + bh + 2); ctx.lineTo(bxs - 3, bys + bh + 2); ctx.stroke()
        ctx.beginPath(); ctx.moveTo(bxs + bw + 3, bys - 2); ctx.lineTo(bxs + bw + 5, bys - 2); ctx.lineTo(bxs + bw + 5, bys + bh + 2); ctx.lineTo(bxs + bw + 3, bys + bh + 2); ctx.stroke()
        break }
      default: {                                                        // arc: the original ticked neon dial
        for (i = 0; i <= 20; i++) {
          a = a0 + sw * i / 20; var bg2 = i % 5 === 0, r1 = r + 5 * g.u, r2 = r + (bg2 ? 10 : 8) * g.u
          ctx.strokeStyle = Hud.css(g.v.line, bg2 ? 0.9 : 0.5); ctx.lineWidth = 1
          ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1); ctx.lineTo(cx + Math.cos(a) * r2, cy + Math.sin(a) * r2); ctx.stroke()
        }
        ctx.lineWidth = 3 * g.u
        ctx.strokeStyle = Hud.css(g.v.line, 0.35)
        ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sw); ctx.stroke()
        ctx.strokeStyle = Hud.css(g.v.danger, 0.75)
        ctx.lineWidth = 2 * g.u
        ctx.beginPath(); ctx.arc(cx, cy, Math.max(0, r - 5 * g.u), a0 + sw * g.warn, a0 + sw); ctx.stroke()
        if (f > 0) {
          ctx.lineWidth = 4 * g.u
          ctx.strokeStyle = lit
          ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sw * f); ctx.stroke()
        }
      }
      }
    }
    T { anchors.centerIn: parent; anchors.verticalCenterOffset: -Math.round(4 * g.u)
        text: g.known ? Hud.num(g.value, g.decimals) : "--"; sz: 24; u: g.u; mono: g.v ? g.v.mono : "monospace"; c: g.v ? g.v.ink : "#fff"; font.bold: true }
    T { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.5 + Math.round(14 * g.u)
        text: g.unit; sz: 9; u: g.u; mono: g.v ? g.v.mono : "monospace"; c: g.v ? g.v.dim : "#888"; font.letterSpacing: 1.2 * g.u }
  }
  T { anchors { top: cv.bottom; topMargin: Math.round(2 * g.u); horizontalCenter: parent.horizontalCenter }
      width: parent.width; horizontalAlignment: Text.AlignHCenter
      text: g.label; sz: 11; u: g.u; mono: g.v ? g.v.mono : "monospace"; c: g.v ? g.v.ink : "#fff"; font.letterSpacing: 1.2 * g.u }
  T { anchors { top: cv.bottom; topMargin: Math.round(18 * g.u); horizontalCenter: parent.horizontalCenter }
      width: parent.width; horizontalAlignment: Text.AlignHCenter
      text: g.sub; sz: 9; u: g.u; mono: g.v ? g.v.mono : "monospace"; c: g.v ? g.v.dim : "#888" }
}
