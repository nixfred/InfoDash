import { test, expect } from "bun:test";
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, chmodSync, rmSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const src = readFileSync(new URL("../Ai.js", import.meta.url), "utf8").replace(/^\.pragma library.*$/m, "");
const SCRIPT = readFileSync(new URL("../scan.sh", import.meta.url), "utf8");
const A: any = new Function(src + "; return { sections, build, working, ago, etime, homeShort, clean, findHerdrWindow, sshTarget };")();

const agent = (o: any) => ({ agent: "claude", agent_status: "idle", cwd: "/p/a", pane_id: "w1:p1", workspace_id: "w1", terminal_title_stripped: "T", agent_session: { value: "id1" }, ...o });
const scan = (agents: any[], ws: any[], proc = "", snip = "") =>
  `##NOW\n1000\n##AGENTS\n${JSON.stringify({ result: { agents } })}\n##WS\n${JSON.stringify({ result: { workspaces: ws } })}\n##PROC\n${proc}\n##SNIP\n${snip}\n`;

test("herdr agents become clickable rows with workspace, title, status and last activity", () => {
  const rows = A.build(scan([agent({ agent_status: "working", terminal_title_stripped: "Fix the picker", agent_session: { value: "s1" } })],
    [{ workspace_id: "w1", label: "project-x" }], "", "s1\t940\tclaude-opus-5-5\tDone, the strip is even now."));
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ kind: "herdr", paneId: "w1:p1", ws: "project-x", title: "Fix the picker", status: "working", model: "opus-5-5", activeSec: 60 });
  expect(rows[0].text).toBe("Done, the strip is even now.");
});
test("blocked first, then working, then by most recent activity", () => {
  const rows = A.build(scan([
    agent({ pane_id: "p1", agent_status: "idle", agent_session: { value: "a" } }),
    agent({ pane_id: "p2", agent_status: "working", agent_session: { value: "b" } }),
    agent({ pane_id: "p3", agent_status: "blocked", agent_session: { value: "c" } }),
    agent({ pane_id: "p4", agent_status: "idle", agent_session: { value: "d" } })], [], "", "a\t100\t\t\nd\t900\t\t"));
  expect(rows.map((r: any) => r.paneId)).toEqual(["p3", "p2", "p4", "p1"]);
});
test("processes herdr does not own appear as non-herdr extras, per agent and folder", () => {
  const rows = A.build(scan([agent({ cwd: "/p/a" })], [], "11\tclaude\t500\t/p/a\n12\tclaude\t100\t/p/a\n13\tcodex\t50\t/p/b\n14\tcodex\t60\t/p/a"));
  expect(rows.filter((r: any) => r.kind === "herdr")).toHaveLength(1);
  expect(rows.filter((r: any) => r.kind === "proc").map((r: any) => r.pid).sort()).toEqual([12, 13, 14]);   // a codex in the same folder is NOT swallowed by herdr's claude
});
test("a trailing slash in the folder does not split one agent into two rows", () => {
  const rows = A.build(scan([agent({ cwd: "/p/a/" })], [], "11\tclaude\t500\t/p/a"));
  expect(rows).toHaveLength(1);
});
test("works with no herdr at all: every process is a dim row", () => {
  const rows = A.build("##NOW\n1\n##AGENTS\n\n##WS\n\n##PROC\n7\tclaude\t2-03:04:05\t/x/y\n##SNIP\n");
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ kind: "proc", pid: 7, project: "y", ageSec: (2 * 24 + 3) * 3600 + 4 * 60 + 5 });
});
test("junk, empty and null entries never throw", () => {
  expect(A.build("")).toEqual([]);
  expect(A.build("##AGENTS\nnot json\n##PROC\ngarbage")).toEqual([]);
  expect(A.build(`##NOW\n1\n##AGENTS\n{"result":{"agents":[null,5,"x",{"pane_id":"p"}]}}\n##WS\n{"result":{"workspaces":[null,3]}}\n##PROC\n##SNIP\n`)).toHaveLength(1);
  expect(A.build(`##AGENTS\n{"result":{"agents":"nope"}}\n##WS\n{"result":{"workspaces":{"a":1}}}\n`)).toEqual([]);
});
test("helpers", () => {
  expect(A.ago(30)).toBe("30s"); expect(A.ago(7200)).toBe("2h"); expect(A.ago(-1)).toBe("");
  expect(A.homeShort("/home/alice/x/y")).toBe("~/x/y");
  expect(A.working(A.build(scan([agent({ agent_status: "working" }), agent({ pane_id: "q", agent_status: "idle" })], [])))).toBe(1);
});
test("a command that prints no trailing newline cannot swallow the next section header", () => {
  const txt = "##NOW\n1\n##AGENTS\n\n##WS\n{\"result\":{\"workspaces\":[]}}\n##PROC\n7\tclaude\t5\t/a/b\n##SNIP\n";
  expect(A.build(txt).map((r: any) => r.pid)).toEqual([7]);
  expect(SCRIPT).toContain("herdr workspace list 2>/dev/null; echo");
});
test("snippets: JSON escapes decoded, control and bidi characters removed, optional strip pattern applied", () => {
  expect(A.clean("He said \\\"hi\\\" there\\nand \\u00e9")).toBe("He said \"hi\" there and é");
  expect(A.clean("abc‮def\u0007ghi")).toBe("abc def ghi");
  expect(A.clean("BANNER v1 ==== Real content", "^BANNER[^=]*=+\\s*")).toBe("Real content");
  expect(A.clean("text", "(unclosed")).toBe("text");                       // a bad pattern is ignored, never thrown
});

// ---- the real scan script, against a fake HOME and a stub herdr, so SNIP, quoting and the cache are exercised
function withFakeHost(fn: (env: any, home: string) => void) {
  const home = mkdtempSync(join(tmpdir(), "infodash-test-"));
  try {
    mkdirSync(join(home, "bin")); mkdirSync(join(home, ".claude/projects/-proj"), { recursive: true });
    const agents = { result: { agents: [{ agent: "claude", agent_status: "idle", cwd: "/p/a", pane_id: "w1:p1", workspace_id: "w1", terminal_title_stripped: "T", agent_session: { value: "11111111-aaaa" } }] } };
    writeFileSync(join(home, "agents.json"), JSON.stringify(agents));
    writeFileSync(join(home, "bin/herdr"), `#!/bin/sh\ncase "$1 $2" in "agent list") cat ${home}/agents.json;; "workspace list") printf '{"result":{"workspaces":[{"workspace_id":"w1","label":"proj"}]}}';; esac\n`);
    chmodSync(join(home, "bin/herdr"), 0o755);
    const line = JSON.stringify({ type: "assistant", message: { role: "assistant", model: "claude-sonnet-5-5", content: [{ type: "text", text: 'He said "hi" there and more words' }] } });
    writeFileSync(join(home, ".claude/projects/-proj/11111111-aaaa.jsonl"), line + "\n");
    fn({ ...process.env, HOME: home, PATH: `${home}/bin:${process.env.PATH}` }, home);
  } finally { rmSync(home, { recursive: true, force: true }); }
}
test("scan script: every section, escaped quotes survive, model found, cache written and reused", () => {
  withFakeHost((env, home) => {
    const run = () => execFileSync("sh", ["-c", SCRIPT], { encoding: "utf8", env, timeout: 20000 });
    const out = run();
    for (const s of ["##NOW", "##AGENTS", "##WS", "##PROC", "##SNIP"]) expect(out).toContain(s);
    const rows = A.build(out);
    const r = rows.find((x: any) => x.kind === "herdr");
    expect(r.ws).toBe("proj");
    expect(r.model).toBe("sonnet-5-5");
    expect(r.text).toBe('He said "hi" there and more words');          // the sed cut this at the first escaped quote before
    expect(readFileSync(join(home, ".cache/infodash/11111111-aaaa"), "utf8")).toContain("sonnet-5-5");
    writeFileSync(join(home, ".cache/infodash/11111111-aaaa"), readFileSync(join(home, ".cache/infodash/11111111-aaaa"), "utf8").replace("He said", "CACHED"));
    expect(run()).toContain("CACHED");                                    // same mtime: the cached line is reused, not recomputed
  });
});
test("scan script survives a missing herdr and a missing transcript dir", () => {
  const home = mkdtempSync(join(tmpdir(), "infodash-test-"));
  try {
    const out = execFileSync("sh", ["-c", SCRIPT], { encoding: "utf8", env: { PATH: "/usr/bin:/bin", HOME: home }, timeout: 20000 });
    for (const s of ["##NOW", "##AGENTS", "##WS", "##PROC", "##SNIP"]) expect(out).toContain(s);
    expect(Array.isArray(A.build(out))).toBe(true);
  } finally { rmSync(home, { recursive: true, force: true }); }
});

// ---- finding the herdr client window
const clients = (list: any[]) => JSON.stringify(list.map((c, i) => ({ address: "0x" + (100 + i), pid: 1000 + i * 10, title: "", class: "kitty", mapped: true, hidden: false, focusHistoryID: i, ...c })));
const ps = (rows: string[]) => rows.join("\n");

test("remote host: a window running ssh to that host whose title herdr set to 'host: <workspace>'", () => {
  const cl = clients([{ title: "Brave", class: "brave" }, { title: "larry: infodash", pid: 2000, address: "0xAA" }]);
  expect(A.findHerdrWindow(cl, ps(["2000 1 kitty kitty", "2001 2000 bash bash --posix", "2002 2001 ssh ssh larry"]), "larry")).toBe("0xAA");
});
test("remote host: ssh running herdr, or herdr --machine, needs no title", () => {
  const cl = clients([{ title: "~", pid: 3000, address: "0xBB" }, { title: "~", pid: 3100, address: "0xCC" }]);
  const p = ps(["3000 1 kitty kitty", "3001 3000 ssh ssh -t me@larry herdr", "3100 1 kitty kitty", "3101 3100 herdr herdr --machine larry"]);
  expect(A.findHerdrWindow(cl, p, "larry")).toBe("0xCC");               // a herdr client for that machine is stronger evidence than ssh
  expect(A.findHerdrWindow(cl, ps(["3000 1 kitty kitty", "3001 3000 ssh ssh -t me@larry herdr"]), "larry")).toBe("0xBB");
  const tie = clients([{ title: "~", pid: 3000, address: "0xBB", focusHistoryID: 5 }, { title: "~", pid: 3100, address: "0xCC", focusHistoryID: 1 }]);
  expect(A.findHerdrWindow(tie, ps(["3000 1 kitty kitty", "3001 3000 ssh ssh larry herdr", "3100 1 kitty kitty", "3101 3100 ssh ssh larry herdr"]), "larry")).toBe("0xCC");   // equal evidence: most recently focused
});
test("a plain interactive ssh shell with an unrelated title is NOT a herdr window", () => {
  const cl = clients([{ title: "~", pid: 3000, address: "0xBB" }]);
  expect(A.findHerdrWindow(cl, ps(["3000 1 kitty kitty", "3001 3000 ssh ssh larry"]), "larry")).toBe("");
});
test("a title alone never selects a window (a web page can set any title)", () => {
  const cl = clients([{ title: "larry: pwned - Brave", pid: 6000, address: "0xDD", class: "brave" }]);
  expect(A.findHerdrWindow(cl, ps(["6000 1 brave brave"]), "larry")).toBe("");
});
test("never picks another host, a lookalike host name, or an ssh whose host only appears as a later word", () => {
  const cl = clients([{ title: "gus: x", pid: 4000, address: "0xCC" }, { title: "larry: y", pid: 4100, address: "0xDD" }, { title: "z", pid: 4200, address: "0xEE" }]);
  const p = ps(["4000 1 kitty kitty", "4001 4000 ssh ssh gus", "4100 1 kitty kitty", "4101 4100 ssh ssh larryx", "4102 4100 ssh ssh my-larry", "4200 1 kitty kitty", "4201 4200 ssh ssh gus tail -f larry"]);
  expect(A.findHerdrWindow(cl, p, "larry")).toBe("");
});
test("local herdr: a client, not the server, and not a client attached to a remote machine", () => {
  const cl = clients([{ title: "~", pid: 5000, address: "0xEE" }, { title: "x", pid: 5100, address: "0xFF" }, { title: "y", pid: 5200, address: "0x11" }]);
  const p = ps(["5000 1 kitty kitty", "5001 5000 herdr herdr", "5100 1 kitty kitty", "5101 5100 herdr herdr server", "5200 1 kitty kitty", "5201 5200 herdr herdr --machine larry"]);
  expect(A.findHerdrWindow(cl, p, "")).toBe("0xEE");
  expect(A.findHerdrWindow(cl, ps(["5200 1 kitty kitty", "5201 5200 herdr herdr --machine larry"]), "")).toBe("");
});
test("hidden and unmapped windows are skipped; windows sharing one process need a title", () => {
  const p = ps(["7000 1 term term", "7001 7000 herdr herdr"]);
  expect(A.findHerdrWindow(clients([{ pid: 7000, address: "0xA1", hidden: true }]), p, "")).toBe("");
  expect(A.findHerdrWindow(clients([{ pid: 7000, address: "0xA2", mapped: false }]), p, "")).toBe("");
  expect(A.findHerdrWindow(clients([{ pid: 7000, address: "0xA3", title: "shell" }, { pid: 7000, address: "0xA4", title: "herdr" }]), p, "")).toBe("0xA4");
});
test("no window, junk input and empty lists return an empty address", () => {
  expect(A.findHerdrWindow("[]", "", "larry")).toBe("");
  expect(A.findHerdrWindow("not json", "", "")).toBe("");
  expect(A.findHerdrWindow("null", "", "")).toBe("");
  expect(A.findHerdrWindow(clients([{ title: "x" }]), "garbage", "")).toBe("");
});
test("sshTarget parses options, user@host and the remote command", () => {
  expect(A.sshTarget("ssh larry")).toEqual({ host: "larry", cmd: "" });
  expect(A.sshTarget("ssh -p 2222 -i /k me@box herdr --x")).toEqual({ host: "box", cmd: "herdr --x" });
  expect(A.sshTarget("ssh -o BatchMode=yes -- box ls")).toEqual({ host: "box", cmd: "ls" });
  expect(A.sshTarget("ssh")).toBeNull();
});
