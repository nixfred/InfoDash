import QtQuick
import "Hud.js" as Hud

// USB topology: one card per host controller on the left, its devices as chips on
// the right joined by a spine. Hubs nest one step to the right. Rows are budgeted
// from the height so the bay never scrolls; whatever does not fit is counted.
Item {
  id: ub
  property var v: null
  property var controllers: []
  readonly property real u: v ? v.u : 1
  readonly property real rowH: Math.round(38 * u)
  readonly property real rowGap: Math.round(5 * u)
  readonly property real cardW: Math.round(176 * u)
  readonly property real groupGap: Math.round(10 * u)
  readonly property int nCtl: controllers.length
  readonly property real groupMinH: Math.round(86 * u)
  // a controller card is at least groupMinH tall: show as many as fit, count the rest
  readonly property int nShow: Math.max(nCtl > 0 ? 1 : 0, Math.min(nCtl, Math.floor((height + groupGap) / (groupMinH + groupGap))))
  readonly property int budget: Math.max(nShow, Math.floor((height - Math.max(0, nShow - 1) * groupGap + rowGap) / (rowH + rowGap)))
  readonly property var plan: {
    var n = nShow, shown = [], used = 0, i
    for (i = 0; i < n; i++) { var c = (controllers[i] && controllers[i].devices ? controllers[i].devices.length : 0); shown.push(c > 0 ? 1 : 0); used += shown[i] }
    var grew = true
    while (used < budget && grew) {
      grew = false
      for (i = 0; i < n && used < budget; i++) if (controllers[i] && controllers[i].devices && shown[i] < controllers[i].devices.length) { shown[i]++; used++; grew = true }
    }
    return shown
  }

  Column {
    spacing: ub.groupGap
    width: parent.width
    Repeater {
      model: ub.nShow
      Item {
        id: grp
        property var c: ub.controllers[index] || ({ id: "", pci: "", name: "", bus: "", speed: "", devices: [] })
        property int shown: ub.plan[index] || 0
        width: ub.width
        height: Math.max(Math.round(86 * ub.u), shown * (ub.rowH + ub.rowGap) - ub.rowGap)

        Rectangle {
          width: ub.cardW; height: parent.height
          color: Hud.rgba(ub.v.line, 0.08); border.width: 1; border.color: Hud.rgba(ub.v.line, 0.6)
          Column {
            anchors { fill: parent; margins: Math.round(8 * ub.u) }
            spacing: Math.round(3 * ub.u)
            T { width: parent.width; text: grp.c.id + "  pci " + String(grp.c.pci).replace(/^0000:/, ""); sz: 9.5; u: ub.u; mono: ub.v.mono; c: ub.v.accent }
            T { width: parent.width; text: String(grp.c.name).toUpperCase(); sz: 12; u: ub.u; mono: ub.v.mono; c: ub.v.ink; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
            T { width: parent.width; text: "bus " + grp.c.bus + " " + grp.c.speed; sz: 9; u: ub.u; mono: ub.v.mono; c: ub.v.dim }
            T { width: parent.width; text: "devices " + grp.c.devices.length + (grp.shown < grp.c.devices.length ? "  (+" + (grp.c.devices.length - grp.shown) + " hidden)" : ""); sz: 9; u: ub.u; mono: ub.v.mono; c: ub.v.dim }
          }
        }
        // spine and per-row ticks
        Rectangle { x: ub.cardW + Math.round(10 * ub.u); y: ub.rowH / 2; width: 1; height: Math.max(0, (grp.shown - 1) * (ub.rowH + ub.rowGap)); color: Hud.rgba(ub.v.line, 0.7); visible: grp.shown > 1 }
        Rectangle { x: ub.cardW; y: grp.height / 2; width: Math.round(10 * ub.u); height: 1; color: Hud.rgba(ub.v.line, 0.7) }
        Repeater {
          model: grp.shown
          Item {
            property var d: (grp.c.devices && grp.c.devices[index]) || ({ id: "", path: "", vidpid: "", speed: "", meta: "", name: "", depth: 1, hub: false })
            readonly property real indent: Math.min(2, Math.max(0, d.depth - 1)) * Math.round(18 * ub.u)
            y: index * (ub.rowH + ub.rowGap)
            x: ub.cardW + Math.round(10 * ub.u)
            width: ub.width - x; height: ub.rowH
            Rectangle { x: 0; y: parent.height / 2; width: Math.round(12 * ub.u) + parent.indent; height: 1; color: Hud.rgba(ub.v.line, 0.7) }
            Rectangle {
              x: Math.round(12 * ub.u) + parent.indent; width: Math.max(0, parent.width - x); height: parent.height
              color: Hud.rgba(ub.v.line, 0.06); border.width: 1; border.color: Hud.rgba(ub.v.line, d.hub ? 0.9 : 0.6)
              T { x: Math.round(8 * ub.u); y: Math.round(4 * ub.u); width: parent.width * 0.7
                  text: d.id + "  " + d.path + "  " + d.vidpid + "  " + d.speed; sz: 9; u: ub.u; mono: ub.v.mono; c: ub.v.accent }
              T { anchors { right: parent.right; rightMargin: Math.round(8 * ub.u) } y: Math.round(4 * ub.u); width: parent.width * 0.25; horizontalAlignment: Text.AlignRight
                  text: d.meta; sz: 9; u: ub.u; mono: ub.v.mono; c: ub.v.dim }
              T { x: Math.round(8 * ub.u); y: Math.round(17 * ub.u); width: parent.width - Math.round(16 * ub.u)
                  text: String(d.name).toUpperCase(); sz: 12; u: ub.u; mono: ub.v.mono; c: ub.v.ink }
            }
          }
        }
      }
    }
  }
  T { visible: ub.nCtl > ub.nShow; anchors { right: parent.right; bottom: parent.bottom } text: "+" + (ub.nCtl - ub.nShow) + " more controllers"; sz: 9; u: ub.u; mono: ub.v ? ub.v.mono : "monospace"; c: ub.v ? ub.v.ink : "#ccc" }
  T { visible: ub.nCtl === 0; anchors.centerIn: parent; text: "NO USB HOST CONTROLLERS"; sz: 11; u: ub.u; mono: ub.v ? ub.v.mono : "monospace"; c: ub.v ? ub.v.dim : "#888" }
}
