.pragma library
// AI SESSIONS data: one scan script per host (run locally or over ssh) prints sections;
// build() turns them into display rows. Pure functions, unit-tested in tests/ai.test.ts.
//
// Sections: ##NOW (epoch seconds on that host), ##AGENTS (herdr agent list JSON), ##WS (herdr
// workspace list JSON), ##PROC (tab: pid, comm, etimes|etime, cwd), ##SNIP (tab: session id,
// transcript mtime, model, last assistant text).
//
// Rows of kind "herdr" come from the host's herdr server and are clickable (herdr agent focus).
// Rows of kind "proc" are agent processes herdr does not know about: shown dim, never clickable.

// The scan itself is scan.sh (POSIX sh, Linux and macOS); DashModel loads it and runs it locally or over ssh.

function sections(text) {
  var out = {}, cur = null, lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^##([A-Z]+)\s*$/)
    if (m) { cur = m[1]; out[cur] = []; continue }
    if (cur !== null) out[cur].push(lines[i])
  }
  return out
}
function json(lines) { try { return JSON.parse((lines || []).join("\n")) } catch (e) { return null } }

function etime(t) {                              // "123" seconds, or ps etime "[[dd-]hh:]mm:ss"
  t = String(t || "").trim()
  if (/^\d+$/.test(t)) return Number(t)
  var m = t.match(/^(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)$/)
  return m ? ((Number(m[1] || 0) * 24 + Number(m[2] || 0)) * 60 + Number(m[3])) * 60 + Number(m[4]) : 0
}
function base(p) { return String(p || "").replace(/\/+$/, "").split("/").pop() }
function normCwd(p) { return String(p || "").replace(/\/+$/, "") }

// Text that came from a transcript or a remote host: decode JSON escapes, drop control and
// bidirectional-override characters, apply the user's optional strip pattern, collapse space.
function clean(s, strip) {
  s = String(s || "").replace(/\\u([0-9a-fA-F]{4})/g, function(m, h) { return String.fromCharCode(parseInt(h, 16)) })
  s = s.replace(/\\n/g, " ").replace(/\\t/g, " ").replace(/\\"/g, "\"").replace(/\\\\/g, "\\")
  s = s.replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁦-⁩﻿]/g, " ")
  if (strip) { try { s = s.replace(new RegExp(strip), "") } catch (e) {} }
  return s.replace(/\s+/g, " ").trim()
}
function shortModel(m) { return String(m || "").replace(/^claude-/, "") }

var RANK = { blocked: 0, working: 1, idle: 2, done: 3, unknown: 4 }

// opts.strip: a regular expression (string) removed from the start of each last-said snippet,
// for agents that begin every reply with a banner.
function build(text, opts) {
  var strip = opts && opts.strip ? String(opts.strip) : ""
  var sec = sections(text)
  var now = Number((sec.NOW || [])[0]) || Math.round(Date.now() / 1000)
  var agentsRaw = ((json(sec.AGENTS) || {}).result || {}).agents
  var agents = Array.isArray(agentsRaw) ? agentsRaw : []
  var wsRaw = ((json(sec.WS) || {}).result || {}).workspaces
  var wsList = Array.isArray(wsRaw) ? wsRaw : []
  var wsName = {}
  for (var w = 0; w < wsList.length; w++) if (wsList[w] && typeof wsList[w] === "object") wsName[wsList[w].workspace_id] = wsList[w].label

  var snip = {}
  var sl = sec.SNIP || []
  for (var s = 0; s < sl.length; s++) {
    var f = sl[s].split("\t"); if (f.length < 2 || !f[0]) continue
    snip[f[0]] = { mtime: Number(f[1]) || 0, model: f[2] || "", text: clean(f[3], strip) }
  }

  var rows = [], herdrKey = {}
  for (var a = 0; a < agents.length; a++) {
    var g = agents[a]
    if (!g || typeof g !== "object") continue
    var sid = (g.agent_session && g.agent_session.value) || "", sn = snip[sid] || {}
    var cwd = g.cwd || g.foreground_cwd || ""
    var kind = String(g.agent || "agent")
    var key = kind + "\0" + normCwd(cwd)
    herdrKey[key] = (herdrKey[key] || 0) + 1
    rows.push({
      kind: "herdr", paneId: String(g.pane_id || ""), agent: kind, status: String(g.agent_status || "unknown"),
      ws: String(wsName[g.workspace_id] || base(cwd) || "?"), title: clean(g.terminal_title_stripped || g.terminal_title),
      cwd: cwd, sid: sid, model: shortModel(sn.model), text: sn.text || "",
      activeSec: sn.mtime ? Math.max(0, now - sn.mtime) : -1
    })
  }
  rows.sort(function(x, y) {
    var rx = RANK[x.status] === undefined ? 4 : RANK[x.status], ry = RANK[y.status] === undefined ? 4 : RANK[y.status]
    if (rx !== ry) return rx - ry
    return (x.activeSec < 0 ? 1e12 : x.activeSec) - (y.activeSec < 0 ? 1e12 : y.activeSec)
  })

  // agent processes herdr does not own: per agent and folder, whatever exceeds herdr's count is "not in herdr"
  var procs = [], pl = sec.PROC || []
  for (var i = 0; i < pl.length; i++) {
    var p = pl[i].split("\t"); if (p.length < 3 || !/^\d+$/.test(p[0])) continue
    procs.push({ kind: "proc", provider: p[1], pid: Number(p[0]), cwd: p[3] || "", project: base(p[3]) || "?", ageSec: etime(p[2]) })
  }
  procs.sort(function(x, y) { return y.ageSec - x.ageSec })            // oldest first: herdr's sessions are the long-lived ones
  var extras = []
  for (var q = 0; q < procs.length; q++) {
    var pk = procs[q].provider + "\0" + normCwd(procs[q].cwd), left = herdrKey[pk] || 0
    if (left > 0) herdrKey[pk] = left - 1
    else extras.push(procs[q])
  }
  extras.sort(function(x, y) { return x.ageSec - y.ageSec })
  return rows.concat(extras)
}

function working(rows) { var n = 0; for (var i = 0; i < rows.length; i++) if (rows[i].kind === "herdr" && rows[i].status === "working") n++; return n }

function ago(sec) {
  if (sec < 0) return ""
  if (sec < 60) return Math.round(sec) + "s"
  if (sec < 3600) return Math.round(sec / 60) + "m"
  if (sec < 86400) return Math.round(sec / 3600) + "h"
  return Math.round(sec / 86400) + "d"
}
function homeShort(p) { return String(p || "").replace(/^\/home\/[^/]+/, "~") }

// --- finding the herdr client window on THIS machine --------------------------------------------
var SSH_ARG = { "-p": 1, "-i": 1, "-l": 1, "-o": 1, "-F": 1, "-J": 1, "-L": 1, "-R": 1, "-D": 1, "-b": 1, "-c": 1, "-e": 1, "-m": 1, "-O": 1, "-S": 1, "-W": 1, "-w": 1, "-B": 1, "-E": 1, "-I": 1, "-Q": 1 }
function tokens(args) { return String(args || "").split(/\s+/).filter(function(t) { return t !== "" }) }
// the host ssh connects to and what it runs there: "ssh -p 22 me@box herdr" -> { host: "box", cmd: "herdr" }
function sshTarget(args) {
  var t = tokens(args), i = 0
  if (t[0] && /(^|\/)ssh$/.test(t[0])) i = 1
  for (; i < t.length; i++) {
    if (t[i] === "--") { i++; break }
    if (t[i].charAt(0) !== "-") break
    if (SSH_ARG[t[i]]) i++
  }
  if (i >= t.length) return null
  return { host: t[i].replace(/^[^@]*@/, ""), cmd: t.slice(i + 1).join(" ") }
}
// a herdr process that is a CLIENT (not the server). Returns { remote: <profile or ssh target or ""> } or null.
function herdrClient(args) {
  var t = tokens(args)
  if (t.indexOf("server") >= 0) return null
  var remote = ""
  for (var i = 0; i < t.length; i++) if ((t[i] === "--machine" || t[i] === "--remote" || t[i] === "-m") && t[i + 1]) remote = t[i + 1].replace(/^[^@]*@/, "")
  return { remote: remote }
}

// clientsText = `hyprctl clients -j`, psText = `ps -eo pid=,ppid=,comm=,args=`. Returns the Hyprland
// window address or "". Only process evidence selects a window (a window title alone never does):
//   host === ""  a window running a herdr client for a LOCAL server;
//   host !== ""  a window running `herdr --machine/--remote <host>`, or `ssh <host>` (running herdr, or
//                a plain interactive ssh whose title herdr set to "<host>: ...").
// Ties go to the most recently focused window.
function findHerdrWindow(clientsText, psText, host) {
  var clients; try { clients = JSON.parse(clientsText) } catch (e) { return "" }
  if (!Array.isArray(clients)) return ""
  var kids = {}, info = {}, lines = String(psText || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s*(.*)$/); if (!m) continue
    info[m[1]] = { comm: m[3], args: m[4] }
    ;(kids[m[2]] = kids[m[2]] || []).push(m[1])
  }
  var pidCount = {}
  for (var c0 = 0; c0 < clients.length; c0++) if (clients[c0]) pidCount[clients[c0].pid] = (pidCount[clients[c0].pid] || 0) + 1
  var best = "", bestScore = 0, bestFocus = 1e9
  for (var c = 0; c < clients.length; c++) {
    var cl = clients[c]
    if (!cl || typeof cl !== "object" || cl.mapped === false || cl.hidden === true) continue
    var title = String(cl.title || ""), score = 0
    var titled = host !== "" && title.indexOf(host + ":") === 0
    var queue = [String(cl.pid)], seen = 0, visited = {}
    while (queue.length && seen < 300) {
      var pid = queue.shift(); if (visited[pid]) continue
      visited[pid] = true; seen++
      var inf = info[pid]
      if (inf) {
        if (inf.comm === "herdr") {
          var hc = herdrClient(inf.args)
          if (hc) {
            if (host === "" && hc.remote === "") score = Math.max(score, 3)
            else if (host !== "" && hc.remote === host) score = Math.max(score, 3)
          }
        } else if (host !== "" && inf.comm === "ssh") {
          var st = sshTarget(inf.args)
          if (st && st.host === host && (st.cmd === "" ? titled : /(^|\s)herdr(\s|$)/.test(st.cmd))) score = Math.max(score, 2)
        }
      }
      var ch = kids[pid] || []
      for (var k = 0; k < ch.length; k++) queue.push(ch[k])
    }
    // terminals that share one process (several windows, one pid) cannot be told apart by their
    // process tree; only the title can
    if (score > 0 && pidCount[cl.pid] > 1 && !titled && !(host === "" && /herdr/i.test(title))) score = 0
    var focus = cl.focusHistoryID === undefined ? 1e8 : Number(cl.focusHistoryID)
    if (score >= 2 && (score > bestScore || (score === bestScore && focus < bestFocus))) { best = String(cl.address); bestScore = score; bestFocus = focus }
  }
  return best
}
