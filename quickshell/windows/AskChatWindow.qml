import Quickshell
import QtQuick
import qs
import qs.components
import qs.services

// The threaded view: transcript kept, session resumed on every send.
FloatingWindow {
    id: chatWindow
    title: "Claude Chat"
    visible: Ask.open && Ask.chat
    implicitWidth: 900
    implicitHeight: 650
    color: Theme.colPopupBg
    onVisibleChanged: if (visible) chatInput.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth
        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: "󰭹  Claude"
                    color: Theme.colPurpleGlow
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: parent.width - 370; height: 1 }
                AskModelPicker { anchors.verticalCenter: parent.verticalCenter }
                AskModeSwitch { anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 56
                    height: 24
                    radius: 6
                    color: newMa.containsMouse ? Theme.colHover : "transparent"
                    border.color: Theme.colPurpleBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "New"
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: newMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ask.newSession()
                    }
                }
            }

            Divider { width: parent.width }

            ListView {
                id: chatList
                width: parent.width
                height: parent.height - 130
                clip: true
                spacing: 12
                model: Ask.transcript
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: chatList.positionViewAtEnd()
                delegate: Column {
                    required property var modelData
                    width: chatList.width
                    spacing: 3
                    Text {
                        text: modelData.role === "you" ? "you" : "claude"
                        color: modelData.role === "you" ? Theme.colFgDim : Theme.colPurpleGlow
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                    TextEdit {
                        text: modelData.text
                        color: Theme.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        selectionColor: Theme.colPurple
                        selectedTextColor: Theme.colFg
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                    }
                }
            }

            Text {
                visible: Ask.busy || Ask.errorText !== ""
                width: parent.width
                text: Ask.busy ? "Thinking... (esc to cancel)" : Ask.errorText
                color: Ask.errorText !== "" ? Theme.colRed : Theme.colFgDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }

            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.widgetRadius
                color: Theme.colPopupInset
                border.color: Theme.colPurpleBorder
                border.width: 1
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Text {
                        text: "󰅂"
                        color: Theme.colPurpleGlow
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item {
                        width: parent.width - 36
                        height: parent.height
                        TextInput {
                            id: chatInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            focus: true
                            color: Theme.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            selectByMouse: true
                            selectionColor: Theme.colPurple
                            selectedTextColor: Theme.colFg
                            clip: true
                            Keys.onEscapePressed: {
                                if (Ask.busy) Ask.cancel()
                                else Ask.close()
                            }
                            Keys.onReturnPressed: {
                                Ask.send(chatInput.text)
                                chatInput.text = ""
                            }
                            Keys.onEnterPressed: {
                                Ask.send(chatInput.text)
                                chatInput.text = ""
                            }
                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_M) {
                                    Ask.cycleModel(1)
                                    event.accepted = true
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: chatInput.text === ""
                            text: "Continue the conversation..."
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
