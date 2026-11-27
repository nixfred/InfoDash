import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import "Layout.js" as Layout
import "Skins.js" as Skins
import "Ai.js" as Ai

// One data model per surface. Runs collector.ts as a single long-lived process
// (one JSON line per tick) and exposes the active Omarchy theme as colours, so
// the HUD restyles itself on every theme switch.
Item {
  id: root
  property bool active: true
  property int intervalMs: 2000
  property var snap: ({})
  property bool ready: false
  property string error: ""
  readonly property string collectorPath: Qt.resolvedUrl("collector.ts").toString().replace(/^file:\/\//, "")
  readonly property string version: "0.2.5"

  // --- layout store ------------------------------------------------------------
  // One file for every monitor: { "version": 1, "screens": { "DP-3": { panelId: {x,y,w,h} } } }.
  // Shared by the desk and the overlay (separate instances): each watches the file, so a
  // move made in one shows in the other. Same layout whatever the theme.
  readonly property string layoutDir: Quickshell.env("HOME") + "/.config/omarchy/infodash"
  property var layouts: ({})
  function layoutFor(screen) { return Layout.sanitize(root.layouts[screen]) }
  function commitLayout(screen, layout) {
    var all = {}
    for (var k in root.layouts) all[k] = root.layouts[k]
    all[screen] = layout
    root.layouts = all
    layoutFile.setText(JSON.stringify({ version: 1, screens: all }, null, 1))
  }
  function resetLayout(screen) { root.commitLayout(screen, Layout.defaults()) }
  Process { id: mkLayoutDir; command: ["mkdir", "-p", root.layoutDir]; running: true }
  FileView {
    id: layoutFile
    path: root.layoutDir + "/layout.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { var o = JSON.parse(text()); if (o && typeof o.screens === "object" && o.screens !== null && !Array.isArray(o.screens)) root.layouts = o.screens } catch (e) {}
    }
  }

  // --- settings: global, shared by desk and overlay through one watched file -------------
  // ~/.config/omarchy/infodash/settings.json
  //   { "skin": id, "aiHost": "" | host name, "fontScale": 0.8 to 1.5,
  //     "fleet": ["host", ...]  (tailnet hosts to pin in the fleet panel; default: the first 8 peers),
  //     "fleetIgnore": ["host", ...]  (tailnet hosts that are never shown),
  //     "snippetStrip": "regex"  (removed from the start of each last-said snippet) }
  property string skinId: Skins.DEFAULT
  property string aiHost: ""                 // "" = agent sessions of THIS machine
  property real fontScale: 1.0               // InfoDash's own text/UI size, independent of the system font size
  property var fleet: []
  property var fleetIgnore: []
  property string snippetStrip: ""
  property bool settingsReady: false         // the file has been read (or found missing): scans may start
  property string _lastWritten: ""           // the newest file content this instance knows (its own write or the last reload)
  readonly property real fontMin: 0.8
  readonly property real fontMax: 1.5
  // Host names reach ssh, so only plain tailnet-style names are accepted (never a leading dash).
  function validHost(h) { return h === "" || /^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$/.test(h) }
  // Write only the given keys, merged into the newest known content, so an instance holding a stale
  // copy cannot clobber a change made by the other one.
  function saveSettings(patch) {
    var cur = {}
    try { cur = JSON.parse(root._lastWritten !== "" ? root._lastWritten : settingsFile.text()) } catch (e) { cur = {} }
    if (typeof cur !== "object" || cur === null || Array.isArray(cur)) cur = {}
    cur.version = 1
    for (var k in patch) cur[k] = patch[k]
    var t = JSON.stringify(cur, null, 1)
    root._lastWritten = t
    settingsFile.setText(t)
  }
  function setSkin(id) {
    if (!Skins.valid(id)) return false
    root.skinId = id; root.saveSettings({ skin: id }); return true
  }
  function setFontScale(v) {
    v = Number(v)
    if (!isFinite(v)) return false
    root.fontScale = Math.round(Math.max(root.fontMin, Math.min(root.fontMax, v)) * 100) / 100
    root.saveSettings({ fontScale: root.fontScale }); return true
  }
  function setAiHost(h) {
    h = String(h || "").trim()
    if (!root.validHost(h)) return false
    root.aiHost = h; root.aiData = null; root.saveSettings({ aiHost: h })
    root.kickScan()
    return true
  }
  FileView {
    id: settingsFile
    path: root.layoutDir + "/settings.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoadFailed: root.settingsReady = true
    onLoaded: {
      var t = text()
      if (t === root._lastWritten) { root.settingsReady = true; return }      // the echo of our own write
      root._lastWritten = t
      try {
        var o = JSON.parse(t)
        if (o && Skins.valid(o.skin)) root.skinId = o.skin
        if (o && typeof o.fontScale === "number" && o.fontScale >= root.fontMin && o.fontScale <= root.fontMax) root.fontScale = o.fontScale
        if (o && typeof o.aiHost === "string" && root.validHost(o.aiHost) && o.aiHost !== root.aiHost) { root.aiHost = o.aiHost; root.aiData = null; root.kickScan() }
        function hostList(a) { return Array.isArray(a) ? a.filter(function(h) { return typeof h === "string" && h !== "" && root.validHost(h) }).slice(0, 16) : [] }
        if (o) { root.fleet = hostList(o.fleet); root.fleetIgnore = hostList(o.fleetIgnore) }
        if (o && typeof o.snippetStrip === "string" && o.snippetStrip.length < 400) root.snippetStrip = o.snippetStrip
      } catch (e) {}
      root.settingsReady = true
    }
  }

  // --- AI sessions: this machine or another tailnet host --------------------------------------
  // One scan script (Ai.js) per host: herdr's agent list + workspaces, agent processes, and the
  // last thing each Claude session said. Local = sh -c, remote = ssh with a multiplexed connection,
  // every 5 s while the dashboard is visible. Every external command runs under `timeout` with its
  // output capped, and a watchdog kills a scan that is still running after 20 s, so one dead host
  // can never freeze the panel.
  property var aiData: null                  // { host, rows: [...], error: "", ts }
  property string _aiErr: ""
  property string _script: ""                // scan.sh, loaded below
  FileView { id: scanFile; path: Qt.resolvedUrl("scan.sh").toString().replace(/^file:\/\//, ""); onLoaded: root._script = text() }
  property string _runHost: ""               // the host the scan in flight was started for
  readonly property var _sshBase: ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4",
                                   "-o", "ServerAliveInterval=3", "-o", "ServerAliveCountMax=2",
                                   "-o", "ControlMaster=auto", "-o", "ControlPersist=90",
                                   "-o", "ControlPath=" + Quickshell.env("HOME") + "/.cache/infodash-ssh-%C",
                                   "-o", "ForwardAgent=no", "-o", "ForwardX11=no", "-o", "ClearAllForwardings=yes",
                                   "-o", "PermitLocalCommand=no", "-o", "RequestTTY=no"]
  // sh -c WRAP sh <command...>: run the command under `timeout` when it exists, cap what it may print
  readonly property string _wrap: "T=; command -v timeout >/dev/null 2>&1 && T=\"timeout -k 2 15\"; $T \"$@\" | head -c 1048576"
  Process { id: aiCacheDir; command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache"]; running: true }
  Timer {
    id: aiFetchTimer
    interval: 5000; repeat: true; triggeredOnStart: true
    running: root.active && root.settingsReady && root._script !== ""
    onTriggered: root.startScan()
  }
  Timer { id: aiWatchdog; interval: 20000; running: aiFetch.running; onTriggered: aiFetch.running = false }
  Timer { id: aiKick; interval: 300; onTriggered: root.startScan() }
  function startScan() { if (!aiFetch.running && root.settingsReady && root._script !== "") { root._runHost = root.aiHost; aiFetch.running = true } }
  // a host change: stop the scan in flight (it is for the old host), then scan the new one
  function kickScan() { aiFetch.running = false; aiKick.restart() }
  Process {
    id: aiFetch
    readonly property string b64: Qt.btoa(root._script)
    command: ["sh", "-c", root._wrap, "sh"].concat(root._runHost === ""
      ? ["sh", "-c", root._script]
      : root._sshBase.concat(["--", root._runHost, "echo " + b64 + " | base64 -d | sh"]))
    stdout: StdioCollector {
      onStreamFinished: {
        if (root._runHost !== root.aiHost) return                     // a late result for a host that is no longer selected
        root.aiData = Ai.scanResult(root.aiData, root._runHost, String(text), root.snippetStrip, Date.now())
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (root._runHost !== root.aiHost) return
        var e = String(text).trim().split("\n").pop()
        if (e !== "") root.aiData = Ai.scanError(root.aiData, root._runHost, e)
      }
    }
  }
  // Click on a session: (1) focus its pane in herdr on that host, (2) if that worked, raise the
  // herdr client window on THIS machine so the user's own focus lands on it. If the session is not
  // open in herdr nothing happens (its row is not clickable, and herdr refuses an unknown pane).
  property string focusHost: ""
  signal focusJumped()
  // The two links in the header. Only these exact addresses are ever opened, in the default browser;
  // the summon overlay closes so the browser is not hidden behind it.
  readonly property var links: ({ site: "https://nixfred.com", repo: "https://github.com/nixfred/InfoDash" })
  function openLink(which) {
    var url = root.links[which]
    if (!url) return
    Quickshell.execDetached(["xdg-open", url])
    root.focusJumped()
  }
  Process {
    id: aiFocus
    onExited: function(code) { if (code === 0 && !winFind.running) winFind.running = true }
  }
  Timer { id: aiFocusWatchdog; interval: 15000; running: aiFocus.running; onTriggered: aiFocus.running = false }
  Process {
    id: winFind
    command: ["sh", "-c", "hyprctl clients -j; echo '##PS'; ps -eo pid=,ppid=,comm=,args="]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = String(text).split("##PS")
        var addr = Ai.findHerdrWindow(parts[0], parts[1] || "", root.focusHost)
        if (addr !== "" && /^0x[0-9a-f]+$/.test(addr)) { Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })"); root.focusJumped() }
      }
    }
  }
  function focusAiPane(pane) {
    pane = String(pane || "")
    if (!/^[A-Za-z0-9][A-Za-z0-9:_-]{0,127}$/.test(pane)) return false
    if (aiFocus.running) return false
    root.focusHost = root.aiHost
    aiFocus.command = ["sh", "-c", root._wrap, "sh"].concat(root.aiHost === "" ? ["herdr", "agent", "focus", pane]
                                          : root._sshBase.concat(["--", root.aiHost, "herdr agent focus " + pane]))
    aiFocus.running = true
    return true
  }

  // --- theme -----------------------------------------------------------------
  property color themeBackground: Commons.Color.background
  property color themeForeground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color green: Commons.Color.accent
  property color yellow: Commons.Color.foreground
  property color red: Commons.Color.urgent
  property color blue: Commons.Color.accent
  property color cyan: Commons.Color.accent

  function parseColors(text) {
    var map = {}, lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*"?(#[0-9A-Fa-f]{6})(?:[0-9A-Fa-f]{2})?"?/)
      if (m) map[m[1].toLowerCase()] = m[2]
    }
    function pick(keys, fallback) { for (var k = 0; k < keys.length; k++) if (map[keys[k]]) return map[keys[k]]; return fallback }
    green = pick(["green", "color2"], Commons.Color.accent)
    yellow = pick(["yellow", "color3"], Commons.Color.foreground)
    red = pick(["red", "color1"], Commons.Color.urgent)
    blue = pick(["blue", "color4"], Commons.Color.accent)
    cyan = pick(["cyan", "color6"], Commons.Color.accent)
    accent = pick(["accent", "cyan", "color6"], Commons.Color.accent)
    themeBackground = pick(["background"], Commons.Color.background)
    themeForeground = pick(["foreground"], Commons.Color.foreground)
  }
  FileView {
    id: colorsFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.parseColors(text())
    onFileChanged: reload()
  }
  // The theme dir is a symlink swap; watching the file alone can miss it.
  Connections {
    target: Commons.Color
    function onAccentChanged() { colorsFile.reload() }
    function onBackgroundChanged() { colorsFile.reload() }
    function onForegroundChanged() { colorsFile.reload() }
  }

  // --- collector ---------------------------------------------------------------
  property bool pause: false
  // the host lists are command line arguments, so a change means a restart
  property bool _rehost: false
  readonly property string hostKey: root.fleet.join(",") + "|" + root.fleetIgnore.join(",")
  onHostKeyChanged: if (collector.running) { root._rehost = true; root.pause = true; rehost.restart() }
  Timer { id: rehost; interval: 200; onTriggered: root.pause = false }
  Process {
    id: collector
    command: ["bun", root.collectorPath, "--interval", String(root.intervalMs)]
      .concat(root.fleet.length > 0 ? ["--fleet", root.fleet.join(",")] : [])
      .concat(root.fleetIgnore.length > 0 ? ["--ignore", root.fleetIgnore.join(",")] : [])
    // not before the settings are read: a collector started earlier would miss the host lists
    running: root.active && !root.pause && root.settingsReady
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        if (line.length > 262144) return
        try {
          var o = JSON.parse(line)
          if (o && o.v === 1) { root.snap = o; root.ready = true; root.error = "" }
        } catch (e) { root.error = "bad collector frame" }
      }
    }
    onExited: function(code) {
      if (!root.active || root._rehost) { root._rehost = false; return }
      root.error = "collector exited (" + code + "), retrying"
      root.pause = true
      retry.restart()
    }
  }
  // First paint: when this model wakes with no data yet, take the newest snapshot any
  // collector left in the runtime dir (written every tick), so a summoned overlay never
  // opens as an empty frame. Live frames replace it within one tick.
  Process {
    id: seed
    command: ["cat", (Quickshell.env("XDG_RUNTIME_DIR") || "/nonexistent") + "/infodash-snap.json"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.ready) return
        try {
          var o = JSON.parse(text)
          if (o && o.v === 1 && (Date.now() - o.ts) < 600000) { root.snap = o; root.ready = true }
        } catch (e) {}
      }
    }
  }
  Component.onCompleted: if (root.active && !root.ready) seed.running = true
  // when hidden the data goes stale: drop "ready" so the next show seeds from the newest snapshot
  onActiveChanged: { if (root.active) { if (!root.ready) seed.running = true } else root.ready = false }
  property real nowMs: Date.now()            // for "how old is this frame" displays
  Timer { interval: 1000; repeat: true; running: root.active; onTriggered: root.nowMs = Date.now() }
  // A binding, never an assignment: the pause flag is what stops and restarts it.
  Timer { id: retry; interval: 3000; onTriggered: root.pause = false }
}
