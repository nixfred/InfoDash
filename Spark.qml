import QtQuick
import "Hud.js" as Hud

// Filled sparkline over a short history array. Auto-scales unless lo/hi are set.
Item {
  id: s
  property var v: null
  property var values: []
  property real lo: NaN
  property real hi: NaN
  readonly property string style: v && v.skin ? v.skin.spark : "area"
  onStyleChanged: cv.requestPaint()
  onValuesChanged: cv.requestPaint()
  onWidthChanged: cv.requestPaint()
  onHeightChanged: cv.requestPaint()
  Canvas {
    id: cv
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d"); ctx.reset()
      var a = s.values || []
      if (!s.v || a.length < 2) return
      var mn = isNaN(s.lo) ? Math.min.apply(null, a) : s.lo, mx = isNaN(s.hi) ? Math.max.apply(null, a) : s.hi
      if (mx - mn < 1) { mx = mn + 1 }
      var w = width, h = height - 2, step = w / (a.length - 1), i
      if (s.style === "step") {                                   // block columns (8-bit, terminal, cassette)
        var bw = Math.max(2, Math.floor(w / a.length) - 1)
        ctx.fillStyle = Hud.css(s.v.accent, 0.85)
        for (i = 0; i < a.length; i++) {
          var bh = Math.max(2, Math.round((a[i] - mn) / (mx - mn) * (h - 2)))
          ctx.fillRect(Math.round(i * (w / a.length)), h + 1 - bh, bw, bh)
        }
        return
      }
      ctx.beginPath()
      for (i = 0; i < a.length; i++) {
        var x = i * step, y = h - (a[i] - mn) / (mx - mn) * (h - 2) - 1
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
      }
      ctx.strokeStyle = Hud.css(s.v.accent, 0.95); ctx.lineWidth = s.style === "line" ? 1.6 : 1.2; ctx.stroke()
      if (s.style === "line") {                                   // line with sample dots (drafting, deco, brass)
        ctx.fillStyle = Hud.css(s.v.accent, 1)
        for (i = 0; i < a.length; i += Math.max(1, Math.floor(a.length / 10))) ctx.fillRect(i * step - 1.5, h - (a[i] - mn) / (mx - mn) * (h - 2) - 2.5, 3, 3)
        return
      }
      ctx.lineTo(w, h + 1); ctx.lineTo(0, h + 1); ctx.closePath()
      ctx.fillStyle = Hud.css(s.v.accent, 0.14); ctx.fill()
    }
  }
}
