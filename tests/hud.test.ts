import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("../Hud.js", import.meta.url), "utf8").replace(/^\.pragma library.*$/m, "");
const H: any = new Function(src + "; return { gridFit };")();

test("the CPU grid never leaves an orphan row", () => {
  for (let n = 1; n <= 128; n++) {
    const g = H.gridFit(n, 160, 220);
    expect(g.cols * g.rows).toBe(n);
  }
});
test("it picks the shape that gives the biggest tiles", () => {
  expect(H.gridFit(24, 160, 220)).toEqual({ cols: 4, rows: 6 });
  expect(H.gridFit(24, 320, 150)).toEqual({ cols: 8, rows: 3 });
  expect(H.gridFit(16, 200, 200)).toEqual({ cols: 4, rows: 4 });
});
test("no CPUs yet means an empty grid", () => {
  expect(H.gridFit(0, 160, 220)).toEqual({ cols: 0, rows: 0 });
});
