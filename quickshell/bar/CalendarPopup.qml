import QtQuick
import qs
import qs.components
import qs.services

PopupCard {
    id: root
    popupName: "calendar"
    contentMargin: 20
    implicitWidth: Theme.calPopupWidth
    anchor.rect.x: root.barWindow
        ? Math.round((root.barWindow.width - Theme.calPopupWidth) / 2) : 0

    readonly property int cellWidth: Math.floor((root.contentWidth - 12) / 7)

    Row {
        width: parent.width
        spacing: 4
        Rectangle {
            width: 26
            height: 26
            radius: 6
            color: calPrevMa.containsMouse ? Theme.colHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: "󰅁"
                color: Theme.colFg
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
            MouseArea {
                id: calPrevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: CalendarState.shift(-1)
            }
        }
        Item {
            width: parent.width - 60
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(CalendarState.ref, "MMMM yyyy")
                color: Theme.colPurpleGlow
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: CalendarState.today()   // jump back to current month
            }
        }
        Rectangle {
            width: 26
            height: 26
            radius: 6
            color: calNextMa.containsMouse ? Theme.colHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Theme.colFg
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
            MouseArea {
                id: calNextMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: CalendarState.shift(1)
            }
        }
    }
    Divider { width: parent.width }

    Grid {
        columns: 7
        spacing: 2
        width: parent.width
        Repeater {
            model: CalendarState.dayNames
            Item {
                required property var modelData
                width: root.cellWidth
                height: 18
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: Theme.colFgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }
    }
    Grid {
        columns: 7
        spacing: 2
        width: parent.width
        Repeater {
            model: CalendarState.cells
            Rectangle {
                id: dayCell
                required property var modelData
                width: root.cellWidth
                height: 26
                radius: 5
                color: dayCell.modelData.isToday ? Theme.colPurple : "transparent"
                border.color: dayCell.modelData.isToday ? Theme.colPurpleGlow : "transparent"
                border.width: dayCell.modelData.isToday ? 1 : 0
                Text {
                    anchors.centerIn: parent
                    visible: dayCell.modelData.current
                    text: dayCell.modelData.day
                    color: dayCell.modelData.isToday ? Theme.colFg : Theme.colFgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: dayCell.modelData.isToday
                }
            }
        }
    }
    Divider { width: parent.width }
    Text {
        text: Clock.currentDate + "  ·  " + Clock.currentTime
        color: Theme.colFgDim
        font.family: Theme.fontFamily
        font.pixelSize: 10
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }
}
