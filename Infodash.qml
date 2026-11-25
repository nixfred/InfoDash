import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "bar-insets.js" as BarInsets
import "Skins.js" as Skins

// Background-layer host. Replaces omarchy.background (manifest clonedFrom), so the
// theme's wallpaper is still shown, dimmed, behind the live dashboard, and
// `omarchy-theme-bg-set` / `omarchy-theme-set` keep working through the same IPC
// target. One surface owns the layer, so the stacking order is never in question.
Scope {
  id: root

  // Declared so omarchy-shell injects PluginShellApi (`if ("shell" in inst)`); the
  // bar position/size bindings below are what move the HUD when the bar moves.
  property var shell: null
  readonly property int barFallbackInset: Math.round(40 * Style.fontScale)
  readonly property var barEdgeInsets: BarInsets.insets(
    shell && shell.bar ? { position: shell.bar.position, barSize: shell.bar.barSize, barHidden: shell.bar.barHidden } : null,
    barFallbackInset)

  readonly property string home: Quickshell.env("HOME")
  readonly property string currentBackgroundLink: home + "/.local/state/omarchy/current/background"
  property string background: ""
  property real wallpaperOpacity: 0.32
  property bool dashboardVisible: true
  property var deskView: null

  DashModel {
    id: dash
    // A hidden desk costs nothing: stop collecting while SUPER+I has it hidden.
    active: root.dashboardVisible
    intervalMs: 2000
  }

  function isVideo(path) {
    if (typeof Util.isVideoPath === "function") return Util.isVideoPath(path)
    return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(String(path || ""))
  }
  // A video wallpaper is Omarchy's own daemon on its own layer: step aside for it.
  readonly property bool videoBackground: root.isVideo(root.background)
  readonly property bool passthrough: root.videoBackground
  function refreshBackground() { if (!readlinkProc.running) readlinkProc.running = true }
  function setBackground(path) { root.background = String(path || "").trim() }
  function applyThemePayload(colorsB64, shellB64) {
    try { Commons.Color.loadColors(Util.decodeBase64(colorsB64)) } catch (e) {}
    try { Commons.Color.loadShell(Util.decodeBase64(shellB64)) } catch (e2) {}
    Style.scheduleRefresh()
  }
  // theme-set passes a 3s snapshot as `path` and the durable target as `finalPath`;
  // display finalPath, the snapshot is deleted after 3s.
  function themeTransition(fromPath, path, finalPath, colorsB64, shellB64) {
    root.setBackground(finalPath || path)
    root.applyThemePayload(colorsB64, shellB64)
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector { onStreamFinished: root.setBackground(String(text || "")) }
  }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshBackground() }

  Process {
    id: bgSwitchProc
    command: ["omarchy-theme-bg-switcher"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var selected = String(text || "").trim()
        if (selected.length > 0 && selected.length <= 4096 && selected.charAt(0) === "/" && !bgSetProc.running) {
          bgSetProc.command = ["omarchy-theme-bg-set", selected]
          bgSetProc.running = true
        }
      }
    }
  }
  Process { id: bgSetProc; onExited: root.refreshBackground() }

  // Same contract as the built-in background plugin, so the CLI keeps working.
  IpcHandler {
    target: "background"
    function refresh(): void { root.refreshBackground() }
    function set(path: string): void { root.setBackground(path) }
    function setInstant(path: string): void { root.setBackground(path) }
    function transition(fromPath: string, path: string): void { root.setBackground(path) }
    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.themeTransition(fromPath, path, finalPath, colorsB64, shellB64)
    }
    function selector(): void { if (!bgSwitchProc.running) bgSwitchProc.running = true }
  }
  // The overlay is a separate instance: tell it whenever the panels are shown or hidden
  // (it also asks for the current value when it opens).
  property bool _pushDirty: false
  Process {
    id: pushPanels
    onExited: { if (root._pushDirty) { root._pushDirty = false; root.sendPanels() } }
  }
  function sendPanels() {
    if (pushPanels.running) { root._pushDirty = true; return }       // newest state is sent when the one in flight ends
    pushPanels.command = ["qs", "ipc", "--pid", String(Quickshell.processId), "call", "infodash-overlay", "setPanels", root.dashboardVisible ? "true" : "false"]
    pushPanels.running = true
  }
  onDashboardVisibleChanged: root.sendPanels()
  IpcHandler {
    target: "infodash"
    function toggleDashboard(): void { root.dashboardVisible = !root.dashboardVisible }
    function setDashboardVisible(v: string): void { root.dashboardVisible = ["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0 }
    function setSkin(id: string): string { return dash.setSkin(String(id)) ? "ok" : "unknown skin; try listSkins" }
    function getSkin(): string { return dash.skinId }
    function cycleSkin(): string { var n = Skins.next(dash.skinId, 1); dash.setSkin(n); return n }
    function prevSkin(): string { var n = Skins.next(dash.skinId, -1); dash.setSkin(n); return n }
    function listSkins(): string { return JSON.stringify(Skins.list.map(function(k) { return { id: k.id, name: k.name, hint: k.hint } })) }
    function setAiHost(name: string): string { return dash.setAiHost(String(name)) ? "ok" : "invalid host name" }
    function setFontScale(v: string): string { return dash.setFontScale(v) ? String(dash.fontScale) : "invalid (0.8 to 1.5)" }
    function getFontScale(): string { return String(dash.fontScale) }
    function getAiHost(): string { return dash.aiHost }
    function aiSessions(): string { return JSON.stringify(dash.aiData || { host: dash.aiHost, pending: true }) }
    function focusAi(pane: string): string { return dash.focusAiPane(pane) ? "sent" : "rejected (bad pane id or busy)" }
    function getDashboardVisible(): string { return root.dashboardVisible ? "true" : "false" }
    function setWallpaperOpacity(v: string): void { var n = Number(v); if (isFinite(n)) root.wallpaperOpacity = Math.max(0, Math.min(1, n)) }
    function status(): string { return JSON.stringify({ version: dash.version, ready: dash.ready, error: dash.error, visible: root.dashboardVisible, skin: dash.skinId, aiHost: dash.aiHost, fontScale: dash.fontScale, background: root.background, host: (dash.snap || {}).host || "" }) }
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      // Hyprland leaves a mapped layer at its old origin when a monitor moves
      // (undock); RemapGuard pulses it unmapped so the compositor re-places it.
      visible: !remapGuard.remapping && !(root.passthrough && !root.dashboardVisible)
      anchors { top: true; bottom: true; left: true; right: true }
      color: root.passthrough ? "transparent" : dash.themeBackground
      WlrLayershell.namespace: "omarchy-background"
      // Bottom (above the wallpaper layer, below every window) with on-demand focus: a surface
      // only learns that CTRL is held while it has keyboard focus, and CTRL+drag edits the layout.
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      exclusionMode: ExclusionMode.Ignore
      updatesEnabled: true

      readonly property var hyprlandMonitor: Hyprland.monitorFor(modelData)
      readonly property var visibleWorkspace: hyprlandMonitor ? hyprlandMonitor.activeWorkspace : null
      readonly property bool fullscreenHere: visibleWorkspace ? visibleWorkspace.hasFullscreen : false

      RemapGuard { id: remapGuard; window: panel }

      // Dimming belongs to the dashboard: hidden dashboard = wallpaper at full brightness.
      Item {
        anchors.fill: parent
        opacity: root.dashboardVisible ? root.wallpaperOpacity : 1.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        WaveWallpaper {
          anchors.fill: parent
          visible: !root.passthrough
          source: root.videoBackground ? "" : Util.fileUrl(root.background)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          playing: !panel.fullscreenHere
        }
      }
      Rectangle {
        anchors.fill: parent
        visible: root.passthrough && root.dashboardVisible
        color: dash.themeBackground
        opacity: Math.max(0, Math.min(1, 1 - root.wallpaperOpacity))
      }

      // Empty-desk gestures, as the stock background: double-click or right-click = wallpaper switcher.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) { if (!(mouse.modifiers & Qt.ControlModifier) && mouse.button === Qt.RightButton && !bgSwitchProc.running) bgSwitchProc.running = true }
        onDoubleClicked: function(mouse) { if (!(mouse.modifiers & Qt.ControlModifier) && mouse.button === Qt.LeftButton && !bgSwitchProc.running) bgSwitchProc.running = true; mouse.accepted = true }
      }

      DashView {
        anchors.fill: parent
        desk: dash
        interactive: true
        screenName: String(modelData.name || "")
        topInset: root.barEdgeInsets.top
        rightInset: root.barEdgeInsets.right
        bottomInset: root.barEdgeInsets.bottom
        leftInset: root.barEdgeInsets.left
        visible: root.dashboardVisible
        onBackgroundSwitchRequested: if (!bgSwitchProc.running) bgSwitchProc.running = true
      }
    }
  }
}
