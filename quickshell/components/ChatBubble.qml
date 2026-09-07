import Quickshell
import QtQuick
import qs
import qs.services

// One message in a thread. Everything it needs is passed in rather than read
// off a model, so the delegate stays the only thing that knows about rows.
Item {
    id: bubble

    property real ts: 0
    property string text: ""
    property bool outgoing: false
    property string senderName: ""
    property bool showSender: false      // group threads name the sender
    property bool pending: false
    property bool failed: false
    property bool delivered: false
    property bool wasRead: false
    property bool deleted: false
    property string quoteAuthor: ""
    property string quoteText: ""
    property var atts: []
    property var reactions: []

    // Asks the thread to react on this message's behalf; the service knows
    // which conversation it belongs to.
    signal reactRequested(string emoji)

    implicitHeight: column.implicitHeight

    readonly property string timeLabel: bubble.ts > 0
        ? Qt.formatDateTime(new Date(bubble.ts), "h:mm AP") : ""

    // ── Bubble width ──────────────────────────────────────────────────
    // A bubble hugs its text, but the text is laid out inside the bubble, so
    // sizing one from the other is circular — QML resolves that by collapsing
    // the bubble to roughly one word per line. The text is measured instead,
    // which depends on nothing in the layout.
    readonly property real maxCard: bubble.width * 0.74
    readonly property real minCard: 112     // always fits "11:37 PM ✓✓"

    // Plenty of attachments arrive with no filename at all, so they are
    // named for what they are rather than shown as a bare paperclip.
    function attLabel(att) {
        if (att.name && att.name !== "") return att.name
        var type = att.type || ""
        if (type.indexOf("image/") === 0) return "Photo"
        if (type.indexOf("video/") === 0) return "Video"
        if (type.indexOf("audio/") === 0) return "Voice message"
        return "File"
    }
    // Nerd Font glyphs, not emoji: emoji come from a fallback font whose
    // advance width the metrics below cannot predict, which swallowed the
    // label in a narrow bubble.
    function attIcon(att) {
        var type = att.type || ""
        if (type.indexOf("image/") === 0) return "󰋩"
        if (type.indexOf("video/") === 0) return "󰕧"
        if (type.indexOf("audio/") === 0) return "󰎆"
        return "󰈔"
    }

    readonly property string longestAttName: {
        var longest = ""
        for (var i = 0; i < bubble.atts.length; i++) {
            var label = bubble.attIcon(bubble.atts[i]) + " "
                      + bubble.attLabel(bubble.atts[i])
            if (label.length > longest.length) longest = label
        }
        return longest
    }
    readonly property bool hasImage: {
        for (var i = 0; i < bubble.atts.length; i++) {
            var a = bubble.atts[i]
            if (a.path && (a.type || "").indexOf("image/") === 0) return true
        }
        return false
    }

    TextMetrics {
        id: bodyMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.chatFontSize
        text: bubble.deleted ? "This message was deleted" : bubble.text
    }
    TextMetrics {
        id: quoteMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.chatFontSize - 3
        text: bubble.quoteText
    }
    TextMetrics {
        id: attMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.chatFontSize - 3
        text: bubble.longestAttName
    }
    TextMetrics {
        id: senderMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.chatFontSize - 3
        font.bold: true
        text: (bubble.showSender && !bubble.outgoing) ? bubble.senderName : ""
    }

    readonly property real cardWidth: {
        // An image sets its own scale; give it the whole allowance.
        if (bubble.hasImage) return bubble.maxCard
        var w = Math.max(bodyMetrics.width, quoteMetrics.width,
                         attMetrics.width, senderMetrics.width)
        // Measuring ignores newlines, so anything multi-line lands at the cap,
        // which is where a long message belongs anyway.
        return Math.max(bubble.minCard, Math.min(bubble.maxCard, w + 24))
    }

    // Read beats delivered beats sent; failure outranks all of it.
    readonly property string statusLabel: {
        if (!bubble.outgoing) return ""
        if (bubble.failed) return "failed"
        if (bubble.pending) return "···"
        if (bubble.wasRead) return "✓✓"
        if (bubble.delivered) return "✓✓"
        return "✓"
    }

    Column {
        id: column
        width: parent.width
        spacing: 2

        Item {
            width: parent.width
            height: card.height

            Rectangle {
                id: card
                x: bubble.outgoing ? parent.width - width : 0
                width: bubble.cardWidth
                height: inner.implicitHeight + 16
                radius: 10
                color: bubble.outgoing ? Theme.colPurple : Theme.colPopupInset
                border.color: bubble.failed ? Theme.colRed
                            : (bubble.outgoing ? Theme.colPurpleGlow : Theme.colPurpleBorder)
                border.width: 1
                opacity: bubble.pending ? 0.65 : 1.0

                Column {
                    id: inner
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    spacing: 4

                    Text {
                        visible: bubble.showSender && !bubble.outgoing
                        text: bubble.senderName
                        color: Theme.colPurpleGlow
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.chatFontSize - 3
                        font.bold: true
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    // Replies quote what they answer; without it the thread
                    // reads as a non-sequitur.
                    Rectangle {
                        visible: bubble.quoteText !== "" || bubble.quoteAuthor !== ""
                        width: parent.width
                        height: quoteCol.implicitHeight + 8
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Rectangle {
                            width: 2
                            height: parent.height
                            color: Theme.colPurpleGlow
                        }
                        Column {
                            id: quoteCol
                            x: 8
                            y: 4
                            width: parent.width - 14
                            spacing: 1
                            Text {
                                text: bubble.quoteAuthor
                                color: Theme.colPurpleGlow
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize - 4
                                font.bold: true
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            Text {
                                text: bubble.quoteText
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize - 3
                                width: parent.width
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                            }
                        }
                    }

                    TextEdit {
                        visible: bubble.text !== "" || bubble.deleted
                        text: bubble.deleted ? "This message was deleted" : bubble.text
                        color: bubble.deleted ? Theme.colFgDim : Theme.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.chatFontSize
                        font.italic: bubble.deleted
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        selectionColor: Theme.colPurpleGlow
                        selectedTextColor: Theme.colFg
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                    }

                    // Attachments land on disk as signal-cli receives them, so
                    // images can be shown inline and anything else handed off.
                    Repeater {
                        model: bubble.atts
                        Column {
                            id: attCol
                            required property var modelData
                            // Sized from the card, not from the column holding
                            // it: a width chained through inner resolves to
                            // zero here, which silently ate the label.
                            width: bubble.cardWidth - 22
                            spacing: 2

                            readonly property bool isImage:
                                (attCol.modelData.type || "").indexOf("image/") === 0

                            Image {
                                visible: attCol.isImage && status === Image.Ready
                                source: attCol.modelData.path
                                        ? ("file://" + attCol.modelData.path) : ""
                                width: Math.min(implicitWidth, attCol.width)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize.height: 260
                            }
                            Text {
                                text: bubble.attIcon(attCol.modelData) + "  "
                                      + bubble.attLabel(attCol.modelData)
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.chatFontSize - 3
                                font.underline: attMa.containsMouse
                                width: parent.width
                                elide: Text.ElideRight
                                MouseArea {
                                    id: attMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !!attCol.modelData.path
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (attCol.modelData.path) {
                                            Quickshell.execDetached(["xdg-open",
                                                                     attCol.modelData.path])
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 5
                        Text {
                            text: bubble.timeLabel
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.chatFontSize - 4
                        }
                        Text {
                            visible: bubble.statusLabel !== ""
                            text: bubble.statusLabel
                            color: bubble.failed ? Theme.colRed
                                 : (bubble.wasRead ? Theme.colGreen : Theme.colFgDim)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.chatFontSize - 4
                        }
                    }
                }
            }

            // Quick reactions, revealed on hover on the free side of the bubble.
            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
            Row {
                visible: hoverArea.containsMouse || reactHover.containsMouse
                anchors.verticalCenter: card.verticalCenter
                x: bubble.outgoing ? 4 : card.width + 8
                spacing: 2
                MouseArea {
                    id: reactHover
                    width: reactRow.width
                    height: reactRow.height
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    Row {
                        id: reactRow
                        spacing: 1
                        Repeater {
                            model: ["👍", "❤️", "😂", "😮", "😢", "🙏"]
                            Rectangle {
                                id: emojiBtn
                                required property string modelData
                                width: 22
                                height: 22
                                radius: 11
                                color: emojiMa.containsMouse ? Theme.colHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: emojiBtn.modelData
                                    font.pixelSize: Theme.chatFontSize
                                }
                                MouseArea {
                                    id: emojiMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bubble.reactRequested(emojiBtn.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Reactions hang under the bubble on the same side it sits.
        Row {
            visible: bubble.reactions.length > 0
            anchors.right: bubble.outgoing ? parent.right : undefined
            spacing: 3
            Repeater {
                model: bubble.reactions
                Rectangle {
                    id: chip
                    required property var modelData
                    width: chipText.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Theme.colPopupInset
                    border.color: Theme.colPurpleBorder
                    border.width: 1
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.emoji
                        font.pixelSize: Theme.chatFontSize - 1
                    }
                }
            }
        }
    }
}
