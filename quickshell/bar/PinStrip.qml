import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// The pinned launchers at the left of the bar.
//
// Three gestures, all Windows-like: drag a pin sideways to reorder, drag it up
// off the bar to unpin, and drop an app dragged out of the app launcher to pin
// it. The launcher drag starts in a different window, so it arrives through
// Launchers rather than as a drop event — see services/Launchers.qml.
Item {
    id: strip

    // Only the bar on the screen the launcher is drawn on reacts to a drag
    // coming out of it.
    property string screenName: ""

    readonly property int slotWidth: 34
    readonly property int slotSpacing: 6
    readonly property int pitch: slotWidth + slotSpacing

    // ── Drag of an existing pin ──────────────────────────────────────
    property bool dragging: false
    property real ghostX: 0
    property real ghostY: 0
    property string ghostIcon: ""
    property string ghostFallback: ""

    // ── Drag of a new app in from the launcher ───────────────────────
    // Pointer arrives in bar-window coordinates; mapFromItem(null, …) turns
    // those into strip coordinates because the bar's scene is the bar window.
    readonly property point incomingPos: Launchers.pendingEntry
        ? strip.mapFromItem(null, Launchers.pendingX, Launchers.pendingY)
        : Qt.point(-1000, -1000)
    readonly property bool incoming: Launchers.pendingEntry !== null
        && Launchers.pendingScreen === strip.screenName
        && Launchers.pendingY >= -6
        && Launchers.pendingY <= Theme.barHeight + 6
        && strip.incomingPos.x >= -strip.pitch
        && strip.incomingPos.x <= row.implicitWidth + strip.pitch
    readonly property int incomingIndex: Math.max(0, Math.min(Launchers.count,
        Math.round(strip.incomingPos.x / strip.pitch)))

    // The trailing slot is the room to drop *after* the last pin; it only
    // exists while something is being dragged in, so the bar doesn't carry a
    // permanent gap.
    implicitWidth: row.implicitWidth + (strip.incoming ? strip.pitch : 0)
    implicitHeight: strip.slotWidth
    Layout.preferredHeight: strip.slotWidth

    Behavior on implicitWidth {
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    Connections {
        target: Launchers
        function onIncomingDropped() {
            if (!strip.incoming) return
            Launchers.insertEntry(Launchers.pendingEntry, strip.incomingIndex)
        }
    }

    // ── Drag bookkeeping ─────────────────────────────────────────────
    function beginDrag(i) {
        var r = Launchers.model.get(i)
        if (!r) return
        strip.ghostIcon = r.icon
        strip.ghostFallback = r.fallback
        strip.dragging = true
        Launchers.dragIndex = i
        Launchers.dragRemoving = false
    }

    function updateDrag(scenePos) {
        var p = strip.mapFromItem(null, scenePos.x, scenePos.y)
        strip.ghostX = p.x - strip.slotWidth / 2
        strip.ghostY = p.y - strip.slotWidth / 2
        // The bar is only 34px of usable height, so "off the bar" is measured
        // vertically — dragging past either edge arms the unpin.
        Launchers.dragRemoving = p.y < -24 || p.y > strip.height + 24
        if (Launchers.dragRemoving) return
        var target = Math.max(0, Math.min(Launchers.count - 1,
                                          Math.floor(p.x / strip.pitch)))
        if (target !== Launchers.dragIndex) {
            Launchers.movePin(Launchers.dragIndex, target)
            Launchers.dragIndex = target
        }
    }

    function endDrag() {
        if (!strip.dragging) return
        strip.dragging = false
        var i = Launchers.dragIndex
        Launchers.dragIndex = -1
        if (Launchers.dragRemoving) {
            Launchers.dragRemoving = false
            Launchers.removePin(i)
        } else {
            Launchers.save()
        }
    }

    // ── The pins ─────────────────────────────────────────────────────
    Row {
        id: row
        height: parent.height
        spacing: strip.slotSpacing
        // Neighbours slide out of the way as the dragged pin passes them.
        move: Transition {
            NumberAnimation { properties: "x"; duration: 120; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: Launchers.model

            delegate: Item {
                id: slot
                required property int index
                required property string name
                required property string icon
                required property string fallback

                width: strip.slotWidth
                height: strip.slotWidth

                readonly property bool lifted: Launchers.dragIndex === slot.index

                BarButton {
                    id: vis
                    anchors.fill: parent
                    bordered: false
                    // The row the ghost came out of reads as an empty socket.
                    opacity: slot.lifted ? 0.25 : 1
                    onClicked: Launchers.launch(slot.index)

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconSize
                        height: Theme.iconSize
                        // Glyph sits behind the icon and shows through if the
                        // themed icon can't be resolved.
                        Text {
                            anchors.centerIn: parent
                            text: slot.fallback
                            color: Theme.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }
                        IconImage {
                            anchors.fill: parent
                            source: slot.icon ? ("image://icon/" + slot.icon) : ""
                        }
                    }

                    // Takes the grab away from BarButton's MouseArea once the
                    // pointer passes the drag threshold, which cancels the
                    // click — so a tap still launches and a drag doesn't.
                    DragHandler {
                        id: pinDrag
                        target: null
                        cursorShape: Qt.ClosedHandCursor
                        onActiveChanged: {
                            if (pinDrag.active) strip.beginDrag(slot.index)
                            else strip.endDrag()
                        }
                        onCentroidChanged: {
                            if (pinDrag.active) strip.updateDrag(pinDrag.centroid.scenePosition)
                        }
                    }
                }
            }
        }
    }

    // ── Insertion caret for an app coming from the launcher ──────────
    Rectangle {
        visible: strip.incoming
        width: 3
        radius: 1.5
        height: parent.height
        // Centred in the gap before the pin it would land in front of.
        x: strip.incomingIndex * strip.pitch - strip.slotSpacing / 2 - width / 2
        color: Theme.colPurpleGlow
        Behavior on x {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }
    }

    // ── The dragged pin, following the pointer ───────────────────────
    Item {
        id: ghost
        visible: strip.dragging
        z: 10
        width: strip.slotWidth
        height: strip.slotWidth
        // Clamped to the bar: a layer surface can't paint outside itself, so
        // an unpin drag shows as the red tint below rather than the icon
        // leaving the bar.
        x: strip.ghostX
        y: Math.max(-4, Math.min(strip.height - height + 4, strip.ghostY))
        opacity: Launchers.dragRemoving ? 0.55 : 0.95

        Rectangle {
            anchors.fill: parent
            radius: Theme.widgetRadius
            color: Launchers.dragRemoving ? Theme.colRed : Theme.colHover
            opacity: Launchers.dragRemoving ? 0.35 : 1
            border.color: Launchers.dragRemoving ? Theme.colRed : Theme.colPurpleBorder
            border.width: Theme.borderWidth
        }
        Item {
            anchors.centerIn: parent
            width: Theme.iconSize
            height: Theme.iconSize
            Text {
                anchors.centerIn: parent
                text: strip.ghostFallback
                color: Theme.colFg
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            IconImage {
                anchors.fill: parent
                source: strip.ghostIcon ? ("image://icon/" + strip.ghostIcon) : ""
            }
        }
    }
}
