import QtQuick

// One table row: cells laid out by fractional column widths. `head` dims it.
Item {
  id: r
  property var v: null
  property var cells: []
  property var fr: []
  property var colors: []
  property bool head: false
  property real sz: 10.5
  readonly property real u: v ? v.u : 1
  height: Math.round(18 * u)
  function off(i) { var s = 0; for (var k = 0; k < i; k++) s += r.fr[k]; return s * r.width }
  Repeater {
    model: r.cells.length
    T {
      x: r.off(index); width: Math.max(0, r.fr[index] * r.width - Math.round(6 * r.u))
      anchors.verticalCenter: parent.verticalCenter
      text: String(r.cells[index]); u: r.u; mono: r.v ? r.v.mono : "monospace"
      sz: r.head ? r.sz - 1 : r.sz
      c: r.head ? (r.v ? r.v.dim : "#888") : (r.colors[index] !== undefined ? r.colors[index] : (r.v ? r.v.ink : "#fff"))
      font.letterSpacing: r.head ? 1.2 * r.u : 0
    }
  }
}
