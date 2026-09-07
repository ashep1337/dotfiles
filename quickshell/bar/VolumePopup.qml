import QtQuick
import qs
import qs.components
import qs.services

PopupCard {
    id: root
    popupName: "volume"
    contentSpacing: 10
    implicitWidth: Theme.volPopupWidth
    anchor.rect.x: root.barWindow ? root.barWindow.width - 90 - Theme.volPopupWidth : 0

    // A drag that ends because the popup vanished never gets a release event,
    // so the knob would stay enlarged next time it opens.
    Connections {
        target: root
        function onVisibleChanged() {
            if (!root.visible) Audio.dragging = false
        }
    }

    Text {
        text: "󰕾  " + ((Audio.sink && Audio.sink.description) ? Audio.sink.description : "Volume")
        color: Theme.colPurpleGlow
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
        width: parent.width
        elide: Text.ElideRight
    }
    Divider { width: parent.width }

    Item {
        width: parent.width
        height: 26
        Rectangle {
            id: sliderTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: Theme.colPopupInset
            Rectangle {
                id: sliderFill
                width: sliderTrack.width * (Audio.display / 100)
                height: parent.height
                radius: 4
                color: Audio.muted ? Theme.colFgDim : Theme.colPurpleGlow
            }
            Rectangle {
                id: sliderKnob
                width: 16
                height: 16
                radius: 8
                x: Math.max(0, Math.min(sliderTrack.width - width,
                                        sliderTrack.width * (Audio.display / 100) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                color: Audio.muted ? Theme.colFgDim : Theme.colFg
                border.color: Theme.colPurpleBorder
                border.width: 2
                scale: (sliderMa.containsMouse || Audio.dragging) ? 1.15 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 80 }
                }
            }
            // Taller than the 8px track so the grab target is a comfortable
            // 26px without a fat groove.
            MouseArea {
                id: sliderMa
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 26
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function percentAt(x) {
                    return (x / sliderTrack.width) * 100
                }
                onPressed: mouse => {
                    Audio.dragging = true
                    Audio.setVolume(percentAt(mouse.x))
                }
                onPositionChanged: mouse => {
                    if (Audio.dragging) Audio.setVolume(percentAt(mouse.x))
                }
                onReleased: mouse => {
                    Audio.setVolume(percentAt(mouse.x))
                    Audio.dragging = false
                }
                onCanceled: Audio.dragging = false
                onWheel: wheel => {
                    Audio.nudge(wheel.angleDelta.y > 0 ? 5 : -5)
                }
            }
        }
    }

    Row {
        width: parent.width
        spacing: 10
        Text {
            text: Audio.display + "%"
            color: Audio.muted ? Theme.colFgDim : Theme.colFg
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 10; height: 1 }
        Rectangle {
            width: muteBtnRow.implicitWidth + 16
            height: 28
            radius: 6
            color: muteMa.containsMouse ? Theme.colHover : "transparent"
            border.color: Theme.colPurpleBorder
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Row {
                id: muteBtnRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: Audio.muted ? "󰖁" : "󰕾"
                    color: Audio.muted ? Theme.colRed : Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Audio.muted ? "Unmute" : "Mute"
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
        }
    }
}
