import QtQuick

// One text style for the whole HUD: mono, plain text, elided, sized in HUD units.
Text {
  property real sz: 11
  property real u: 1
  property string mono: "monospace"
  property color c: "#ccc"
  color: c
  font.family: mono
  font.pixelSize: Math.max(6, Math.round(sz * u))
  textFormat: Text.PlainText
  elide: Text.ElideRight
  renderType: Text.NativeRendering
}
