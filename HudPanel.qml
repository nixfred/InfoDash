import QtQuick
import "Hud.js" as Hud

// A HUD panel. The chrome (frame, title, tag, ornament) is drawn by the active skin's
// frame file (Skin*.qml, chosen in Skins.js); this item only positions the content area
// the frame reports. Skins never touch colours: they read them from the DashView `v`.
Item {
  id: p
  property string title: ""
  property string tag: ""
  property var v: null                 // the DashView (colours, fonts, skin, u)
  property string slot: ""             // layout id (usb, cpu, ...)
  property bool animate: true          // glide to new rectangles; off while being dragged
  Behavior on x { enabled: p.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Behavior on y { enabled: p.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Behavior on width { enabled: p.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Behavior on height { enabled: p.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  readonly property real u: v ? v.u : 1
  default property alias content: body.data
  readonly property alias bodyItem: body

  readonly property string frameFile: v && v.skin ? v.skin.frame : "SkinStarTrek.qml"
  function loadFrame() { frame.setSource(Qt.resolvedUrl(p.frameFile), { "panel": p }) }
  onFrameFileChanged: loadFrame()
  Component.onCompleted: loadFrame()
  Loader { id: frame; anchors.fill: parent }
  // Plain clicks on a panel belong to the panel: they must not fall through to the overlay backdrop
  // (which closes it) or the desk (which opens the wallpaper switcher). CTRL passes through to the layout drag.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onPressed: function(m) { m.accepted = !(m.modifiers & Qt.ControlModifier) }
  }

  Item {
    id: body
    clip: true
    x: frame.item ? frame.item.bodyX : Math.round(10 * p.u)
    y: frame.item ? frame.item.bodyY : Math.round(30 * p.u)
    width: frame.item ? frame.item.bodyW : p.width - 2 * x
    height: frame.item ? frame.item.bodyH : p.height - y - Math.round(8 * p.u)
  }
}
