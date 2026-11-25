import QtQuick

// Key on the left (dim), value on the right (ink): one line of a stat block.
Item {
  id: kv
  property var v: null
  property string k: ""
  property string val: ""
  property color vc: v ? v.ink : "#fff"
  readonly property real u: v ? v.u : 1
  height: Math.round(16 * u)
  T { id: valT; anchors.right: parent.right; width: Math.min(implicitWidth, parent.width * 0.7); horizontalAlignment: Text.AlignRight
      text: kv.val; sz: 10; u: kv.u; mono: kv.v ? kv.v.mono : "monospace"; c: kv.vc }
  T { anchors.left: parent.left; width: Math.max(0, parent.width - valT.width - Math.round(8 * kv.u)); text: kv.k; sz: 10; u: kv.u; mono: kv.v ? kv.v.mono : "monospace"; c: kv.v ? kv.v.dim : "#888" }
}
