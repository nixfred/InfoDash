.pragma library
// Infodash skins. A skin changes SHAPE, TYPE, ORNAMENT and GAUGE STYLE, never colour:
// every colour a skin draws comes from the Omarchy system theme through DashView
// (ink, bg, line, glow, accent, blue, yellow, cyan, danger, ok).
//
//   frame   QML file in this folder that draws the panel chrome and reports the body rect
//   gauge   dial art: ring | arc | needle | knob | seg | fan | draft | ascii
//   spark   history art: area | line | step
//   fonts   preferred families in order ("mono" = the Omarchy UI font); first one installed wins
//   btn     button corner: pill | round | square | cut
//   spacing letter-spacing multiplier for titles
//   bold    titles bold

var list = [
  { id: "startrek",  name: "STAR TREK",  hint: "LCARS elbows and pills",         frame: "SkinStarTrek.qml",   gauge: "ring",   spark: "area", fonts: ["Noto Sans", "DejaVu Sans"],              btn: "pill",   spacing: 1.8, bold: true },
  { id: "cyberpunk", name: "CYBERPUNK",  hint: "Chamfered edges, hazard tabs",   frame: "SkinCyberpunk.qml",  gauge: "arc",    spark: "area", fonts: ["mono"],                                  btn: "cut",    spacing: 2.2, bold: true },
  { id: "steampunk", name: "STEAMPUNK",  hint: "Riveted plates and gears",       frame: "SkinSteampunk.qml",  gauge: "needle", spark: "line", fonts: ["DejaVu Serif", "Liberation Serif"],       btn: "round",  spacing: 1.2, bold: true },
  { id: "deco",      name: "ART DECO",   hint: "Stepped corners, sunbursts",     frame: "SkinDeco.qml",       gauge: "fan",    spark: "line", fonts: ["DejaVu Sans", "Noto Sans"],              btn: "square", spacing: 3.0, bold: false },
  { id: "8bit",      name: "8-BIT",      hint: "Pixel tiles, block meters",      frame: "Skin8Bit.qml",       gauge: "seg",    spark: "step", fonts: ["DejaVu Sans Mono", "mono"],              btn: "square", spacing: 1.0, bold: true },
  { id: "blueprint", name: "BLUEPRINT",  hint: "Drafting lines, dimensions",     frame: "SkinBlueprint.qml",  gauge: "draft",  spark: "line", fonts: ["Nimbus Mono PS", "iA Writer Mono S", "mono"], btn: "square", spacing: 1.6, bold: false },
  { id: "nostromo",  name: "NOSTROMO",   hint: "Amber-terminal CRT, scanlines",  frame: "SkinNostromo.qml",   gauge: "ascii",  spark: "step", fonts: ["Nimbus Mono PS", "DejaVu Sans Mono", "mono"], btn: "square", spacing: 1.2, bold: true },
  { id: "cassette",  name: "CASSETTE",   hint: "Bezels, screws, label strips",   frame: "SkinCassette.qml",   gauge: "knob",   spark: "step", fonts: ["Liberation Mono", "iA Writer Mono S", "mono"], btn: "round",  spacing: 1.4, bold: true },
  { id: "diesel",    name: "DIESEL",     hint: "Steel plate, stencil, needles",  frame: "SkinDiesel.qml",     gauge: "needle", spark: "line", fonts: ["DejaVu Sans", "Liberation Sans"],        btn: "square", spacing: 2.4, bold: true }
]

var DEFAULT = "startrek"

function ids() { return list.map(function(s) { return s.id }) }
function valid(id) { for (var i = 0; i < list.length; i++) if (list[i].id === id) return true; return false }
function get(id) { for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return list[0] }
function next(id, step) {
  var i = 0
  for (var k = 0; k < list.length; k++) if (list[k].id === id) i = k
  return list[(i + (step || 1) + list.length * 4) % list.length].id
}
