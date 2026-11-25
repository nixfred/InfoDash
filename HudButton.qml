import QtQuick
import "Hud.js" as Hud

// Flat HUD button. `active` fills it with the accent; hover brightens the border.
Rectangle {
  id: b
  property string label: ""
  property bool active: false
  property var v: null
  property real sz: 10.5
  signal clicked()
  readonly property bool hovered: ma.containsMouse
  readonly property real u: v ? v.u : 1
  implicitWidth: lab.implicitWidth + Math.round(22 * u)
  implicitHeight: Math.round(24 * u)
  color: active ? Hud.rgba(v.accent, 0.22) : (ma.containsMouse ? Hud.rgba(v.line, 0.18) : "transparent")
  radius: !v || !v.skin ? 0 : (v.skin.btn === "pill" ? height / 2 : (v.skin.btn === "round" ? Math.round(4 * u) : (v.skin.btn === "cut" ? Math.round(2 * u) : 0)))
  border.width: 1
  border.color: active ? v.accent : (ma.containsMouse ? v.glow : Hud.rgba(v.line, 0.7))
  T { id: lab; anchors.centerIn: parent; text: b.label; sz: b.sz; u: b.u; mono: b.v.mono; c: b.active ? b.v.accent : b.v.ink; font.letterSpacing: 1.4 * b.u; elide: Text.ElideNone }
  MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
