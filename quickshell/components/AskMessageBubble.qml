import QtQuick
import qs
import qs.services

// A Codex transcript message. User prompts and agent responses deliberately
// use different alignment, surface color, and labels for quick visual parsing.
Item {
    id: bubble

    property string role: "codex"
    property string text: ""
    readonly property bool outgoing: bubble.role === "you"
    readonly property real maxBubbleWidth: bubble.width * (bubble.outgoing ? 0.76 : 0.88)

    implicitHeight: card.height + 4

    Rectangle {
        id: card
        anchors.right: bubble.outgoing ? parent.right : undefined
        anchors.left: bubble.outgoing ? undefined : parent.left
        width: Math.min(bubble.maxBubbleWidth,
                        Math.max(bubble.outgoing ? 140 : 220, bodyMetrics.width + 32))
        height: content.implicitHeight + 22
        radius: 8
        color: bubble.outgoing ? Theme.colPurple : Theme.colPopupInset
        border.color: bubble.outgoing ? Theme.colPurpleGlow : "#292538"
        border.width: 1

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 11
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 6

            Text {
                text: bubble.outgoing ? "YOU" : "CODEX"
                color: bubble.outgoing ? "#c9a7ff" : Theme.colPurpleGlow
                font.family: Theme.askFontFamily
                font.pixelSize: Math.max(9, Ask.chatFontSize - 5)
                font.bold: true
                font.letterSpacing: 0.8
            }

            TextEdit {
                width: parent.width
                text: bubble.text
                color: Theme.colFg
                font.family: Theme.askFontFamily
                font.pixelSize: Ask.chatFontSize
                font.letterSpacing: 0
                readOnly: true
                selectByMouse: true
                selectionColor: Theme.colPurpleGlow
                selectedTextColor: Theme.colFg
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
            }
        }
    }

    TextMetrics {
        id: bodyMetrics
        font.family: Theme.askFontFamily
        font.pixelSize: Ask.chatFontSize
        text: bubble.text.indexOf("\n") >= 0 ? new Array(120).join("M") : bubble.text
    }
}
