.pragma library
// Infodash layout engine: pure grid logic, no QML. Panels live on a COLS x ROWS grid
// as {x, y, w, h} cells. Moving or resizing one panel pushes the others clear.
// Themes never touch this: they only draw inside the rectangles it produces.

var COLS = 48
var ROWS = 24

// Minimum size per panel, in cells (a gauge needs its dial, a table needs its columns).
var MINS = {
  usb: { w: 8, h: 5 }, fleet: { w: 6, h: 4 }, ai: { w: 6, h: 4 },
  cpu: { w: 6, h: 5 }, mem: { w: 6, h: 5 }, gfx: { w: 6, h: 4 }, stg: { w: 6, h: 5 },
  pw: { w: 12, h: 4 }, np: { w: 12, h: 4 }, ledger: { w: 16, h: 3 }
}

// The default arrangement (reproduces the original hand-built dashboard exactly).
function defaults() {
  return {
    ai:     { x: 0,  y: 0,  w: 16, h: 14 },     // agent sessions grow without bound, so they get the big slot
    fleet:  { x: 16, y: 0,  w: 12, h: 7 },
    usb:    { x: 16, y: 7,  w: 12, h: 7 },     // the USB bay is mostly empty, so it takes the small one
    cpu:    { x: 28, y: 0,  w: 10, h: 7 },
    mem:    { x: 38, y: 0,  w: 10, h: 7 },
    gfx:    { x: 28, y: 7,  w: 10, h: 7 },
    stg:    { x: 38, y: 7,  w: 10, h: 7 },
    pw:     { x: 0,  y: 14, w: 24, h: 6 },
    np:     { x: 24, y: 14, w: 24, h: 6 },
    ledger: { x: 0,  y: 20, w: 48, h: 4 }
  }
}

function ids() { return Object.keys(MINS) }
function copyRect(r) { return { x: r.x, y: r.y, w: r.w, h: r.h } }
function copy(layout) { var o = {}; for (var k in layout) o[k] = copyRect(layout[k]); return o }

function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

function inBounds(r) { return r.x >= 0 && r.y >= 0 && r.w >= 1 && r.h >= 1 && r.x + r.w <= COLS && r.y + r.h <= ROWS }

// Round to whole cells, enforce the minimum size, keep inside the grid.
function clampRect(r, id) {
  var m = MINS[id] || { w: 1, h: 1 }
  var w = Math.max(m.w, Math.min(COLS, Math.round(r.w)))
  var h = Math.max(m.h, Math.min(ROWS, Math.round(r.h)))
  var x = Math.max(0, Math.min(COLS - w, Math.round(r.x)))
  var y = Math.max(0, Math.min(ROWS - h, Math.round(r.y)))
  return { x: x, y: y, w: w, h: h }
}

// Is the whole layout legal: every panel present, inside the grid, at least its minimum, no overlaps?
function valid(layout) {
  var k = ids()
  for (var i = 0; i < k.length; i++) {
    var r = layout[k[i]]
    if (!r || !inBounds(r) || r.w < MINS[k[i]].w || r.h < MINS[k[i]].h) return false
    for (var j = i + 1; j < k.length; j++) if (layout[k[j]] && overlaps(r, layout[k[j]])) return false
  }
  return true
}

// Keep only what a saved layout got right; anything illegal means "use the default".
function sanitize(saved) {
  if (!saved || typeof saved !== "object") return defaults()
  var out = {}, k = ids()
  for (var i = 0; i < k.length; i++) {
    var r = saved[k[i]]
    if (!r || typeof r.x !== "number" || typeof r.y !== "number" || typeof r.w !== "number" || typeof r.h !== "number") return defaults()
    out[k[i]] = { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.w), h: Math.round(r.h) }
  }
  return valid(out) ? out : defaults()
}

// Push panels out of the way in one direction. The dragged panel `id` never moves here.
// Returns {layout, moved:[ids], cost} or null when something would leave the grid.
function pushing(layout, id, dir) {
  var L = copy(layout), moved = {}, keys = ids()
  for (var guard = 0; guard < 400; guard++) {
    var hit = null
    for (var i = 0; i < keys.length && !hit; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        var a = keys[i], b = keys[j]
        if (!overlaps(L[a], L[b])) continue
        // which one yields: never the dragged panel; otherwise the one further along `dir`
        var mover
        if (a === id) mover = b
        else if (b === id) mover = a
        else {
          var pa = dir === "down" ? L[a].y : dir === "right" ? L[a].x : dir === "up" ? -(L[a].y + L[a].h) : -(L[a].x + L[a].w)
          var pb = dir === "down" ? L[b].y : dir === "right" ? L[b].x : dir === "up" ? -(L[b].y + L[b].h) : -(L[b].x + L[b].w)
          mover = pa >= pb ? a : b
        }
        hit = { mover: mover, fixed: mover === a ? b : a }
        break
      }
    }
    if (!hit) break
    var m = L[hit.mover], f = L[hit.fixed]
    if (dir === "down") m.y = f.y + f.h
    else if (dir === "up") m.y = f.y - m.h
    else if (dir === "right") m.x = f.x + f.w
    else m.x = f.x - m.w
    if (!inBounds(m)) return null
    moved[hit.mover] = true
  }
  if (!valid(L)) return null
  var list = Object.keys(moved), cost = 0
  for (var n = 0; n < list.length; n++) {
    var o = layout[list[n]], p = L[list[n]]
    cost += Math.abs(o.x - p.x) + Math.abs(o.y - p.y)
  }
  return { layout: L, moved: list, cost: list.length * 1000 + cost }
}

// Put `id` at `rect` (move or resize) and resolve the fallout.
// Tries a push in each direction and keeps the cheapest; if none fits, tries swapping with
// the single panel underneath. Returns the new layout, or null when it cannot be done.
function place(layout, id, rect) {
  var r = clampRect(rect, id)
  var base = copy(layout)
  base[id] = r
  if (valid(base)) return base
  var best = null, dirs = ["down", "up", "right", "left"]
  for (var i = 0; i < dirs.length; i++) {
    var res = pushing(base, id, dirs[i])
    if (res && (!best || res.cost < best.cost)) best = res
  }
  if (best) return best.layout
  // swap fallback: exactly one panel under the drop, and it fits into the slot the dragged one left
  var under = []
  var keys = ids()
  for (var k = 0; k < keys.length; k++) if (keys[k] !== id && overlaps(r, layout[keys[k]])) under.push(keys[k])
  if (under.length === 1) {
    var old = layout[id], other = layout[under[0]]
    var sw = copy(base)
    sw[under[0]] = clampRect({ x: old.x, y: old.y, w: other.w, h: other.h }, under[0])
    if (valid(sw)) return sw
  }
  return null
}

// Like place(), but when the exact spot is impossible, snap to the closest legal one
// (searching outward a few cells), so a drag feels magnetic instead of refusing.
function placeNear(layout, id, rect, reach) {
  var r = clampRect(rect, id)
  var res = place(layout, id, r)
  if (res) return res
  var best = null, bestD = 1e9
  for (var d = 1; d <= reach; d++) {
    for (var dx = -d; dx <= d; dx++) {
      for (var dy = -d; dy <= d; dy++) {
        var dist = Math.abs(dx) + Math.abs(dy)
        if (dist !== d && Math.max(Math.abs(dx), Math.abs(dy)) !== d) continue
        if (dist >= bestD) continue
        var c = clampRect({ x: r.x + dx, y: r.y + dy, w: r.w, h: r.h }, id)
        var p = place(layout, id, c)
        if (p) { best = p; bestD = dist }
      }
    }
    if (best) return best
  }
  return null
}
