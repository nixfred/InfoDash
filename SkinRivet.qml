import QtQuick

// A rivet or screw head: a disc with a small highlight. Colours come from the DashView `v`.
Rectangle {
  id: r
  property var v: null
  property real d: 6
  property real a: 0.55
  property bool slot: false
  width: d; height: d; radius: d / 2
  color: v ? Qt.rgba(v.ink.r, v.ink.g, v.ink.b, a) : "#888"
  Rectangle { visible: !r.slot; x: r.d * 0.2; y: r.d * 0.15; width: r.d * 0.35; height: width; radius: width / 2; color: r.v ? Qt.rgba(r.v.ink.r, r.v.ink.g, r.v.ink.b, 0.55) : "#ccc" }
  Rectangle { visible: r.slot; anchors.centerIn: parent; width: r.d * 0.8; height: Math.max(1, r.d * 0.16); rotation: 35; color: r.v ? r.v.bg : "#000" }
}
