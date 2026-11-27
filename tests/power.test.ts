import { test, expect } from "bun:test";
import { parseActiveProfile, POWER_PROFILE_CMD } from "../power.ts";

test("the real busctl reply gives the profile name", () => {
  expect(parseActiveProfile('{"type":"s","data":"performance"}\n')).toBe("performance");
  expect(parseActiveProfile('{"type":"s","data":" power-saver "}')).toBe("power-saver");
});

test("empty or garbage output gives an empty string", () => {
  for (const t of ["", "  \n", "not json", "{", "null", "42", '{"type":"s"}', '{"data":5}'])
    expect(parseActiveProfile(t)).toBe("");
});

test("the command is the stock Omarchy busctl read, not powerprofilesctl", () => {
  expect(POWER_PROFILE_CMD[0]).toBe("busctl");
  expect(POWER_PROFILE_CMD).not.toContain("powerprofilesctl");
});
