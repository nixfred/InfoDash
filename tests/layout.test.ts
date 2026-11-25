import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";

// Layout.js is a QML ".pragma library": strip the pragma and load it as plain JS.
const src = readFileSync(new URL("../Layout.js", import.meta.url), "utf8").replace(/^\.pragma library.*$/m, "");
const L: any = new Function(src + "; return { COLS, ROWS, MINS, defaults, ids, valid, sanitize, overlaps, clampRect, place, placeNear, copy, copyRect };")();

test("default layout is legal and tiles the whole grid", () => {
  const d = L.defaults();
  expect(L.valid(d)).toBe(true);
  let area = 0;
  for (const k of L.ids()) area += d[k].w * d[k].h;
  expect(area).toBe(L.COLS * L.ROWS);
});

test("sanitize falls back to defaults for junk or overlapping saves", () => {
  expect(L.sanitize(null)).toEqual(L.defaults());
  const bad = L.defaults(); bad.cpu = { ...bad.usb };
  expect(L.sanitize(bad)).toEqual(L.defaults());
  const small = L.defaults(); small.ledger.w = 2;
  expect(L.sanitize(small)).toEqual(L.defaults());
});

test("move into free space: no one else moves", () => {
  const d = L.defaults();
  d.cpu = { x: 28, y: 0, w: 10, h: 5 };           // shrink to its minimum: rows 5-6 become free
  expect(L.valid(d)).toBe(true);
  const r = L.place(d, "cpu", { x: 28, y: 2, w: 10, h: 5 });
  expect(r).not.toBeNull();
  expect(r.fleet).toEqual(d.fleet);
  expect(r.gfx).toEqual(d.gfx);
  expect(r.cpu).toEqual({ x: 28, y: 2, w: 10, h: 5 });
});

test("move onto another panel pushes it clear, nothing overlaps", () => {
  const d = L.defaults();
  const r = L.place(d, "stg", { x: 28, y: 7, w: 10, h: 7 });   // storage onto graphics (same size, packed)
  expect(r).not.toBeNull();
  expect(L.valid(r)).toBe(true);
  expect(r.stg).toEqual({ x: 28, y: 7, w: 10, h: 7 });
  expect(r.gfx).not.toEqual(d.gfx);
});

test("a push chains: pushed panels push the next one", () => {
  const e = L.defaults();
  e.pw = { x: 0, y: 14, w: 24, h: 4 }; e.np = { x: 24, y: 14, w: 24, h: 4 };
  e.ledger = { x: 0, y: 18, w: 48, h: 3 };   // rows 21..23 free
  expect(L.valid(e)).toBe(true);
  const r = L.place(e, "ai", { x: 0, y: 2, w: 16, h: 14 }); // ai slides down over pw, which pushes ledger
  expect(r).not.toBeNull();
  expect(L.valid(r)).toBe(true);
  expect(r.pw.y).toBe(16);
  expect(r.ledger.y).toBeGreaterThanOrEqual(20);
});

test("impossible push returns null instead of a broken layout", () => {
  const d = L.defaults();                       // fully packed
  const r = L.place(d, "ledger", { x: 0, y: 0, w: 48, h: 24 });
  expect(r === null || L.valid(r)).toBe(true);
});

test("resize cannot go below the minimum and stays in the grid", () => {
  const d = L.defaults();
  const r = L.place(d, "ai", { x: 0, y: 0, w: 1, h: 1 });
  if (r) { expect(r.ai.w).toBeGreaterThanOrEqual(L.MINS.ai.w); expect(r.ai.h).toBeGreaterThanOrEqual(L.MINS.ai.h); }
  const c = L.clampRect({ x: 60, y: 40, w: 100, h: 100 }, "cpu");
  expect(c.x + c.w).toBeLessThanOrEqual(L.COLS);
  expect(c.y + c.h).toBeLessThanOrEqual(L.ROWS);
});

test("swap fallback on a packed screen", () => {
  const d = L.defaults();
  const r = L.place(d, "cpu", { x: 38, y: 0, w: 10, h: 7 });   // onto mem, same size, grid full
  expect(r).not.toBeNull();
  expect(L.valid(r)).toBe(true);
  expect(r.cpu.x).toBe(38);
  expect(r.mem.x).toBe(28);
});

test("randomised moves always leave a legal layout or null", () => {
  let seed = 7; const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  let cur = L.defaults();
  for (let i = 0; i < 2000; i++) {
    const id = L.ids()[Math.floor(rnd() * 10)];
    const o = cur[id];
    const rect = rnd() < 0.5
      ? { x: Math.floor(rnd() * 48), y: Math.floor(rnd() * 24), w: o.w, h: o.h }
      : { x: o.x, y: o.y, w: 1 + Math.floor(rnd() * 20), h: 1 + Math.floor(rnd() * 12) };
    const r = L.place(cur, id, rect);
    if (r) { expect(L.valid(r)).toBe(true); cur = r; }
  }
});

test("placeNear snaps a half-slot drop on a packed screen to a legal spot", () => {
  const d = L.defaults();
  const exact = L.place(d, "cpu", { x: 21, y: 0, w: 10, h: 7 });
  expect(exact).toBeNull();                       // a half-slot drop cannot be satisfied exactly
  const near = L.placeNear(d, "cpu", { x: 21, y: 0, w: 10, h: 7 }, 8);
  expect(near).not.toBeNull();
  expect(L.valid(near)).toBe(true);
});

test("sanitize: missing, out-of-bounds, non-numeric, overlapping and too-small saves all fall back; extra keys and fractions are tolerated", () => {
  const d = L.defaults();
  const miss = L.copy(d); delete miss.cpu;
  expect(L.sanitize(miss)).toEqual(d);
  const oob = L.copy(d); oob.cpu.x = 47;
  expect(L.sanitize(oob)).toEqual(d);
  const nan = L.copy(d); (nan as any).cpu.w = "10";
  expect(L.sanitize(nan)).toEqual(d);
  const extra = L.copy(d); (extra as any).future = { x: 0, y: 0, w: 1, h: 1 };
  expect(L.sanitize(extra)).toEqual(d);                                   // unknown ids are ignored, a valid layout survives
  const frac = L.copy(d); frac.cpu = { x: 28.2, y: 0.4, w: 9.9, h: 7.1 };
  expect(L.valid(L.sanitize(frac))).toBe(true);
  expect(L.sanitize(5)).toEqual(d); expect(L.sanitize([])).toEqual(d);
});

test("placeNear fuzz: the dragged panel lands where asked or nearby, nothing overlaps, nobody else changes size", () => {
  let seed = 12345; const rnd = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  let cur = L.defaults();
  for (let i = 0; i < 3000; i++) {
    const id = L.ids()[Math.floor(rnd() * 10)], o = cur[id];
    const rect = rnd() < 0.5
      ? { x: Math.floor(rnd() * 48), y: Math.floor(rnd() * 24), w: o.w, h: o.h }
      : { x: o.x, y: o.y, w: L.MINS[id].w + Math.floor(rnd() * 12), h: L.MINS[id].h + Math.floor(rnd() * 8) };
    const r = L.placeNear(cur, id, rect, 8);
    if (!r) continue;
    expect(L.valid(r)).toBe(true);
    for (const k of L.ids()) if (k !== id) { expect(r[k].w).toBe(cur[k].w); expect(r[k].h).toBe(cur[k].h); }
    cur = r;
  }
});

test("an impossible placement is refused (null), never a broken layout", () => {
  const d = L.defaults();
  const r = L.place(d, "ledger", { x: 0, y: 0, w: 48, h: 24 });
  expect(r === null).toBe(true);
});
