import { test, expect } from "bun:test";
import { pickFleet } from "../fleet.ts";

const rows = ["me", "alpha-gw", "beta", "gamma"].map((name) => ({ name, dns: name === "alpha-gw" ? "alpha" : name }));
const names = (r: { name: string }[]) => r.map((x) => x.name);

test("an ignored host is never shown, by host name or DNS name", () => {
  expect(names(pickFleet(rows, [], ["alpha-gw"]))).toEqual(["me", "beta", "gamma"]);
  expect(names(pickFleet(rows, [], ["alpha"]))).toEqual(["me", "beta", "gamma"]);
});
test("ignore beats pin", () => {
  expect(names(pickFleet(rows, ["alpha", "beta"], ["alpha-gw"]))).toEqual(["beta"]);
});
test("an ignored host does not use up one of the places", () => {
  expect(names(pickFleet(rows, [], ["alpha"], 2))).toEqual(["me", "beta"]);
});
test("pins keep their order, match either name and never repeat", () => {
  expect(names(pickFleet(rows, ["gamma", "alpha-gw", "alpha"], []))).toEqual(["gamma", "alpha-gw"]);
});
test("a host pinned by its DNS name is shown under that name", () => {
  expect(pickFleet(rows, ["alpha"], [])).toEqual([{ name: "alpha", dns: "alpha" }]);
});
