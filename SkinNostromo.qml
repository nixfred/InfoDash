import QtQuick
import "Hud.js" as Hud

// NOSTROMO: a double-ruled terminal box, bracketed title and tag cut into the top rule,
// faint scanlines and a blinking cursor. No gloss; everything blocky and monospace.
Item {
  id: f
  TextMetrics { id: tmTag; text: panel && panel.tag !== "" ? "[ " + panel.tag + " ]" : ""; font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9 * f.u)); font.bold: false; font.letterSpacing: 0; font.italic: false }
  TextMetrics { id: tmTitle; text: "[ " + String(panel ? panel.title : "") + " ]"; font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(10.5 * f.u)); font.bold: true; font.letterSpacing: 1.2 * f.u; font.italic: false }
  property var panel: null
  readonly property var v: panel ? panel.v : null
  readonly property real u: panel ? panel.u : 1
  readonly property color ink: v ? v.ink : "#ccc"
  readonly property real tagBoxW: tmTag.text === "" ? 0 : Math.min(width * 0.4, tmTag.advanceWidth + Math.round(8 * u))
  readonly property real maskW: Math.max(0, Math.min(tmTitle.advanceWidth + Math.round(24 * u), width - Math.round(28 * u) - tagBoxW - Math.round(6 * u)))
  readonly property real bodyX: Math.round(14 * u)
  readonly property real bodyY: Math.round(22 * u)
  readonly property real bodyW: width - 2 * bodyX
  readonly property real bodyH: height - bodyY - Math.round(14 * u)

  Rectangle { anchors.fill: parent; color: f.v ? Hud.rgba(f.v.bg, 0.8) : "#000" }
  Rectangle { x: Math.round(2 * f.u); y: Math.round(7 * f.u); width: f.width - 2 * x; height: f.height - y - Math.round(2 * f.u); color: "transparent"
              border.width: 2; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.78) }
  Rectangle { x: Math.round(6 * f.u); y: Math.round(11 * f.u); width: f.width - 2 * x; height: f.height - y - Math.round(6 * f.u); color: "transparent"
              border.width: 1; border.color: Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.3) }
  Canvas {   // scanlines, painted once per size
    anchors.fill: parent
    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
    Connections { target: f.v; function onInkChanged() { requestPaint() } }
    onPaint: {
      var c = getContext("2d"); c.reset()
      if (!f.v) return
      c.fillStyle = Hud.css(f.v.ink, 0.06)
      for (var y = 0; y < height; y += 3) c.fillRect(0, y, width, 1)
    }
  }
  // bracketed title, masking the rule behind it
  Rectangle { x: Math.round(14 * f.u); y: 0; width: f.maskW; height: Math.round(15 * f.u); color: f.v ? Hud.rgba(f.v.bg, 0.97) : "#000"
    Text { textFormat: Text.PlainText; id: title; x: Math.round(4 * f.u); width: Math.max(0, parent.width - Math.round(8 * f.u)); height: parent.height; verticalAlignment: Text.AlignVCenter
           text: "[ " + String(panel ? panel.title : "") + " ]"; color: f.v ? f.v.ink : "#ccc"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(9, Math.round(10.5 * f.u)); font.bold: true; font.letterSpacing: 1.2 * f.u }
    Rectangle { id: cursor; visible: f.maskW >= tmTitle.advanceWidth + Math.round(24 * f.u); x: title.x + tmTitle.advanceWidth + Math.round(3 * f.u); y: Math.round(3 * f.u); width: Math.round(6 * f.u); height: Math.round(9 * f.u); color: f.v ? f.v.accent : "#0ff"
                SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0.0; duration: 600 } NumberAnimation { to: 1.0; duration: 600 } } }
  }
  Rectangle { visible: tag.text !== ""; anchors.right: parent.right; anchors.rightMargin: Math.round(14 * f.u); y: 0
              width: f.tagBoxW; height: Math.round(15 * f.u); color: f.v ? Hud.rgba(f.v.bg, 0.97) : "#000"
    Text { textFormat: Text.PlainText; id: tag; anchors.fill: parent; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
           text: panel && panel.tag !== "" ? "[ " + panel.tag + " ]" : ""; color: f.v ? f.v.dim : "#888"; elide: Text.ElideRight
           font.family: f.v ? f.v.mono : "monospace"; font.pixelSize: Math.max(8, Math.round(9 * f.u)) } }
}
