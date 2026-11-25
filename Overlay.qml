import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// SUPER+D: `omarchy-shell shell toggle nixfred.infodash '{}'` hides the current app behind
// a clear background with infodash on it (and brings the app back). The shell calls
// open(payload) / close() and reads `opened` to pick which.
// SUPER+I (service) shows or hides the infodash panels on whichever layer is up, so with
// the overlay open it leaves a clear background and the app stays hidden.
// Esc or a click outside the cards closes the overlay.
Scope {
  id: root
  property bool opened: false

  // Its own model, collecting only while open; it seeds its first paint from the
  // snapshot file the collector keeps (see DashModel), so it never opens blank.
  DashModel { id: dash; active: root.opened && root.panelsVisible; intervalMs: 2000 }
  // a click on a session that jumped the user's focus to the herdr window: get out of its way
  Connections { target: dash; function onFocusJumped() { root.close() } }

  property string background: ""
  readonly property real wallpaperOpacity: 0.32
  readonly property bool videoBackground: root.isVideo(root.background)
  function isVideo(path) {
    if (typeof Util.isVideoPath === "function") return Util.isVideoPath(path)
    return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(String(path || ""))
  }
  Process {
    id: backgroundLink
    command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector { onStreamFinished: root.background = String(text || "").trim() }
  }
  // Panels on/off, shared with the service (SUPER+I). Fetched on open, pushed on change.
  property bool panelsVisible: true
  Process {
    id: panelsFetch
    command: ["qs", "ipc", "--pid", String(Quickshell.processId), "call", "infodash", "getDashboardVisible"]
    stdout: StdioCollector { onStreamFinished: root.panelsVisible = String(text).trim() !== "false" }
  }
  IpcHandler {
    target: "infodash-overlay"
    function setPanels(v: string): void { root.panelsVisible = ["1", "true", "on", "yes"].indexOf(String(v).toLowerCase()) >= 0 }
  }
  function open(payload) { root.opened = true; backgroundLink.running = true; panelsFetch.running = true }
  function close() { root.opened = false }
  function toggle(payload) { if (root.opened) close(); else open(payload) }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.opened && !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      updatesEnabled: root.opened
      WlrLayershell.namespace: "infodash-overlay"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal      // leave the bar's strip alone

      RemapGuard { id: remapGuard; window: panel }
      onVisibleChanged: if (visible) dashView.resetTransient()      // CTRL, open menus and the skin strip never survive a close

      Rectangle {
        id: keyCatcher
        anchors.fill: parent
        color: dash.themeBackground
        Item {
          anchors.fill: parent
          opacity: root.panelsVisible ? root.wallpaperOpacity : 1.0
          WaveWallpaper {
            anchors.fill: parent
            visible: !root.videoBackground
            source: root.videoBackground ? "" : Util.fileUrl(root.background)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            playing: root.opened
          }
        }
        focus: root.opened
        Keys.onEscapePressed: { if (dashView.dragging || dashView.popupOpen) dashView.keyPress(Qt.Key_Escape); else root.close() }
        Keys.onPressed: function(e) { if (e.key === Qt.Key_Control) dashView.keyPress(e.key) }
        Keys.onReleased: function(e) { dashView.keyRelease(e.key) }
        // Exclusive layer focus is not enough: Qt needs an item with activeFocus or Esc never fires.
        onVisibleChanged: if (visible) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        MouseArea { anchors.fill: parent; onClicked: function(mouse) { if (!(mouse.modifiers & Qt.ControlModifier)) root.close() } }
        DashView {
          id: dashView
          anchors.fill: parent
          visible: root.panelsVisible
          desk: dash
          interactive: true
          screenName: String(modelData.name || "")
          onBackgroundSwitchRequested: { root.close(); Quickshell.execDetached(["omarchy-shell", "background", "selector"]) }
        }
      }
    }
  }
}
