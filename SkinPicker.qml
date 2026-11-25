import QtQuick
import "Hud.js" as Hud
import "Skins.js" as Skins

// The skin switcher. A small, dim chip in the header shows the current skin; clicking it
// opens a compact strip of every skin (hover shows a one-line hint). Pick one, press Esc or
// click away and it closes. Quiet by default so it stays out of the way.
Item {
  id: sp
  property var v: null                 // the DashView
  property bool open: false
  readonly property real u: v ? v.u : 1
  readonly property string current: v && v.skin ? v.skin.id : Skins.DEFAULT
  property string hint: ""
  width: chip.width; height: chip.height

  Rectangle {
    id: chip
    height: Math.round(19 * sp.u); width: label.implicitWidth + Math.round(22 * sp.u)
    radius: !sp.v || !sp.v.skin ? 0 : (sp.v.skin.btn === "pill" ? height / 2 : (sp.v.skin.btn === "round" ? Math.round(4 * sp.u) : 0))
    color: sp.open ? Hud.rgba(sp.v.accent, 0.2) : "transparent"
    border.width: 1
    border.color: Hud.rgba(sp.open || ma.containsMouse ? sp.v.accent : sp.v.line, sp.open || ma.containsMouse ? 0.95 : 0.35)
    T { id: label; anchors.centerIn: parent; text: "SKIN  ▸  " + (sp.v && sp.v.skin ? sp.v.skin.name : ""); sz: 9; u: sp.u; mono: sp.v.mono; c: sp.open ? sp.v.accent : sp.v.ink; font.letterSpacing: 1.6 * sp.u; elide: Text.ElideNone }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sp.open = !sp.open }
  }

  Rectangle {
    id: strip
    visible: sp.open
    x: 0; y: chip.height + Math.round(6 * sp.u)
    width: Math.max(flow.width, sizeRow.width) + Math.round(20 * sp.u); height: flow.height + sizeRow.height + hintT.height + Math.round(30 * sp.u)
    color: Hud.rgba(sp.v.bg, 0.94); border.width: 1; border.color: Hud.rgba(sp.v.accent, 0.8)
    radius: chip.radius > 0 ? Math.round(6 * sp.u) : 0
    // Equal-width cells in a grid whose column count divides the skin count, so the rows are
    // always even (one row of 9, or 3 x 3 when space is tight; never a stray last button).
    TextMetrics { id: tm; font.family: sp.v.mono; font.pixelSize: Math.max(8, Math.round(9.5 * sp.u)); font.letterSpacing: 1.4 * sp.u
                  text: Skins.list.reduce(function(a, k) { return k.name.length > a.length ? k.name : a }, "") }
    readonly property real cellW: tm.advanceWidth + Math.round(26 * sp.u)
    readonly property real avail: (sp.v ? sp.v.width : 1200) - (sp.parent ? sp.parent.x : 0) - sp.x - Math.round(40 * sp.u)
    readonly property int cols: {
      var n = Skins.list.length, sps = Math.round(6 * sp.u)
      for (var d = n; d >= 1; d--)
        if (n % d === 0 && d * cellW + (d - 1) * sps <= avail) return d
      return 1
    }
    Grid {
      id: flow
      x: Math.round(10 * sp.u); y: Math.round(9 * sp.u)
      columns: strip.cols
      columnSpacing: Math.round(6 * sp.u); rowSpacing: Math.round(6 * sp.u)
      Repeater {
        model: Skins.list
        delegate: HudButton {
          required property var modelData
          v: sp.v; sz: 9.5
          width: strip.cellW
          label: modelData.name
          active: modelData.id === sp.current
          onClicked: { if (sp.v && sp.v.desk) sp.v.desk.setSkin(modelData.id); sp.open = false }
          onHoveredChanged: sp.hint = hovered ? modelData.hint : ""
        }
      }
    }
    // InfoDash's own text size (independent of the system font size): 70% to 180%
    Row {
      id: sizeRow
      x: Math.round(10 * sp.u); y: flow.y + flow.height + Math.round(8 * sp.u)
      spacing: Math.round(8 * sp.u); height: Math.round(24 * sp.u)
      T { anchors.verticalCenter: parent.verticalCenter; text: "TEXT SIZE"; sz: 9.5; u: sp.u; mono: sp.v.mono; c: sp.v.ink; font.letterSpacing: 1.4 * sp.u; elide: Text.ElideNone }
      HudButton { v: sp.v; sz: 10; width: Math.round(36 * sp.u); label: "A\u2212"; onClicked: sp.v.desk.setFontScale(sp.v.fontScale - 0.1) }
      T { anchors.verticalCenter: parent.verticalCenter; width: Math.round(46 * sp.u); horizontalAlignment: Text.AlignHCenter
          text: Math.round(sp.v.fontScale * 100) + "%"; sz: 10.5; u: sp.u; mono: sp.v.mono; c: sp.v.accent; font.bold: true; elide: Text.ElideNone }
      HudButton { v: sp.v; sz: 10; width: Math.round(36 * sp.u); label: "A+"; onClicked: sp.v.desk.setFontScale(sp.v.fontScale + 0.1) }
      HudButton { v: sp.v; sz: 9.5; width: Math.round(64 * sp.u); label: "RESET"; visible: Math.abs(sp.v.fontScale - 1) > 0.001; onClicked: sp.v.desk.setFontScale(1) }
    }
    T { id: hintT; x: Math.round(11 * sp.u); y: sizeRow.y + sizeRow.height + Math.round(6 * sp.u); width: parent.width - Math.round(22 * sp.u)
        text: sp.hint !== "" ? sp.hint : "colours always follow the Omarchy theme"; sz: 9; u: sp.u; mono: sp.v.mono; c: sp.v.dim; font.letterSpacing: 1 * sp.u }
  }
}
