import QtQuick
import QtQuick.Effects

// Screensaver-styled lock backdrop: the branding art (the same file the
// terminal screensaver renders) on black, revealed row by row when the lock
// comes up, then kept alive with a scanning accent beam and a slow glow.
// Children are placed in the slot under the clock (the password field).
Item {
  id: root

  property string artText: ""
  property color ink: "#c0caf5"
  property color accent: "#7aa2f7"
  property color muted: "#565f89"
  property string fontFamily: "monospace"
  // True while the lock (or its preview) is on screen. Rising edge replays
  // the reveal; false parks every animation.
  property bool active: true

  default property alias slotData: slot.data
  property real slotHeight: 67

  readonly property var rows: splitRows(artText)
  readonly property int rowCount: Math.max(1, rows.length)
  readonly property int colCount: {
    var n = 1
    for (var i = 0; i < rows.length; i++) n = Math.max(n, rows[i].length)
    return n
  }

  // Terminal-like cell: braille glyphs stack into continuous shapes only when
  // rows sit close together, so line height stays near the glyph height.
  readonly property real cellRatio: 1.18
  readonly property real fontPx: Math.max(8, Math.floor(Math.min(
    height * 0.42 / (rowCount * cellRatio),
    width * 0.8 / (colCount * 0.6))))
  readonly property real rowPx: Math.round(fontPx * cellRatio)

  property real reveal: 0
  property real sweep: 0
  property real breathe: 0
  property date now: new Date()

  function splitRows(text) {
    var lines = String(text || "").replace(/\s+$/, "").split("\n")
    while (lines.length > 0 && lines[0].trim().length === 0) lines.shift()
    return lines
  }

  // Art rests a little below full ink so the beam has room to brighten it.
  readonly property color restInk: Qt.tint(root.muted, Qt.alpha(root.ink, 0.72))
  readonly property color beamColor: Qt.lighter(root.accent, 1.45)

  component ArtRows: Column {
    Repeater {
      model: root.rows
      Text {
        required property string modelData
        required property int index
        height: root.rowPx
        text: modelData.length > 0 ? modelData : " "
        textFormat: Text.PlainText
        color: Qt.tint(root.restInk, Qt.alpha(root.beamColor, 0.95 * root.beamAt(index)))
        font.family: root.fontFamily
        font.pixelSize: root.fontPx
        verticalAlignment: Text.AlignVCenter
        opacity: root.rowOpacity(index)
        transform: Translate { y: (1 - root.rowOpacity(index)) * root.rowPx * 0.6 }
      }
    }
  }

  // Brightness of the scan beam on a row: a soft band, ~4 rows tall, that
  // travels from above the art to below it as sweep goes 0 -> 1.
  function beamAt(index) {
    var centre = sweep * (rowCount + 8) - 4
    var d = (index - centre) / 2.2
    return Math.exp(-d * d)
  }

  function rowOpacity(index) {
    // Each row fades over a window of 5 rows, staggered top to bottom.
    var t = reveal * (rowCount + 5) - index
    return Math.max(0, Math.min(1, t / 5))
  }

  onActiveChanged: if (active) replay()
  Component.onCompleted: if (active) replay()

  function replay() {
    now = new Date()
    revealAnim.restart()
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
  }

  Column {
    id: stack
    anchors.centerIn: parent
    spacing: Math.round(root.fontPx * 1.4)

    Item {
      id: artBlock
      anchors.horizontalCenter: parent.horizontalCenter
      width: artRows.width
      height: artRows.height

      // Padded, layered copy of the art: the halo samples this with explicit
      // room for the blur, so it lines up with the crisp art drawn on top.
      Item {
        id: artLayer
        readonly property real pad: Math.round(root.fontPx * 2)
        x: -pad
        y: -pad
        width: artRows.width + pad * 2
        height: artRows.height + pad * 2
        layer.enabled: true
        visible: false

        ArtRows { x: artLayer.pad; y: artLayer.pad }
      }

      // Soft halo behind the art, breathing in the accent colour.
      MultiEffect {
        anchors.fill: artLayer
        source: artLayer
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        colorization: 1.0
        colorizationColor: root.accent
        opacity: (0.25 + 0.3 * root.breathe) * root.reveal
      }

      ArtRows { id: artRows }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Math.round(root.fontPx * 0.3)
      opacity: Math.max(0, Math.min(1, root.reveal * 2 - 0.6))

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        // 24-hour clock regardless of locale; the date below follows the locale.
        text: Qt.formatTime(root.now, "HH:mm")
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.fontPx * 2.8)
        font.weight: Font.Light
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.fontPx * 0.95)
      }
    }

    Item {
      id: slot
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.width
      height: root.slotHeight
      opacity: Math.max(0, Math.min(1, root.reveal * 2 - 1))
    }
  }

  NumberAnimation {
    id: revealAnim
    target: root
    property: "reveal"
    from: 0
    to: 1
    duration: 2400
    easing.type: Easing.OutCubic
  }

  SequentialAnimation {
    running: root.active
    loops: Animation.Infinite
    PauseAnimation { duration: 2200 }
    NumberAnimation { target: root; property: "sweep"; from: 0; to: 1; duration: 2600; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 3600 }
  }

  SequentialAnimation {
    running: root.active
    loops: Animation.Infinite
    NumberAnimation { target: root; property: "breathe"; from: 0; to: 1; duration: 4200; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "breathe"; from: 1; to: 0; duration: 4200; easing.type: Easing.InOutSine }
  }

  Timer {
    running: root.active
    repeat: true
    interval: 1000
    onTriggered: root.now = new Date()
  }
}
