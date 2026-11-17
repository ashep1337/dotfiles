import Quickshell
import QtQuick
import qs
import qs.components
import qs.services

// Full Codex workspace: persisted threads on the left, active conversation on
// the right, and tail-following that disengages as soon as the user scrolls up.
FloatingWindow {
    id: chatWindow
    title: "Codex Chat"
    visible: Ask.open && Ask.chat
    implicitWidth: 1120
    implicitHeight: 720
    color: Theme.colPopupBg
    function submitMessage() {
        if (Ask.send(chatInput.text)) {
            chatInput.text = ""
            chatList.scrollToLatest()
        }
    }
    onVisibleChanged: {
        if (visible) {
            chatInput.forceActiveFocus()
            Qt.callLater(function() { chatList.scrollToLatest() })
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth

        Row {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth

            Rectangle {
                id: sidebar
                width: 246
                height: parent.height
                color: "#09080d"

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Row {
                        width: parent.width
                        height: 30
                        spacing: 8
                        Text {
                            text: "󰭹"
                            color: Theme.colPurpleGlow
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "CODEX"
                            color: Theme.colFg
                            font.family: Theme.askFontFamily
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 1.2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 6
                        color: newMa.containsMouse ? Theme.colHover : Theme.colPopupInset
                        border.color: Theme.colPurpleBorder
                        border.width: 1
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "+"
                                color: Theme.colPurpleGlow
                                font.family: Theme.askFontFamily
                                font.pixelSize: 18
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "New conversation"
                                color: Theme.colFg
                                font.family: Theme.askFontFamily
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: newMa
                            anchors.fill: parent
                            enabled: !Ask.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ask.newSession()
                        }
                    }

                    Text {
                        text: "HISTORY"
                        color: Theme.colFgDim
                        font.family: Theme.askFontFamily
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    ListView {
                        id: historyList
                        width: parent.width
                        height: parent.height - 106
                        clip: true
                        spacing: 4
                        model: Ask.history
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: historyRow
                            required property var modelData
                            width: historyList.width
                            height: 54
                            radius: 6
                            readonly property bool selected: Ask.session === modelData.id
                            color: selected ? Theme.colPopupHover
                                  : (historyMa.containsMouse ? "#16121e" : "transparent")
                            border.color: selected ? Theme.colPurpleBorder : "transparent"
                            border.width: 1
                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 3
                                Text {
                                    width: parent.width
                                    text: historyRow.modelData.name || historyRow.modelData.preview || "Untitled conversation"
                                    color: historyRow.selected ? Theme.colFg : "#bbb8ca"
                                    font.family: Theme.askFontFamily
                                    font.pixelSize: 11
                                    font.bold: historyRow.selected
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: {
                                        var stamp = historyRow.modelData.updatedAt || 0
                                        if (!stamp) return historyRow.modelData.cwd || ""
                                        return Qt.formatDateTime(new Date(stamp * 1000), "MMM d · h:mm AP")
                                    }
                                    color: Theme.colFgDim
                                    font.family: Theme.askFontFamily
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
                                }
                            }
                            MouseArea {
                                id: historyMa
                                anchors.fill: parent
                                enabled: !Ask.busy
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ask.openSession(historyRow.modelData.id)
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: historyList.count === 0
                            text: Ask.historyLoading ? "Loading…" : "No conversations yet"
                            color: Theme.colFgDim
                            font.family: Theme.askFontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle { width: 1; height: parent.height; color: Theme.colPurpleBorder; opacity: 0.75 }

            Item {
                id: workspace
                width: parent.width - sidebar.width - 1
                height: parent.height
                Column {
                    anchors.fill: parent

                    Item {
                        id: toolbar
                        width: parent.width
                        height: 52
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: Ask.session ? "Workspace chat" : "New conversation"
                                color: Theme.colFg
                                font.family: Theme.askFontFamily
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: Ask.workingDirectory
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            AskModelPicker { anchors.verticalCenter: parent.verticalCenter }
                            AskModeSwitch { anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: 78
                                height: 26
                                radius: 6
                                color: Theme.colPopupInset
                                border.color: Theme.colPurpleBorder
                                border.width: 1
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Text {
                                        text: "−"
                                        color: fontDown.containsMouse ? Theme.colPurpleGlow : Theme.colFgDim
                                        font.family: Theme.askFontFamily
                                        font.pixelSize: 17
                                        MouseArea {
                                            id: fontDown
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Ask.adjustChatFont(-1)
                                        }
                                    }
                                    Text {
                                        text: Ask.chatFontSize
                                        color: Theme.colFg
                                        font.family: Theme.askFontFamily
                                        font.pixelSize: 10
                                    }
                                    Text {
                                        text: "+"
                                        color: fontUp.containsMouse ? Theme.colPurpleGlow : Theme.colFgDim
                                        font.family: Theme.askFontFamily
                                        font.pixelSize: 16
                                        MouseArea {
                                            id: fontUp
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Ask.adjustChatFont(1)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#241b31" }

                    Item {
                        width: parent.width
                        height: parent.height - toolbar.height - composer.height - statusArea.height - 1
                        ListView {
                            id: chatList
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            anchors.topMargin: 14
                            anchors.bottomMargin: 10
                            clip: true
                            spacing: 12
                            model: Ask.transcript
                            boundsBehavior: Flickable.StopAtBounds
                            property bool followTail: true

                            function scrollToLatest() {
                                followTail = true
                                positionViewAtEnd()
                            }

                            onMovementStarted: followTail = false
                            onMovementEnded: followTail = atYEnd
                            onCountChanged: {
                                if (followTail) Qt.callLater(function() { chatList.positionViewAtEnd() })
                            }
                            Connections {
                                target: Ask
                                function onStreamTextChanged() {
                                    if (chatList.followTail)
                                        Qt.callLater(function() { chatList.positionViewAtEnd() })
                                }
                                function onRequestsChanged() {
                                    if (chatList.followTail)
                                        Qt.callLater(function() { chatList.positionViewAtEnd() })
                                }
                                function onTranscriptChanged() {
                                    if (chatList.followTail)
                                        Qt.callLater(function() { chatList.positionViewAtEnd() })
                                }
                                function onSessionChanged() {
                                    chatList.followTail = true
                                    Qt.callLater(function() { chatList.positionViewAtEnd() })
                                }
                            }
                            delegate: Item {
                                id: entry
                                required property var modelData
                                width: chatList.width
                                height: entry.modelData.kind === "text"
                                      ? messageBubble.implicitHeight : toolCard.height
                                AskMessageBubble {
                                    id: messageBubble
                                    visible: entry.modelData.kind === "text"
                                    width: parent.width
                                    role: entry.modelData.role || "codex"
                                    text: entry.modelData.text || ""
                                }
                                ToolCallCard {
                                    id: toolCard
                                    visible: entry.modelData.kind === "tool"
                                    width: Math.min(parent.width * 0.9, 760)
                                    entry: entry.modelData
                                }
                            }
                            footer: Column {
                                width: chatList.width
                                spacing: 10
                                topPadding: visible ? 12 : 0
                                visible: Ask.streamText !== "" || Ask.requests.length > 0
                                AskMessageBubble {
                                    visible: Ask.streamText !== ""
                                    width: chatList.width
                                    role: "codex"
                                    text: Ask.streamText
                                }
                                Repeater {
                                    model: Ask.requests
                                    AskRequestCard {
                                        required property var modelData
                                        width: Math.min(chatList.width * 0.9, 760)
                                        request: modelData
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            visible: Ask.transcript.length === 0 && Ask.streamText === ""
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "What are we building?"
                                color: Theme.colFg
                                font.family: Theme.askFontFamily
                                font.pixelSize: Ask.chatFontSize + 3
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Start a conversation with Codex"
                                color: Theme.colFgDim
                                font.family: Theme.askFontFamily
                                font.pixelSize: Ask.chatFontSize - 3
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            width: latestText.implicitWidth + 28
                            height: 30
                            radius: 15
                            visible: !chatList.followTail
                            color: Theme.colPurple
                            border.color: Theme.colPurpleGlow
                            border.width: 1
                            Text {
                                id: latestText
                                anchors.centerIn: parent
                                text: "↓  Jump to latest"
                                color: Theme.colFg
                                font.family: Theme.askFontFamily
                                font.pixelSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chatList.scrollToLatest()
                            }
                        }
                    }

                    Item {
                        id: statusArea
                        width: parent.width
                        height: chatStatus.visible ? Math.min(48, chatStatus.implicitHeight + 10) : 0
                        Text {
                            id: chatStatus
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 22
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Ask.busy || Ask.errorText !== "" || Ask.lastDurationMs > 0
                            text: Ask.errorText !== "" ? Ask.errorText : Ask.statusText
                            textFormat: Text.PlainText
                            color: Ask.errorText !== "" ? Theme.colRed : Theme.colFgDim
                            font.family: Theme.askFontFamily
                            font.pixelSize: Math.max(9, Ask.chatFontSize - 5)
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: composer
                        width: parent.width
                        height: 72
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            height: 52
                            radius: 8
                            color: Theme.colPopupInset
                            border.color: chatInput.activeFocus ? Theme.colPurpleGlow : Theme.colPurpleBorder
                            border.width: 1
                            TextInput {
                                id: chatInput
                                anchors.left: parent.left
                                anchors.right: sendIcon.left
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                focus: true
                                color: Theme.colFg
                                font.family: Theme.askFontFamily
                                font.pixelSize: Ask.chatFontSize
                                selectByMouse: true
                                selectionColor: Theme.colPurple
                                selectedTextColor: Theme.colFg
                                clip: true
                                Keys.onEscapePressed: {
                                    if (Ask.busy) Ask.cancel()
                                    else Ask.close()
                                }
                                Keys.onReturnPressed: {
                                    chatWindow.submitMessage()
                                }
                                Keys.onEnterPressed: {
                                    chatWindow.submitMessage()
                                }
                                Keys.onPressed: event => {
                                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_M) {
                                        Ask.cycleModel(1)
                                        event.accepted = true
                                    }
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chatInput.text === ""
                                text: "Message Codex…"
                                color: Theme.colFgDim
                                font.family: Theme.askFontFamily
                                font.pixelSize: Ask.chatFontSize
                            }
                            Text {
                                id: sendIcon
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: Ask.busy ? "󰜺" : "󰒊"
                                color: Ask.busy ? Theme.colFgDim : Theme.colPurpleGlow
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    enabled: !Ask.busy && chatInput.text.trim() !== ""
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chatWindow.submitMessage()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
