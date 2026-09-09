import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.components
import qs.services

// The Signal client: conversations on the left, the open thread on the right.
// All state lives in the Signal service, so closing this window only hides it —
// messages keep arriving and the bar badge keeps counting.
FloatingWindow {
    id: win
    title: "Signal"
    visible: Signal.open
    implicitWidth: 1020
    implicitHeight: 680
    color: Theme.colPopupBg

    // ── Click-outside dismissal ──────────────────────────────────────
    // Focus-follows-mouse rules out closing on focus loss: the pointer merely
    // crossing the border would count. A compositor-side grab clears on a
    // button press outside the window instead, so drifting the mouse away
    // leaves the window alone. That first click outside is spent on the
    // dismissal and does not reach whatever was under it.
    HyprlandFocusGrab {
        active: win.visible
        windows: [win]
        // Hyprland clears the grab when we drop it too — after the window is
        // already hidden — so re-check before acting on it.
        onCleared: if (win.visible) Signal.close()
    }

    // Showing the window can run before the composer below it exists, so the
    // focus call waits for the rest of the tree.
    onVisibleChanged: {
        if (!win.visible) return
        Qt.callLater(win.focusComposer)
        if (Signal.activeId === "") return
        Signal.markRead(Signal.activeId)
        Signal.rebuildThread()   // lands the view on the newest message
    }

    function focusComposer() {
        if (composer) composer.forceActiveFocus()
    }

    // Picking a conversation — from the list, from IPC — puts the cursor in
    // the composer, which is the only thing anyone wants to do next.
    Connections {
        target: Signal
        function onActiveIdChanged() {
            if (win.visible) Qt.callLater(win.focusComposer)
        }
    }

    // Conversations, plus — once the user starts typing — anyone in the address
    // book they have not spoken to yet.
    readonly property var sidebarItems: {
        var f = Signal.filter.trim().toLowerCase()
        var out = []
        var seen = ({})
        for (var i = 0; i < Signal.convs.length; i++) {
            var c = Signal.convs[i]
            if (f !== "" && c.name.toLowerCase().indexOf(f) < 0
                         && (c.lastText || "").toLowerCase().indexOf(f) < 0) continue
            out.push(c)
            seen[c.id] = true
        }
        if (f === "") return out
        var pools = [Signal.contacts, Signal.groups]
        for (var p = 0; p < pools.length; p++) {
            for (var j = 0; j < pools[p].length; j++) {
                var e = pools[p][j]
                if (seen[e.id]) continue
                if (e.name.toLowerCase().indexOf(f) < 0
                    && (e.number || "").indexOf(f) < 0) continue
                out.push({ "id": e.id, "kind": e.kind, "number": e.number,
                           "groupId": e.groupId, "name": e.name, "lastTs": 0,
                           "lastText": "", "unread": 0, "typing": false })
            }
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth

        Row {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            spacing: 0

            // ═══════════════════════════════════════════════════════════
            //  LEFT: conversations
            // ═══════════════════════════════════════════════════════════
            Item {
                id: sidebar
                width: 300
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            text: "󰍡  Signal"
                            color: Theme.colPurpleGlow
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.chatFontSize + 1
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 150; height: 1 }
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Signal.status === "online" ? Theme.colGreen
                                 : (Signal.status === "connecting" ? "#f59e0b" : Theme.colRed)
                        }
                        Text {
                            text: Signal.status
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.chatFontSize - 3
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Signal.reconnect()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: Theme.widgetRadius
                        color: Theme.colPopupInset
                        border.color: searchInput.activeFocus ? Theme.colPurpleGlow
                                                              : Theme.colPurpleBorder
                        border.width: 1
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            spacing: 6
                            Text {
                                text: "󰍉"
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize - 1
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Item {
                                width: parent.width - 28
                                height: parent.height
                                TextInput {
                                    id: searchInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    text: Signal.filter
                                    color: Theme.colFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.chatFontSize - 1
                                    selectByMouse: true
                                    selectionColor: Theme.colPurple
                                    clip: true
                                    onTextChanged: Signal.filter = text
                                    Keys.onEscapePressed: {
                                        if (Signal.filter !== "") Signal.filter = ""
                                        else Signal.close()
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: searchInput.text === ""
                                    text: "Search or start a chat"
                                    color: Theme.colFgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.chatFontSize - 1
                                }
                            }
                        }
                    }

                    ListView {
                        id: convList
                        width: parent.width
                        height: parent.height - 88
                        clip: true
                        spacing: 2
                        model: win.sidebarItems
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: convRow
                            required property var modelData
                            width: convList.width
                            height: 58
                            radius: 8
                            color: Signal.activeId === convRow.modelData.id
                                   ? Theme.colHover
                                   : (convMa.containsMouse ? Theme.colPopupHover : "transparent")

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 9

                                Avatar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: convRow.modelData.name
                                    key: convRow.modelData.id
                                    group: convRow.modelData.kind === "group"
                                    size: 34
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 43
                                    spacing: 2
                                    Row {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: convRow.modelData.name
                                            color: Theme.colFg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.chatFontSize - 1
                                            font.bold: convRow.modelData.unread > 0
                                            width: parent.width - 52
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: convRow.modelData.lastTs > 0
                                                  ? win.shortTime(convRow.modelData.lastTs) : ""
                                            color: Theme.colFgDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.chatFontSize - 4
                                            width: 46
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: convRow.modelData.typing
                                                  ? "typing…"
                                                  : (convRow.modelData.lastText !== ""
                                                     ? convRow.modelData.lastText
                                                     : "No messages yet")
                                            color: convRow.modelData.typing
                                                   ? Theme.colGreen : Theme.colFgDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.chatFontSize - 3
                                            font.italic: convRow.modelData.lastText === ""
                                                         && !convRow.modelData.typing
                                            width: parent.width - (convRow.modelData.unread > 0 ? 30 : 0)
                                            elide: Text.ElideRight
                                        }
                                        Rectangle {
                                            visible: convRow.modelData.unread > 0
                                            width: Math.max(18, badge.implicitWidth + 8)
                                            height: 16
                                            radius: 8
                                            color: Theme.colPurpleGlow
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                id: badge
                                                anchors.centerIn: parent
                                                text: convRow.modelData.unread
                                                color: "#ffffff"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.chatFontSize - 4
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: convMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // A search hit that isn't a conversation yet
                                    // becomes one on click.
                                    Signal.openContact(convRow.modelData)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: Theme.colPurpleBorder
                opacity: 0.4
            }

            // ═══════════════════════════════════════════════════════════
            //  RIGHT: the open thread
            // ═══════════════════════════════════════════════════════════
            Item {
                id: threadPane
                width: parent.width - sidebar.width - 1
                height: parent.height

                // Nothing selected — also what a first run looks like.
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: Signal.activeId === ""
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰍡"
                        color: Theme.colPurpleBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 48
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Signal.convs.length > 0
                              ? "Pick a conversation"
                              : "Search for a contact to start a chat"
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.chatFontSize - 1
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Signal.errorText !== ""
                        text: Signal.errorText
                        color: Theme.colRed
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.chatFontSize - 3
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    visible: Signal.activeId !== ""

                    // ── Thread header ──────────────────────────────────
                    Row {
                        width: parent.width
                        height: 38
                        spacing: 10
                        Avatar {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Signal.activeConv ? Signal.activeConv.name : ""
                            key: Signal.activeId
                            group: Signal.activeConv && Signal.activeConv.kind === "group"
                            size: 32
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: Signal.activeConv ? Signal.activeConv.name : ""
                                color: Theme.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize
                                font.bold: true
                            }
                            Text {
                                text: {
                                    if (!Signal.activeConv) return ""
                                    if (Signal.activeConv.typing) return "typing…"
                                    if (Signal.activeConv.kind === "group") return "group"
                                    return Signal.activeConv.number
                                }
                                color: Signal.activeConv && Signal.activeConv.typing
                                       ? Theme.colGreen : Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize - 3
                            }
                        }
                    }

                    Divider { width: parent.width }

                    // ── Messages ───────────────────────────────────────
                    ListView {
                        id: threadList
                        width: parent.width
                        height: parent.height - 116
                        clip: true
                        spacing: 8
                        model: Signal.thread
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 400

                        // Follow the tail, but only when already there — reading
                        // back through history shouldn't get yanked away.
                        property bool atTail: true
                        onContentYChanged: threadList.atTail =
                            (contentHeight - (contentY + height)) < 80
                        // Refilling appends thousands of rows; callLater
                        // collapses that into one scroll.
                        onCountChanged: if (threadList.atTail)
                            Qt.callLater(threadList.positionViewAtEnd)
                        Component.onCompleted: threadList.toBottom()

                        // A long thread's height is only an estimate until its
                        // delegates are built, so one jump to the end lands
                        // short. Hold the view at the end until the height stops
                        // changing — or until the user scrolls, which wins.
                        property bool pinning: false
                        onContentHeightChanged: if (threadList.pinning)
                            Qt.callLater(threadList.positionViewAtEnd)
                        onMovementStarted: threadList.pinning = false

                        function toBottom() {
                            threadList.atTail = true
                            threadList.pinning = true
                            threadList.positionViewAtEnd()
                            pinTimeout.restart()
                        }

                        Timer {
                            id: pinTimeout
                            interval: 1500
                            onTriggered: threadList.pinning = false
                        }

                        Connections {
                            target: Signal
                            function onThreadReloaded() { threadList.toBottom() }
                        }

                        section.property: "day"
                        section.criteria: ViewSection.FullString
                        section.delegate: Item {
                            required property string section
                            width: threadList.width
                            height: 24
                            Text {
                                anchors.centerIn: parent
                                text: parent.section
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize - 4
                            }
                        }

                        delegate: ChatBubble {
                            id: msg
                            required property var model
                            width: threadList.width
                            ts: msg.model.ts
                            text: msg.model.text
                            outgoing: msg.model.outgoing
                            senderName: msg.model.senderName
                            showSender: Signal.activeConv
                                        && Signal.activeConv.kind === "group"
                            pending: msg.model.pending
                            failed: msg.model.failed
                            delivered: msg.model.delivered
                            wasRead: msg.model.read
                            deleted: msg.model.deleted
                            quoteAuthor: msg.model.quoteAuthor
                            quoteText: msg.model.quoteText
                            atts: JSON.parse(msg.model.attsJson)
                            reactions: JSON.parse(msg.model.reactionsJson)
                            onReactRequested: emoji => Signal.sendReaction(
                                msg.model.ts, msg.model.sender, emoji, false)
                        }
                    }

                    Text {
                        visible: Signal.errorText !== ""
                        width: parent.width
                        text: Signal.errorText
                        color: Theme.colRed
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.chatFontSize - 3
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    // ── Composer ───────────────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: Theme.widgetRadius
                        color: Theme.colPopupInset
                        border.color: composer.activeFocus ? Theme.colPurpleGlow
                                                           : Theme.colPurpleBorder
                        border.width: 1
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Item {
                                width: parent.width - 40
                                height: parent.height
                                TextInput {
                                    id: composer
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    focus: true
                                    color: Theme.colFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.chatFontSize
                                    selectByMouse: true
                                    selectionColor: Theme.colPurple
                                    selectedTextColor: Theme.colFg
                                    clip: true
                                    enabled: Signal.online

                                    function submit() {
                                        if (composer.text.trim() === "") return
                                        Signal.sendText(composer.text)
                                        composer.text = ""
                                        typingTimer.stop()
                                        Signal.sendTyping(true)
                                    }
                                    Keys.onReturnPressed: composer.submit()
                                    Keys.onEnterPressed: composer.submit()
                                    Keys.onEscapePressed: Signal.close()
                                    onTextChanged: {
                                        if (composer.text === "") return
                                        // One STARTED per burst of typing, and a
                                        // STOPPED once the burst ends.
                                        if (!typingTimer.running) Signal.sendTyping(false)
                                        typingTimer.restart()
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: composer.text === ""
                                    text: Signal.online ? "Message…" : "Connecting to signal-cli…"
                                    color: Theme.colFgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.chatFontSize
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰊴"
                                color: composer.text.trim() !== "" ? Theme.colPurpleGlow
                                                                   : Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize + 2
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: composer.submit()
                                }
                            }
                        }
                    }
                }

                Timer {
                    id: typingTimer
                    interval: 4000
                    onTriggered: Signal.sendTyping(true)
                }
            }
        }
    }

    // Times in the sidebar are relative to today the way a phone shows them.
    function shortTime(ts) {
        var d = new Date(ts)
        var now = new Date()
        if (d.toDateString() === now.toDateString()) return Qt.formatDateTime(d, "h:mm AP")
        var days = (now.getTime() - ts) / 86400000
        if (days < 7) return Qt.formatDateTime(d, "ddd")
        return Qt.formatDateTime(d, "M/d")
    }
}
