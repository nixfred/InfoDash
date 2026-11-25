import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import "Hud.js" as Hud
import "Layout.js" as Layout
import "Skins.js" as Skins
import "Ai.js" as Ai

// The dashboard. Hosted by Infodash.qml (background layer) and Overlay.qml
// (summoned). Never scrolls (Law 17): the whole thing is one fixed grid whose
// rows are budgeted from the height, and every list is cut to what fits.
Item {
  id: view
  property var desk: null
  property bool interactive: true
  property string screenName: ""
  property int topInset: 0
  property int rightInset: 0
  property int bottomInset: 0
  property int leftInset: 0
  signal backgroundSwitchRequested()

  // --- data (every section defaults to empty so the first frame never throws) --
  readonly property var s: desk && desk.snap ? desk.snap : ({})
  readonly property var cpu: s.cpu || ({})
  readonly property var mem: s.mem || ({})
  readonly property var gpus: s.gpus || []
  readonly property var stor: s.storage || ({ mounts: [], nvme: [] })
  readonly property var net: s.net || ({ ifaces: [] })
  readonly property var pcie: s.pcie || []
  readonly property var usb: s.usb || ({ controllers: [] })
  readonly property var audio: s.audio || ({ sinks: [], sources: [] })
  readonly property var fleet: s.fleet || []
  // agent sessions: a scan of this machine or of another tailnet host (see DashModel / Ai.js)
  readonly property string aiHost: desk ? desk.aiHost : ""
  readonly property var aiData: desk ? desk.aiData : null
  readonly property bool aiReady: !!aiData && aiData.host === aiHost
  readonly property var ai: aiReady ? aiData.rows : []
  readonly property string aiError: aiReady ? aiData.error : ""
  function statusColor(st) { return st === "working" ? accent : (st === "blocked" ? danger : (st === "done" ? ok : dim)) }
  readonly property var led: s.ledger || ({})
  readonly property var hist: s.hist || ({ cpuTemp: [], memGB: [], rootPct: [] })

  // --- palette, all from the active Omarchy theme -----------------------------
  // HUD unit: screen-derived, times InfoDash's own text size setting (not the system font size)
  readonly property real fontScale: desk ? desk.fontScale : 1.0
  readonly property real u: Math.max(0.8, Math.min(2.0, Math.min(width / 1900, height / 1100))) * fontScale
  // --- skin: shapes, type and gauge art only; colours below never change with the skin ----
  readonly property var skin: Skins.get(desk ? desk.skinId : Skins.DEFAULT)
  readonly property var _families: Qt.fontFamilies()
  function pickFont(list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i] === "mono") return Style.resolvedFontFamily
      if (view._families.indexOf(list[i]) >= 0) return list[i]
    }
    return Style.resolvedFontFamily
  }
  readonly property string mono: pickFont(skin.fonts)
  readonly property color ink: desk ? desk.themeForeground : "#ddd"
  readonly property color bg: desk ? desk.themeBackground : "#000"
  readonly property color dim: ink                // one text brightness everywhere: hierarchy is size, weight and case, never fading
  readonly property color accent: desk ? desk.accent : "#4cf"
  readonly property color line: desk ? desk.cyan : "#48a"
  readonly property color glow: desk ? desk.cyan : "#4cf"
  readonly property color danger: desk ? desk.red : "#f55"
  readonly property color ok: desk ? desk.green : "#5f5"
  readonly property color blue: desk ? desk.blue : "#58f"
  readonly property color yellow: desk ? desk.yellow : "#fc4"
  readonly property color cyan: desk ? desk.cyan : "#4cf"

  readonly property real pad: Math.round(24 * u)
  readonly property real gap: Math.round(12 * u)

  // --- actions -----------------------------------------------------------------
  function sh(cmd) { if (view.interactive) Quickshell.execDetached(cmd) }
  readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0

  // --- layout state: the saved layout, or a live preview while a panel is dragged ----
  readonly property var committed: desk ? desk.layoutFor(screenName) : Layout.defaults()
  property var preview: null                  // live layout during a drag
  readonly property var cur: preview ? preview : committed
  property string dragId: ""
  property string dragZone: ""                // "" = move, else l r t b tl tr bl br
  property var dragFree: ({ x: 0, y: 0, w: 0, h: 0 })   // the panel under the pointer (move only)
  property bool dragBad: false                // pointer is over a spot that cannot be satisfied
  property bool ctrlHover: false
  property bool ctrlKey: false                // CTRL held, from key events (needs keyboard focus)
  readonly property bool dragging: dragId !== ""
  readonly property bool editing: dragging || ctrlKey || ctrlHover
  readonly property var fleetOthers: (view.fleet || []).filter(function(f) { return f && !f.self })
  property bool hostMenuOpen: false
  property real hostMenuX: 0
  property real hostMenuY: 0
  function toggleHostMenu(item) {
    var pt = item.mapToItem(stage, 0, item.height + Math.round(4 * view.u))
    view.hostMenuX = Math.max(0, Math.min(pt.x, stage.width - Math.round(214 * view.u)))
    view.hostMenuY = pt.y
    view.hostMenuOpen = !view.hostMenuOpen
  }
  function pickAiHost(name) { if (view.desk && view.desk.setAiHost(name)) view.hostMenuOpen = false }
  property var _startCells: null
  property var _startPx: null
  property point _press: Qt.point(0, 0)

  function rect(id) {
    if (view.dragId === id && view.dragZone === "") return view.dragFree
    return stage.px(view.cur[id])
  }

  // Which panel and edge is under (x, y) in stage coordinates.
  function hit(x, y) {
    var e = Math.round(12 * view.u), k = Layout.ids()
    for (var i = 0; i < k.length; i++) {
      var r = stage.px(view.cur[k[i]])
      if (x < r.x || y < r.y || x > r.x + r.w || y > r.y + r.h) continue
      var z = ""
      if (y < r.y + e) z += "t"; else if (y > r.y + r.h - e) z += "b"
      if (x < r.x + e) z += "l"; else if (x > r.x + r.w - e) z += "r"
      return { id: k[i], zone: z }
    }
    return null
  }
  function cursorFor(h) {
    if (!h) return Qt.ArrowCursor
    switch (h.zone) {
      case "": return Qt.SizeAllCursor
      case "l": case "r": return Qt.SizeHorCursor
      case "t": case "b": return Qt.SizeVerCursor
      case "tl": case "br": return Qt.SizeFDiagCursor
      default: return Qt.SizeBDiagCursor
    }
  }
  function beginDrag(pos) {
    var h = view.hit(pos.x, pos.y)
    if (!h) return
    view._press = pos
    view._startCells = Layout.copyRect(view.committed[h.id])
    view._startPx = stage.px(view._startCells)
    view.dragZone = h.zone
    view.dragFree = view._startPx
    view.dragBad = false
    view.preview = Layout.copy(view.committed)
    view.dragId = h.id
  }
  function updateDrag(pos) {
    if (!view.dragging) return
    var dx = pos.x - view._press.x, dy = pos.y - view._press.y
    var dxc = dx / stage.cellW, dyc = dy / stage.cellH
    var s = view._startCells, m = Layout.MINS[view.dragId], z = view.dragZone
    var r = { x: s.x, y: s.y, w: s.w, h: s.h }
    if (z === "") {
      r.x = s.x + dxc; r.y = s.y + dyc
      view.dragFree = { x: view._startPx.x + dx, y: view._startPx.y + dy, w: view._startPx.w, h: view._startPx.h }
    } else {
      if (z.indexOf("l") >= 0) { var left = Math.max(0, Math.min(s.x + s.w - m.w, Math.round(s.x + dxc))); r.x = left; r.w = s.x + s.w - left }
      if (z.indexOf("r") >= 0) r.w = Math.max(m.w, Math.min(Layout.COLS - s.x, Math.round(s.w + dxc)))
      if (z.indexOf("t") >= 0) { var top = Math.max(0, Math.min(s.y + s.h - m.h, Math.round(s.y + dyc))); r.y = top; r.h = s.y + s.h - top }
      if (z.indexOf("b") >= 0) r.h = Math.max(m.h, Math.min(Layout.ROWS - s.y, Math.round(s.h + dyc)))
    }
    var res = z === "" ? Layout.placeNear(view.committed, view.dragId, r, 8) : Layout.place(view.committed, view.dragId, r)
    if (res) { view.preview = res; view.dragBad = false } else view.dragBad = true
  }
  function endDrag() {
    if (view.dragging && view.preview && view.desk) view.desk.commitLayout(view.screenName, view.preview)
    view.preview = null
    view.dragId = ""
  }
  function cancelDrag() { view.preview = null; view.dragId = "" }

  // Key events: instant CTRL on/off (pointer events only refresh it when the mouse moves) and
  // Esc to cancel a drag. The overlay's own key catcher forwards the same keys.
  Item {
    id: keySink
    focus: true
    onActiveFocusChanged: if (!activeFocus) view.ctrlKey = false
    Keys.onPressed: function(e) { view.keyPress(e.key); e.accepted = false }
    Keys.onReleased: function(e) { view.keyRelease(e.key); e.accepted = false }
  }
  readonly property bool popupOpen: picker.open || hostMenuOpen
  function resetTransient() { ctrlKey = false; ctrlHover = false; hostMenuOpen = false; picker.open = false }
  function keyPress(k) { if (k === Qt.Key_Control) view.ctrlKey = true; else if (k === Qt.Key_Escape) { if (view.dragging) view.cancelDrag(); else if (view.hostMenuOpen) view.hostMenuOpen = false; else picker.open = false } }
  function keyRelease(k) { if (k === Qt.Key_Control) { view.ctrlKey = false; view.ctrlHover = false } }

  Item {
    id: stage
    x: view.leftInset + view.pad
    y: view.topInset + Math.round(6 * view.u)
    width: view.width - view.leftInset - view.rightInset - 2 * view.pad
    height: view.height - view.topInset - view.bottomInset - Math.round(6 * view.u) - view.pad

    // ---- header ----------------------------------------------------------------
    readonly property real hH: Math.round(60 * view.u)
    T { x: Math.round(8 * view.u); y: Math.round(4 * view.u); text: "INFODASH"; sz: 30; u: view.u; mono: view.mono; c: view.ink; font.letterSpacing: 9 * view.u; elide: Text.ElideNone }
    // brand line: "by @nixfred" + mark opens nixfred.com, the repo address opens the project page
    Item {
      id: brand
      x: Math.round(10 * view.u); y: Math.round(43 * view.u)
      width: byText.implicitWidth + markImg.width + repoText.implicitWidth + Math.round(30 * view.u)
      height: Math.round(15 * view.u)
      Row {
        spacing: Math.round(6 * view.u)
        anchors.verticalCenter: parent.verticalCenter
        Item {
          width: byText.implicitWidth + markImg.width + Math.round(5 * view.u); height: Math.round(15 * view.u)
          T { id: byText; anchors.verticalCenter: parent.verticalCenter; text: "by @nixfred"; sz: 10; u: view.u; mono: view.mono; c: view.ink; font.underline: siteHit.containsMouse; font.letterSpacing: 1 * view.u }
          Image {
            id: markImg
            anchors.left: byText.right; anchors.leftMargin: Math.round(5 * view.u); anchors.verticalCenter: parent.verticalCenter
            width: Math.round(15 * view.u); height: width
            source: Qt.resolvedUrl("assets/nixfred-mark.png"); sourceSize: Qt.size(64, 64)
            smooth: true; mipmap: true; asynchronous: true
          }
          MouseArea { id: siteHit; anchors.fill: parent; enabled: view.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (view.desk) view.desk.openLink("site") }
        }
        Item {
          width: repoText.implicitWidth; height: Math.round(15 * view.u)
          T { id: repoText; anchors.verticalCenter: parent.verticalCenter; text: "github.com/nixfred/InfoDash"; sz: 10; u: view.u; mono: view.mono; c: view.ink; font.underline: repoHit.containsMouse; font.letterSpacing: 0.5 * view.u }
          MouseArea { id: repoHit; anchors.fill: parent; enabled: view.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (view.desk) view.desk.openLink("repo") }
        }
      }
    }
    T { id: screenLabel; x: Math.round(300 * view.u); y: Math.round(24 * view.u); text: view.screenName; sz: 10; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.5 * view.u }
    // skin switcher: quiet chip beside the monitor name, strip opens on click
    MouseArea { anchors.fill: parent; z: 90; visible: picker.open || view.hostMenuOpen; onClicked: { picker.open = false; view.hostMenuOpen = false } }
    SkinPicker {
      id: picker
      visible: view.interactive
      x: screenLabel.x + screenLabel.implicitWidth + Math.round(18 * view.u); y: Math.round(20 * view.u); z: 100
      v: view
    }
    Column {
      anchors.right: parent.right
      spacing: Math.round(2 * view.u)
      T { anchors.right: parent.right; text: "HOST   " + String(view.s.host || "--").toUpperCase() + "     UPTIME   " + Hud.fmtUptime(view.s.uptimeSec); sz: 13; u: view.u; mono: view.mono; c: view.ink; font.letterSpacing: 2 * view.u; width: Math.max(0, stage.width - picker.x - picker.width - Math.round(24 * view.u)); horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
      T { anchors.right: parent.right; text: view.desk && view.desk.error !== "" ? view.desk.error : (view.desk && view.desk.ready ? ((view.desk.nowMs - view.s.ts < 8000 ? "LIVE  " : "UPDATING  ") + new Date(view.s.ts).toLocaleTimeString(Qt.locale(), "HH:mm:ss")) : "COLLECTING..."); sz: 9.5; u: view.u; mono: view.mono; c: view.desk && view.desk.error !== "" ? view.danger : view.dim; width: Math.max(0, stage.width - Math.round(300 * view.u)); horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
    }

    // ---- grid geometry: Layout.COLS x Layout.ROWS cells under the header ----------
    readonly property real gridTop: hH + view.gap
    readonly property real cellW: (width + view.gap) / Layout.COLS
    readonly property real cellH: (height - gridTop + view.gap) / Layout.ROWS
    function px(r) { return { x: r.x * cellW, y: gridTop + r.y * cellH, w: r.w * cellW - view.gap, h: r.h * cellH - view.gap } }

    // ---- row 1: USB bay | fleet + AI | telemetry ---------------------------------
    HudPanel {
      v: view; title: "DEVICE BAY // USB TOPOLOGY"; tag: view.usb.controllers.length + " HOST"
      slot: "usb"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      UsbBay { anchors.fill: parent; v: view; controllers: view.usb.controllers }
    }

    HudPanel {
      id: fleetPanel
      v: view; title: "FLEET // TAILNET"; tag: view.fleet.filter(function(f) { return f.online }).length + "/" + view.fleet.length + " UP"
      slot: "fleet"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      readonly property real rowH: Math.round(21 * view.u)
      readonly property int fit: Math.max(0, Math.floor(bodyItem.height / rowH))
      Column {
        width: parent.width
        Repeater {
          model: view.fleet.slice(0, fleetPanel.fit)
          Item {
            width: parent.width; height: fleetPanel.rowH
            Rectangle { x: 0; anchors.verticalCenter: parent.verticalCenter; width: Math.round(8 * view.u); height: width; radius: width / 2; color: modelData.online ? view.ok : "transparent"; border.width: 1; border.color: modelData.online ? view.ok : view.dim }
            T { x: Math.round(18 * view.u); anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.4; text: String(modelData.name).toUpperCase() + (modelData.self ? " *" : ""); sz: 11; u: view.u; mono: view.mono; c: modelData.online ? view.ink : view.dim }
            T { anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: parent.width * 0.5; horizontalAlignment: Text.AlignRight; text: modelData.online ? modelData.os : "OFFLINE"; sz: 9.5; u: view.u; mono: view.mono; c: modelData.online ? view.dim : view.danger }
          }
        }
        T { visible: view.fleet.length === 0; text: "tailscale not answering"; sz: 10; u: view.u; mono: view.mono; c: view.dim }
      }
    }

    HudPanel {
      id: aiPanel
      v: view; title: "AI SESSIONS"
      tag: (view.aiHost !== "" ? view.aiHost.toUpperCase() + " \u00B7 " : "") + (Ai.working(view.ai) > 0 ? Ai.working(view.ai) + " WORKING \u00B7 " : "") + view.ai.length + " LIVE"
      slot: "ai"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      readonly property real rowH: Math.round(62 * view.u)
      readonly property real headH: hostChip.height + Math.round(8 * view.u)
      readonly property real moreH: Math.round(16 * view.u)
      readonly property int fit: Math.max(1, Math.floor((bodyItem.height - headH - moreH) / rowH))
      HudButton {
        id: hostChip
        v: view; sz: 9
        label: "HOST \u25BE  " + (view.aiHost !== "" ? view.aiHost.toUpperCase() : "THIS MACHINE")
        active: view.aiHost !== ""
        visible: view.interactive
        onClicked: view.toggleHostMenu(hostChip)
      }
      Column {
        y: aiPanel.headH
        width: parent.width
        Repeater {
          model: Math.min(view.ai.length, aiPanel.fit)
          delegate: Item {
            id: rowItem
            required property int index
            readonly property var row: view.ai[index] || ({ kind: "", ws: "", project: "", status: "unknown", title: "", text: "", agent: "", model: "", cwd: "", provider: "", pid: 0, paneId: "", activeSec: -1, ageSec: 0 })
            readonly property bool herdr: row.kind === "herdr"
            width: parent.width; height: aiPanel.rowH
            Rectangle { anchors.fill: parent; anchors.bottomMargin: 2; color: rowMa.pressed ? Hud.rgba(view.accent, 0.24) : (rowMa.containsMouse ? Hud.rgba(view.accent, 0.11) : "transparent") }
            Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Hud.rgba(view.line, 0.18) }
            Rectangle {   // status dot, pulsing while the agent works
              x: Math.round(3 * view.u); y: Math.round(7 * view.u); width: Math.round(8 * view.u); height: width; radius: width / 2
              color: rowItem.herdr ? view.statusColor(row.status) : "transparent"
              border.width: 1; border.color: rowItem.herdr ? view.statusColor(row.status) : view.dim
              SequentialAnimation on opacity { running: rowItem.herdr && row.status === "working"; loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1.0; duration: 700 } }
            }
            // line 1: workspace (or folder) and, right, status and how long ago it was active
            T { x: Math.round(18 * view.u); y: Math.round(2 * view.u); width: parent.width * 0.55
                text: String(rowItem.herdr ? row.ws : row.project).toUpperCase(); sz: 11; u: view.u; mono: view.mono; c: view.ink; font.bold: true }
            T { anchors.right: parent.right; y: Math.round(3 * view.u); width: parent.width * 0.42; horizontalAlignment: Text.AlignRight
                text: rowItem.herdr ? (String(row.status).toUpperCase() + (row.activeSec >= 0 ? "  \u00B7  " + Ai.ago(row.activeSec) : ""))
                                    : ("NOT IN HERDR  \u00B7  " + Ai.ago(row.ageSec))
                sz: 9; u: view.u; mono: view.mono; c: rowItem.herdr ? view.statusColor(row.status) : view.dim; font.letterSpacing: 0.8 * view.u }
            // line 2: the session's own title
            T { x: Math.round(18 * view.u); y: Math.round(18 * view.u); width: parent.width - Math.round(18 * view.u)
                text: rowItem.herdr ? row.title : (row.provider + "  pid " + row.pid); sz: 10; u: view.u; mono: view.mono; c: view.ink }
            // line 3: what the agent said last
            T { x: Math.round(18 * view.u); y: Math.round(33 * view.u); width: parent.width - Math.round(18 * view.u)
                text: rowItem.herdr ? row.text : Ai.homeShort(row.cwd); sz: 9; u: view.u; mono: view.mono; c: view.dim }
            // line 4: agent, model, folder
            T { x: Math.round(18 * view.u); y: Math.round(47 * view.u); width: parent.width - Math.round(18 * view.u)
                text: rowItem.herdr ? row.agent + (row.model !== "" ? "  \u00B7  " + row.model : "") + "  \u00B7  " + Ai.homeShort(row.cwd) : ""
                sz: 8.5; u: view.u; mono: view.mono; c: view.ink }
            MouseArea {
              id: rowMa
              anchors.fill: parent
              enabled: rowItem.herdr && view.interactive && !!view.desk
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.desk.focusAiPane(row.paneId)
            }
          }
        }
        T { visible: view.ai.length > aiPanel.fit; height: aiPanel.moreH; width: parent.width; text: "+" + (view.ai.length - aiPanel.fit) + " more sessions"; sz: 9; u: view.u; mono: view.mono; c: view.dim; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
        T { visible: view.aiReady && view.ai.length === 0 && view.aiError === ""; text: view.aiHost === "" ? "no agent sessions running" : "no agent sessions on " + view.aiHost; sz: 10; u: view.u; mono: view.mono; c: view.dim }
        T { visible: !view.aiReady; text: view.aiHost === "" ? "scanning..." : "connecting to " + view.aiHost + "..."; sz: 10; u: view.u; mono: view.mono; c: view.dim }
        T { visible: view.aiError !== ""; width: parent.width; text: view.aiError; sz: 10; u: view.u; mono: view.mono; c: view.danger; wrapMode: Text.Wrap; elide: Text.ElideNone }
      }
    }

    // CPU
    HudPanel {
      v: view; title: "CPU"; tag: String(view.cpu.model || "")
      slot: "cpu"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      Gauge {
        id: cpuG
        v: view; width: Math.min(parent.width * 0.5, parent.height); height: parent.height
        known: view.cpu.tempC !== null && view.cpu.tempC !== undefined
        value: view.cpu.tempC || 0; minV: 20; maxV: view.cpu.tjmax || 100; warn: 0.85; unit: "C TCTL"; label: "CPU TEMPERATURE"
        sub: "tjmax " + (view.cpu.tjmax || "--")
      }
      Column {
        x: cpuG.width + Math.round(10 * view.u); width: parent.width - x; spacing: Math.round(3 * view.u)
        KV { v: view; width: parent.width; k: "cores"; val: (view.cpu.cores || "--") + "C / " + (view.cpu.threads || "--") + "T" }
        KV { v: view; width: parent.width; k: "busy"; val: Hud.num(view.cpu.busyPct) + "%" }
        KV { v: view; width: parent.width; k: "clk avg"; val: view.cpu.avgMHz ? view.cpu.avgMHz + " MHz" : "--" }
        T { text: view.cpu.coreMHz && view.cpu.coreMHz.length ? "CORE MHZ 0-" + (view.cpu.coreMHz.length - 1) : "CORE BUSY %"; sz: 9; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1 * view.u }
        Item {
          width: parent.width; height: Math.round(26 * view.u)
          readonly property var arr: view.cpu.coreMHz && view.cpu.coreMHz.length ? view.cpu.coreMHz : (view.cpu.coreBusy || [])
          readonly property real peak: view.cpu.coreMHz && view.cpu.coreMHz.length ? Math.max.apply(null, arr.concat([1])) : 100
          Repeater {
            model: parent.arr.length
            Rectangle {
              width: Math.max(2, parent.width / Math.max(1, parent.arr.length) - 2); x: index * (width + 2)
              height: Math.max(2, parent.height * Hud.clamp(parent.arr[index] / parent.peak, 0, 1)); anchors.bottom: parent.bottom
              color: Hud.rgba(view.accent, 0.8)
            }
          }
        }
        T { text: "TCTL LAST " + (view.hist.cpuTemp.length * 2) + "S"; sz: 9; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1 * view.u }
        Spark { v: view; width: parent.width; height: Math.round(34 * view.u); values: view.hist.cpuTemp }
      }
    }

    // MEMORY
    HudPanel {
      v: view; title: "MEMORY"; tag: Hud.num(view.mem.totalGB) + " GB"
      slot: "mem"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      Gauge {
        id: memG
        v: view; width: Math.min(parent.width * 0.5, parent.height); height: parent.height
        known: view.mem.totalGB > 0
        value: view.mem.usedGB || 0; minV: 0; maxV: view.mem.totalGB || 1; warn: 0.9; decimals: 1; unit: "GB USED"; label: "MEMORY"
        sub: Hud.num(view.mem.usedPct) + "% of " + Hud.num(view.mem.totalGB) + " GB"
      }
      Column {
        x: memG.width + Math.round(10 * view.u); width: parent.width - x; spacing: Math.round(3 * view.u)
        KV { v: view; width: parent.width; k: "avail"; val: Hud.num(view.mem.availGB, 1) + " GB" }
        KV { v: view; width: parent.width; k: "swap"; val: Hud.num(view.mem.swapUsedGB, 1) + " / " + Hud.num(view.mem.swapTotalGB, 1) + " GB" }
        KV { v: view; width: parent.width; visible: !!(view.mem.dimmC && view.mem.dimmC.length > 0); k: "dimm temp"; val: (view.mem.dimmC || []).join(" / ") + " C" }
        Item { width: 1; height: Math.round(28 * view.u) }
        T { text: "USED GB " + (view.hist.memGB.length * 2) + "S"; sz: 9; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1 * view.u }
        Spark { v: view; width: parent.width; height: Math.round(34 * view.u); values: view.hist.memGB }
      }
    }

    // GRAPHICS
    HudPanel {
      id: gfx
      v: view; title: "GRAPHICS"; tag: view.gpus.length + " ADAPTER"
      slot: "gfx"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      readonly property real rowH: Math.round(52 * view.u)
      readonly property int fit: Math.max(1, Math.floor(bodyItem.height / rowH))
      Column {
        width: parent.width
        Repeater {
          model: view.gpus.slice(0, gfx.fit)
          Item {
            width: parent.width; height: gfx.rowH
            Rectangle { x: 0; y: Math.round(6 * view.u); width: Math.round(26 * view.u); height: width; color: "transparent"; border.width: 1; border.color: view.accent
              Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; color: Hud.rgba(view.accent, 0.35) } }
            T { x: Math.round(38 * view.u); y: Math.round(4 * view.u); width: parent.width * 0.62; text: modelData.name; sz: 12; u: view.u; mono: view.mono; c: view.ink }
            T { anchors.right: parent.right; y: Math.round(5 * view.u); text: modelData.primary ? "PRIMARY" : "SECONDARY"; sz: 9; u: view.u; mono: view.mono; c: modelData.primary ? view.ok : view.accent; elide: Text.ElideNone }
            T { x: Math.round(38 * view.u); y: Math.round(24 * view.u); width: parent.width - x
                text: modelData.note !== "" ? modelData.note : [
                  modelData.tempC !== null ? Hud.num(modelData.tempC) + "C" : "",
                  modelData.loadPct !== null ? Hud.num(modelData.loadPct) + "%" : "",
                  modelData.powerW !== null ? Hud.num(modelData.powerW) + " W" : "",
                  modelData.clockMHz !== null ? Hud.num(modelData.clockMHz) + " MHz" : "",
                  modelData.vramTotalMB ? Hud.num(modelData.vramUsedMB / 1024, 1) + "/" + Hud.num(modelData.vramTotalMB / 1024, 1) + " GB" : ""
                ].filter(function(x) { return x !== "" }).join("  ·  ")
                sz: 10; u: view.u; mono: view.mono; c: view.dim }
          }
        }
        T { visible: view.gpus.length === 0; text: "no display adapters"; sz: 10; u: view.u; mono: view.mono; c: view.dim }
      }
    }

    // STORAGE
    HudPanel {
      id: stg
      v: view; title: "STORAGE"
      tag: view.stor.mounts.length ? Hud.num(view.stor.mounts[0].usedGB) + " / " + Hud.num(view.stor.mounts[0].totalGB) + " GB" : ""
      slot: "stg"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      Gauge {
        id: stgG
        v: view; width: Math.min(parent.width * 0.5, parent.height); height: parent.height
        known: view.stor.mounts.length > 0
        value: view.stor.mounts.length ? view.stor.mounts[0].pct : 0; minV: 0; maxV: 100; warn: 0.9; unit: "% " + (view.stor.mounts.length ? view.stor.mounts[0].mount : "ROOT"); label: "STORAGE"
        sub: view.stor.mounts.length ? Hud.num(view.stor.mounts[0].usedGB) + " GB used" : ""
      }
      Column {
        x: stgG.width + Math.round(10 * view.u); width: parent.width - x; spacing: Math.round(3 * view.u)
        Repeater { model: view.stor.nvme.slice(0, 2); KV { v: view; width: parent.width; k: modelData.name; val: Hud.num(modelData.tempC) + " C" } }
        Repeater { model: view.stor.mounts.slice(0, 3); KV { v: view; width: parent.width; k: modelData.mount; val: modelData.pct + "% used"; vc: modelData.pct >= 90 ? view.danger : view.ink } }
        Item { width: 1; height: Math.round(10 * view.u) }
        T { text: "ROOT % " + (view.hist.rootPct.length * 2) + "S"; sz: 9; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1 * view.u }
        Spark { v: view; width: parent.width; height: Math.round(30 * view.u); values: view.hist.rootPct; lo: 0; hi: 100 }
      }
    }

    // ---- row 2: PipeWire | network + PCIe -----------------------------------------
    HudPanel {
      id: pw
      v: view; title: "PIPEWIRE ROUTING"
      tag: (view.audio.apps || 0) + " PLAYING · " + (view.audio.recorders || 0) + " RECORDING"
      slot: "pw"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      readonly property real rowH: Math.round(17 * view.u)
      readonly property real footH: bodyItem.height > Math.round(120 * view.u) ? Math.round(52 * view.u) : 0
      readonly property int fit: Math.max(1, Math.floor((bodyItem.height - Math.round(24 * view.u) - Math.round(20 * view.u) - footH) / rowH))
      readonly property var cols: [0.07, 0.4, 0.09, 0.15, 0.05, 0.08, 0.16]
      function cells(x) { return [x.id, x.node, x.bus, x.fmt, x.ch, x.rate, x.state + (x.isDefault ? " ◆" : "")] }
      function colors(x) { return [view.dim, view.ink, view.dim, view.dim, view.dim, view.dim, x.state === "RUNNING" ? view.ok : (x.state === "IDLE" ? view.accent : view.dim)] }
      Row {
        width: parent.width; spacing: Math.round(14 * view.u)
        Column {
          width: (parent.width - parent.spacing) / 2
          T { text: "SINKS  " + view.audio.sinks.length; sz: 10; u: view.u; mono: view.mono; c: view.ink; font.letterSpacing: 1.5 * view.u }
          TableRow { v: view; width: parent.width; head: true; fr: pw.cols; cells: ["ID", "NODE", "BUS", "FMT", "CH", "RATE", "STATE"] }
          Repeater { model: view.audio.sinks.slice(0, pw.fit); TableRow { v: view; width: parent.width; fr: pw.cols; cells: pw.cells(modelData); colors: pw.colors(modelData) } }
        }
        Column {
          width: (parent.width - parent.spacing) / 2
          T { text: "SOURCES  " + view.audio.sources.length + " + " + (view.audio.monitors || 0) + " MONITOR TAPS"; sz: 10; u: view.u; mono: view.mono; c: view.ink; font.letterSpacing: 1.5 * view.u }
          TableRow { v: view; width: parent.width; head: true; fr: pw.cols; cells: ["ID", "NODE", "BUS", "FMT", "CH", "RATE", "STATE"] }
          Repeater { model: view.audio.sources.slice(0, pw.fit); TableRow { v: view; width: parent.width; fr: pw.cols; cells: pw.cells(modelData); colors: pw.colors(modelData) } }
        }
      }
      Column {
        visible: pw.footH > 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        T { width: parent.width; sz: 10; u: view.u; mono: view.mono; c: view.dim
            text: "FLOW  apps " + (view.audio.apps || 0) + "  ▸ pipewire ▸  " + (function() { var d = view.audio.sinks.filter(function(x) { return x.isDefault })[0]; return d ? d.node + " " + d.fmt + " " + d.rate : "no default sink" })() }
        T { width: parent.width; sz: 10; u: view.u; mono: view.mono; c: view.dim
            text: (function() { var d = view.audio.sources.filter(function(x) { return x.isDefault })[0]; return d ? d.node : "no default source" })() + "  ▸  apps " + (view.audio.recorders || 0) }
        T { width: parent.width; sz: 10; u: view.u; mono: view.mono; c: view.dim
            text: view.audio.sinks.concat(view.audio.sources).filter(function(x) { return x.state === "SUSPENDED" }).length + " endpoints suspended, " + view.audio.sinks.concat(view.audio.sources).filter(function(x) { return x.state === "RUNNING" }).length + " running" }
      }
    }

    HudPanel {
      id: np
      v: view; title: "NETWORK // PCIE LINKS"
      slot: "np"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      readonly property real rowH: Math.round(17 * view.u)
      readonly property real footH: bodyItem.height > Math.round(100 * view.u) ? Math.round(40 * view.u) : 0
      readonly property int fit: Math.max(1, Math.floor((bodyItem.height - Math.round(22 * view.u) - footH) / rowH))
      readonly property var netCols: [0.24, 0.1, 0.3, 0.18, 0.18]
      Row {
        width: parent.width; height: parent.height; spacing: Math.round(14 * view.u)
        Item {
          width: (parent.width - parent.spacing) * 0.5; height: parent.height
          Column {
            width: parent.width
            TableRow { v: view; width: parent.width; head: true; fr: np.netCols; cells: ["INTERFACE", "STATE", "ADDRESS", "RX/S", "TX/S"] }
            Repeater {
              model: view.net.ifaces.slice(0, np.fit)
              TableRow { v: view; width: parent.width; fr: np.netCols
                cells: [modelData.name, modelData.state, modelData.addr, Hud.fmtRate(modelData.rxRate), Hud.fmtRate(modelData.txRate)]
                colors: [view.ink, modelData.state === "UP" ? view.ok : view.dim, view.ink, view.dim, view.dim] }
            }
          }
          Column {
            visible: np.footH > 0
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            T { width: parent.width; sz: 10; u: view.u; mono: view.mono; c: view.dim; text: "since boot  rx " + Hud.fmtBytes(view.net.rxBytes) + "  tx " + Hud.fmtBytes(view.net.txBytes) }
            T { width: parent.width; sz: 10; u: view.u; mono: view.mono; c: view.dim; text: "rate " + Hud.fmtRate(view.net.rxRate) + " rx  ·  " + Hud.fmtRate(view.net.txRate) + " tx" }
          }
        }
        Item {
          width: (parent.width - parent.spacing) * 0.5; height: parent.height
          Column {
            width: parent.width
            TableRow { v: view; width: parent.width; head: true; fr: [0.52, 0.2, 0.28]; cells: ["DEVICE", "LINK", "LANES"] }
            Repeater {
              model: view.pcie.slice(0, np.fit)
              Item {
                width: parent.width; height: np.rowH
                T { anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5; text: modelData.name; sz: 10.5; u: view.u; mono: view.mono; c: view.ink }
                T { anchors.verticalCenter: parent.verticalCenter; x: parent.width * 0.52; width: parent.width * 0.2; text: String(modelData.speed).replace(" GT/s", "GT"); sz: 10; u: view.u; mono: view.mono; c: view.dim }
                Row {
                  x: parent.width * 0.74; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                  Repeater {
                    model: Math.min(16, modelData.maxWidth)
                    Rectangle { width: Math.max(2, Math.round(3 * view.u)); height: Math.round(9 * view.u); color: index < modelData.width ? view.accent : Hud.rgba(view.line, 0.3) }
                  }
                }
              }
            }
          }
        }
      }
    }

    // ---- row 3: system ledger ----------------------------------------------------
    HudPanel {
      id: ledger
      v: view; title: "SYSTEM LEDGER"
      slot: "ledger"; animate: view.dragId !== slot; z: view.dragId === slot ? 50 : 1; opacity: view.dragId === slot ? 0.88 : 1
      x: view.rect(slot).x; y: view.rect(slot).y; width: view.rect(slot).w; height: view.rect(slot).h
      readonly property real bw: bodyItem.width
      readonly property var profiles: ["power-saver", "balanced", "performance"]

      // THEME
      Column {
        x: 0; width: ledger.bw * 0.2; spacing: Math.round(4 * view.u)
        T { text: "THEME"; sz: 9.5; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.5 * view.u }
        T { width: parent.width; text: String(view.led.theme || "--").toUpperCase(); sz: 16; u: view.u; mono: view.mono; c: view.ink; font.letterSpacing: 2 * view.u }
        HudButton { v: view; label: "BG SWITCHER"; onClicked: view.backgroundSwitchRequested() }
      }
      // POWER PROFILE
      Column {
        x: ledger.bw * 0.2; width: ledger.bw * 0.27; spacing: Math.round(4 * view.u)
        T { text: "POWER PROFILE"; sz: 9.5; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.5 * view.u }
        Row {
          spacing: Math.round(6 * view.u)
          Repeater { model: ledger.profiles; HudButton { v: view; label: String(modelData).toUpperCase(); active: view.led.powerProfile === modelData; sz: 9.5; onClicked: view.sh(["powerprofilesctl", "set", modelData]) } }
        }
        T { text: "powerprofilesctl  ·  now " + (view.led.powerProfile || "--"); sz: 9; u: view.u; mono: view.mono; c: view.dim }
      }
      // UPDATES
      Column {
        x: ledger.bw * 0.49; width: ledger.bw * 0.16; spacing: Math.round(4 * view.u)
        T { text: "UPDATES"; sz: 9.5; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.5 * view.u }
        T { text: view.led.updates === null || view.led.updates === undefined ? "checking..." : (view.led.updates + " pending"); sz: 13; u: view.u; mono: view.mono; c: view.led.updates > 0 ? view.accent : view.ink }
        HudButton { v: view; label: "UPDATE"; onClicked: view.sh(["sh", "-c", "command -v omarchy-launch-floating-terminal-with-presentation >/dev/null && exec omarchy-launch-floating-terminal-with-presentation omarchy-update; exec xdg-terminal-exec omarchy-update"]) }
      }
      // TOGGLES
      Column {
        x: ledger.bw * 0.66; width: ledger.bw * 0.16; spacing: Math.round(4 * view.u)
        T { text: "TOGGLES"; sz: 9.5; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.5 * view.u }
        HudButton { v: view; label: "NIGHT LIGHT " + (view.led.nightlight === true ? "ON" : (view.led.nightlight === false ? "OFF" : "--")); active: view.led.nightlight === true; sz: 9.5; onClicked: view.sh(["omarchy-toggle-nightlight"]) }
        HudButton { v: view; label: "DO NOT DISTURB"; sz: 9.5; onClicked: view.sh(["omarchy-toggle-notification-silencing"]) }
      }
      // WORKSPACES
      Column {
        x: ledger.bw * 0.83; width: ledger.bw * 0.17; spacing: Math.round(4 * view.u)
        T { text: "WORKSPACE JUMP"; sz: 9.5; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.5 * view.u }
        Row {
          spacing: Math.round(5 * view.u)
          Repeater { model: 6; HudButton { v: view; label: String(index + 1); active: view.focusedWs === index + 1; sz: 10; onClicked: if (view.interactive) Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (index + 1) + "\" })") } }
        }
        T { text: "SUPER+1..6"; sz: 9; u: view.u; mono: view.mono; c: view.dim }
      }
    }

    // ---- edit layer: hold CTRL, drag a panel to move it, drag an edge or corner to resize ----
    Canvas {
      id: gridDots
      x: 0; y: stage.gridTop
      width: stage.width; height: stage.height - stage.gridTop
      z: 10
      visible: opacity > 0.01
      opacity: view.interactive && view.editing ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
      onVisibleChanged: if (visible) requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections { target: view; function onAccentChanged() { gridDots.requestPaint() } }
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = Hud.css(view.accent, 0.38)
        var cw = stage.cellW, ch = stage.cellH, d = Math.max(2, Math.round(2 * view.u))
        for (var c = 0; c <= Layout.COLS; c++)
          for (var r = 0; r <= Layout.ROWS; r++)
            ctx.fillRect(c * cw - d / 2, r * ch - d / 2, d, d)
      }
    }
    Rectangle {
      id: ghost
      visible: view.dragging && !!view.preview
      z: 40
      readonly property var g: view.dragging && view.preview ? stage.px(view.preview[view.dragId]) : ({ x: 0, y: 0, w: 0, h: 0 })
      x: g.x; y: g.y; width: g.w; height: g.h
      color: Hud.rgba(view.dragBad ? view.danger : view.accent, 0.14)
      border.width: 2
      border.color: view.dragBad ? view.danger : view.accent
      Behavior on x { NumberAnimation { duration: 90 } }
      Behavior on y { NumberAnimation { duration: 90 } }
      Behavior on width { NumberAnimation { duration: 90 } }
      Behavior on height { NumberAnimation { duration: 90 } }
    }
    HoverHandler {
      id: hoverH
      enabled: view.interactive
      acceptedModifiers: Qt.ControlModifier
      // HoverHandler does not filter by modifier, so read CTRL off the pointer event itself.
      cursorShape: (view.ctrlKey || view.ctrlHover || view.dragging) ? view.cursorFor(view.dragging ? ({ zone: view.dragZone }) : view.hit(point.position.x, point.position.y)) : Qt.ArrowCursor
      onPointChanged: view.ctrlHover = hovered && (point.modifiers & Qt.ControlModifier) !== 0
      onHoveredChanged: if (!hovered) view.ctrlHover = false
    }
    DragHandler {
      enabled: view.interactive
      target: null
      acceptedButtons: Qt.LeftButton
      acceptedModifiers: Qt.ControlModifier
      onActiveChanged: if (active) view.beginDrag(centroid.pressPosition); else view.endDrag()
      onCentroidChanged: if (active) view.updateDrag(centroid.position)
    }
    // CTRL + double-click on the title strip puts this monitor back to the default layout.
    TapHandler {
      enabled: view.interactive
      acceptedModifiers: Qt.ControlModifier
      onDoubleTapped: function(point) { if (point.position.y < stage.hH && view.desk) view.desk.resetLayout(view.screenName) }
    }

    // host menu for the AI SESSIONS panel: this machine, then every tailnet host that is up
    Rectangle {
      id: hostMenu
      visible: view.hostMenuOpen
      z: 100
      readonly property int cols: view.fleetOthers.length > 7 ? 2 : 1
      readonly property real cellW: Math.round(190 * view.u)
      x: Math.min(view.hostMenuX, Math.max(0, stage.width - width)); y: Math.min(view.hostMenuY, Math.max(0, stage.height - height))
      width: cols * cellW + (cols - 1) * Math.round(4 * view.u) + Math.round(14 * view.u)
      height: menuCol.height + Math.round(14 * view.u)
      color: Hud.rgba(view.bg, 0.95); border.width: 1; border.color: Hud.rgba(view.accent, 0.85)
      radius: view.skin.btn === "pill" || view.skin.btn === "round" ? Math.round(6 * view.u) : 0
      Column {
        id: menuCol
        x: Math.round(7 * view.u); y: Math.round(7 * view.u); width: parent.width - Math.round(14 * view.u)
        spacing: Math.round(4 * view.u)
        T { text: "SHOW AGENT SESSIONS OF"; sz: 8.5; u: view.u; mono: view.mono; c: view.dim; font.letterSpacing: 1.4 * view.u }
        HudButton { v: view; sz: 9.5; width: parent.width; label: "THIS MACHINE"; active: view.aiHost === ""; onClicked: view.pickAiHost("") }
        Grid {
          columns: hostMenu.cols; columnSpacing: Math.round(4 * view.u); rowSpacing: Math.round(4 * view.u)
          Repeater {
            model: view.fleetOthers.length
            delegate: HudButton {
              required property int index
              readonly property var host: view.fleetOthers[index] || ({ name: "", dns: "", online: false })
              v: view; sz: 9.5; width: hostMenu.cellW
              label: String(host.name).toUpperCase() + (host.online ? "" : "   OFFLINE")
              active: view.aiHost !== "" && view.aiHost === (host.dns || host.name)
              enabled: host.online && (host.dns || host.name) !== ""
              onClicked: view.pickAiHost(host.dns || host.name)
            }
          }
        }
      }
    }
  }
}
