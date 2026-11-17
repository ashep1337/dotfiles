import QtQuick
import qs
import qs.services

// One tool call in the transcript: name, arguments, and the result once it
// lands. Collapsed by default — tool output is often long and is rarely what
// you are reading the transcript for.
Rectangle {
    id: card

    // A transcript entry with kind === "tool"
    property var entry: null
    property bool expanded: false

    readonly property string toolName: card.entry ? (card.entry.tool || "tool") : ""
    readonly property bool pending: card.entry ? !card.entry.done : false
    readonly property bool failed: card.entry ? card.entry.isError === true : false

    height: cardCol.implicitHeight + 16
    radius: 8
    color: "#0d0c12"
    border.color: card.failed ? Theme.colRed : Theme.colPurpleBorder
    border.width: 1

    Column {
        id: cardCol
        x: 10
        y: 8
        width: parent.width - 20
        spacing: 6

        Row {
            width: parent.width
            spacing: 8
            Text {
                text: card.pending ? "󰔟" : (card.failed ? "󰅚" : "󰄬")
                color: card.pending ? Theme.colFgDim
                     : (card.failed ? Theme.colRed : Theme.colGreen)
                font.family: Theme.fontFamily
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: card.toolName === "Command" ? "$" : card.toolName
                color: card.toolName === "Command" ? Theme.colGreen : Theme.colPurpleGlow
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Ask.chatFontSize - 3)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                // The arguments, on one line, until the card is opened
                width: parent.width - 150
                text: card.entry ? (card.entry.input || "") : ""
                color: Theme.colFgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Ask.chatFontSize - 4)
                elide: Text.ElideRight
                visible: !card.expanded
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: 1; height: 1 }
        }

        // Full arguments and output, once opened
        TextEdit {
            visible: card.expanded
            width: parent.width
            text: (card.entry ? (card.entry.input || "") : "")
                  + ((card.entry && card.entry.result) ? ("\n\n" + card.entry.result) : "")
            color: card.failed ? Theme.colRed : Theme.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Ask.chatFontSize - 4)
            readOnly: true
            selectByMouse: true
            selectionColor: Theme.colPurple
            selectedTextColor: Theme.colFg
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
        }
    }

    MouseArea {
        anchors.fill: parent
        // Let the TextEdit take the pointer once the card is open, so output
        // can be selected and copied.
        enabled: !card.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: card.expanded = true
    }
    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22
        enabled: card.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: card.expanded = false
    }
}
