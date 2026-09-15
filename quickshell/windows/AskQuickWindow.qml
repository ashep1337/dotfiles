import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.components
import qs.services

// Compact view of the latest exchange in the shared Codex conversation.
FloatingWindow {
    id: quickWindow
    title: "Ask Codex"
    visible: Ask.open && !Ask.chat

    // The body (question + answer) is measured at a fixed width, so its
    // height never depends on the window height — no binding loop.
    readonly property int baseHeight: 108
    readonly property bool hasBody: Ask.lastQuestion !== "" || Ask.errorText !== "" || Ask.requests.length > 0
    readonly property int bodyHeight: hasBody
        ? Math.max(60, Math.min(quickBody.implicitHeight + 12, 560)) : 0
    readonly property int targetHeight: baseHeight + bodyHeight

    implicitWidth: 620
    implicitHeight: targetHeight
    // Pinning min and max to the target forces the compositor to honor the
    // resize; implicitHeight alone is only a suggestion.
    minimumSize: Qt.size(620, targetHeight)
    maximumSize: Qt.size(620, targetHeight)
    color: Theme.colPopupBg
    onVisibleChanged: if (visible) quickInput.forceActiveFocus()

    // ── Click-outside dismissal ──────────────────────────────────────
    // Focus-follows-mouse rules out closing on focus loss: the pointer merely
    // crossing the border would count. A compositor-side grab clears on a
    // button press outside the window instead, so drifting the mouse away
    // leaves the window alone. That first click outside is spent on the
    // dismissal and does not reach whatever was under it.
    HyprlandFocusGrab {
        active: quickWindow.visible
        windows: [quickWindow]
        // Hyprland clears the grab when we drop it too — after the window is
        // already hidden — so re-check before acting on it.
        onCleared: if (quickWindow.visible) Ask.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                Text {
                    text: "󰭹  Ask"
                    color: Theme.colPurpleGlow
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    AskModelPicker { anchors.verticalCenter: parent.verticalCenter }
                    AskModeSwitch { anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                width: parent.width
                height: 38
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
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item {
                        width: parent.width - 36
                        height: parent.height
                        TextInput {
                            id: quickInput
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
                            Keys.onTabPressed: Ask.setMode(true)
                            Keys.onReturnPressed: {
                                if (Ask.send(quickInput.text)) quickInput.text = ""
                            }
                            Keys.onEnterPressed: {
                                if (Ask.send(quickInput.text)) quickInput.text = ""
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
                            visible: quickInput.text === ""
                            text: {
                                if (Ask.busy) return Ask.statusText
                                return "Ask Codex… (tab opens conversation)"
                            }
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }

            // ── Question + answer ────────────────────────────────────
            Flickable {
                id: quickFlick
                width: parent.width
                height: quickWindow.bodyHeight
                visible: quickWindow.hasBody
                clip: true
                contentHeight: quickBody.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: quickBody
                    width: quickFlick.width
                    spacing: 6
                    Text {
                        visible: Ask.lastQuestion !== ""
                        width: parent.width
                        text: "› " + Ask.lastQuestion
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                    // One compact row per tool, so a quick question that ends
                    // up running something still shows what it did.
                    Repeater {
                        model: Ask.transcript.slice(Ask.latestTurnStart).filter(function(e) { return e.kind === "tool" })
                        ToolCallCard {
                            required property var modelData
                            visible: modelData.kind === "tool"
                            width: quickBody.width
                            entry: modelData
                        }
                    }
                    // TextEdit rather than Text so the reply can be selected
                    // and copied with the mouse.
                    TextEdit {
                        id: quickAnswer
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        selectionColor: Theme.colPurple
                        selectedTextColor: Theme.colFg
                        text: Ask.lastAnswer !== "" ? Ask.lastAnswer : (Ask.busy ? "…" : "")
                        color: Ask.lastAnswer !== "" ? Theme.colFg : Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                    }
                    TextEdit {
                        visible: Ask.errorText !== ""
                        width: parent.width
                        text: Ask.errorText
                        textFormat: TextEdit.PlainText
                        readOnly: true
                        selectByMouse: true
                        color: Theme.colRed
                        wrapMode: TextEdit.Wrap
                    }
                    Repeater {
                        model: Ask.requests
                        AskRequestCard {
                            required property var modelData
                            width: quickBody.width
                            request: modelData
                        }
                    }
                }
            }
        }
    }
}
