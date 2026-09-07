import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root

    visible: true

    title: "Clipboard"

    width: 700
    height: 750

    minimumWidth: 400
    minimumHeight: 300

    color: "transparent"

    property color accent: "#8700ff"
    property color bg: "#121212"
    property color bgAlt: "#1a1a1a"
    property color fg: "#f0f0f0"

    property var clipboardEntries: []

    function refreshClipboard() {
        listProc.running = true
    }

    function pasteItem(item) {
        pasteProc.command = [
            "bash",
            "-c",
            `printf '%s' '${item.replace(/'/g,"'\\''")}' | cliphist decode | wl-copy`
        ]

        pasteProc.running = true
        root.close()
}

    Timer {
        id: pollTimer
        interval: 1000   // check every second
        repeat: true
        running: root.visible
        onTriggered: refreshClipboard()
}
    Process {
        id: listProc
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text)
                    return

                root.clipboardEntries =
                    text
                        .trim()
                        .split("\n")
                        .filter(Boolean)
            }
        }
    }

    Process {
        id: pasteProc
    }

    Rectangle {
        anchors.fill: parent

        radius: 16

        color: root.bg

        border {
            width: 2
            color: root.accent
        }

        ColumnLayout {

            anchors.fill: parent
            anchors.margins: 18

            spacing: 12

            Text {
                text: "Clipboard"

                color: root.accent

                font.pixelSize: 26
                font.bold: true
            }

            TextField {
                id: search

                Layout.fillWidth: true

                placeholderText:
                    "Search history..."

                color: root.fg

                background: Rectangle {
                    radius: 10

                    color: root.bgAlt

                    border {
                        width: 1

                        color:
                            search.activeFocus
                            ? root.accent
                            : "#333"
                    }
                }
            }

            ListView {

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true

                spacing: 8

                model:
                    root.clipboardEntries.filter(
                        x =>
                            x.toLowerCase()
                            .includes(
                                search.text
                                .toLowerCase()
                            )
                    )

                delegate: Rectangle {

                    width:
                        ListView.view.width

                    height: 58

                    radius: 10

                    color:
                        mouse.containsMouse
                        ? "#2a1140"
                        : root.bgAlt

                    border {
                        width:
                            mouse.containsMouse
                            ? 1
                            : 0

                        color:
                            root.accent
                    }

                    Text {

                        anchors.fill:
                            parent

                        anchors.margins:
                            14

                        color:
                            root.fg

                        elide:
                            Text.ElideRight

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            modelData
                    }

                    MouseArea {

                        id: mouse

                        anchors.fill:
                            parent

                        hoverEnabled:
                            true

                        onClicked:
                            root.pasteItem(
                                modelData
                            )
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refreshClipboard()
        search.forceActiveFocus()
    }
}
