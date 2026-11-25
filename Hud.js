.pragma library
// Small drawing helpers shared by the Canvas items.
function css(c, a) {
  return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (a === undefined ? c.a : a) + ")"
}
// For Rectangle/Text colours: a real QML colour (CSS rgba() strings are Canvas-only).
function hex2(n) { var h = Math.max(0, Math.min(255, Math.round(n))).toString(16); return h.length < 2 ? "0" + h : h }
function rgba(c, a) { return "#" + hex2((a === undefined ? c.a : a) * 255) + hex2(c.r * 255) + hex2(c.g * 255) + hex2(c.b * 255) }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
function fmtRate(b) {
  b = Number(b) || 0
  if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
  if (b >= 1024) return (b / 1024).toFixed(1) + " KB/s"
  return Math.round(b) + " B/s"
}
function fmtBytes(b) {
  b = Number(b) || 0
  if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB"
  if (b >= 1048576) return (b / 1048576).toFixed(2) + " MB"
  return (b / 1024).toFixed(0) + " KB"
}
function fmtUptime(s) {
  s = Math.max(0, Math.floor(Number(s) || 0))
  var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
  return (d ? d + "d " : "") + h + "h " + m + "m"
}
function fmtAge(s) {
  s = Math.max(0, Math.floor(Number(s) || 0))
  if (s < 3600) return Math.floor(s / 60) + "m"
  if (s < 86400) return Math.floor(s / 3600) + "h"
  return Math.floor(s / 86400) + "d"
}
function num(v, d) { return v === null || v === undefined || !isFinite(v) ? "--" : Number(v).toFixed(d === undefined ? 0 : d) }
// A grid for n equal tiles in a w x h box with every row full: of the column
// counts that divide n, the one that gives the biggest square tile.
function gridFit(n, w, h) {
  var best = { cols: 0, rows: 0 }, size = -1
  for (var c = 1; c <= n; c++) {
    if (n % c) continue
    var t = Math.min(w / c, h / (n / c))
    if (t > size) { size = t; best = { cols: c, rows: n / c } }
  }
  return best
}
