import QtQuick
import qs
import qs.components
import qs.services

PopupCard {
    id: root
    popupName: "network"
    contentSpacing: 4
    implicitWidth: Theme.netPopupWidth
    anchor.rect.x: root.barWindow ? root.barWindow.width - 180 - Theme.netPopupWidth : 0

    Text {
        text: "󰛳  Network Interfaces"
        color: Theme.colPurpleGlow
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
        width: parent.width
    }
    Divider { width: parent.width }

    Repeater {
        model: Network.devices
        Rectangle {
            id: ifaceRow
            required property var modelData
            required property int index
            readonly property bool expanded: Network.selectedIface === ifaceRow.modelData.name
            readonly property var activeNet: Network.activeNetworkOf(ifaceRow.modelData)
            width: root.contentWidth
            height: ifaceRowCol.implicitHeight + 14
            radius: 6
            color: ifaceRow.expanded ? Theme.colPopupHover
                                     : (ifaceMa.containsMouse ? Theme.colHover : "transparent")
            Column {
                id: ifaceRowCol
                x: 6
                y: 7
                width: parent.width - 12
                spacing: 6
                Row {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: ifaceRow.modelData.connected ? Theme.colGreen : Theme.colFgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        Text {
                            text: ifaceRow.modelData.name
                            color: Theme.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            text: (ifaceRow.activeNet ? ifaceRow.activeNet.name : "—")
                                  + " (" + Network.deviceTypeName(ifaceRow.modelData.type) + ")"
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        text: ifaceRow.expanded ? "󰅃" : "󰅀"
                        color: Theme.colPurpleGlow
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Column {
                    visible: ifaceRow.expanded
                    width: parent.width
                    spacing: 3
                    Divider {
                        width: parent.width
                        opacity: 0.35
                    }
                    // MAC comes straight from the device object
                    Row {
                        width: ifaceRowCol.width
                        spacing: 6
                        Text {
                            text: "MAC"
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            width: 54
                        }
                        Text {
                            text: ifaceRow.modelData.address
                            color: Theme.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            width: ifaceRowCol.width - 60
                            elide: Text.ElideRight
                        }
                    }
                    Repeater {
                        model: Network.ifaceDetailPairs
                        Row {
                            required property var modelData
                            width: ifaceRowCol.width
                            spacing: 6
                            Text {
                                text: modelData.k
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                width: 54
                            }
                            Text {
                                text: modelData.v
                                color: Theme.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                width: ifaceRowCol.width - 60
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Text {
                        visible: Network.ifaceDetailPairs.length === 0
                        text: "Reading interface..."
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
            MouseArea {
                id: ifaceMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Network.selectIface(ifaceRow.modelData.name)
            }
        }
    }
    Text {
        visible: Network.devices.length === 0
        text: "No devices"
        color: Theme.colFgDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
        topPadding: 8
    }
}
