import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────
    property color colPurple: "#37006c"
    property color colPurpleBorder: "#37006c"
    property color colPurpleGlow: "#5a1a9a"
    property color colFg: "#e0def4"
    property color colFgDim: "#908caa"
    property color colBarBg: "#000000"
    property color colWidgetBg: "#1a1a2e80"
    property color colHover: "#2a0050"
    property color colRed: "#f7768e"
    property color colGreen: "#a6e3a1"
    property color colPopupBg: "#1e1e2ef0"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14
    property int barHeight: 42
    property int widgetRadius: 8
    property int borderWidth: 2
    property int iconSize: 22

    // ── Shared state ──────────────────────────────────────────────────
    property string currentTime: ""
    property string currentDate: ""
    property string networkStatus: ""
    property string networkName: ""
    property int volumePercent: 0
    property bool volumeMuted: false
    property string activePopup: ""
    property var launcherItems: []

    function togglePopup(name) {
        if (root.activePopup === name) {
            root.activePopup = ""
        } else {
            root.activePopup = name
        }
    }

    // ── Load launchers from JSON ──────────────────────────────────────
    Process {
        id: launcherLoader
        command: ["cat", Qt.resolvedUrl("launchers.json").toString().replace("file://", "")]
        running: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    root.launcherItems = JSON.parse(data.trim())
                } catch (e) {
                    console.error("Failed to parse launchers.json:", e)
                }
            }
        }
    }

    // ── Network interfaces list ───────────────────────────────────────
    property var networkInterfaces: []

    Process {
        id: netListProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device | grep -v '^lo'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var parts = line.split(":")
                if (parts.length >= 4) {
                    var iface = {
                        "device": parts[0],
                        "type": parts[1],
                        "state": parts[2],
                        "connection": parts[3] || "—"
                    }
                    var current = root.networkInterfaces.slice()
                    current.push(iface)
                    root.networkInterfaces = current
                }
            }
        }
    }

    // ── Volume sinks list ─────────────────────────────────────────────
    property var audioSinks: []

    Process {
        id: sinkListProc
        command: ["sh", "-c", "wpctl status | awk '/Audio/,/Video/' | grep -E '│.*\\*?[0-9]+\\.' | sed 's/[│├└─]//g' | sed 's/^[ \\t]*//'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var isDefault = line.indexOf("*") >= 0
                var cleanLine = line.replace(/\*/g, "").trim()
                var sink = {
                    "name": cleanLine,
                    "isDefault": isDefault
                }
                var current = root.audioSinks.slice()
                current.push(sink)
                root.audioSinks = current
            }
        }
    }

    // ── Processes ─────────────────────────────────────────────────────

    Process {
        id: timeProc
        command: ["date", "+%I:%M %p"]
        running: true
        stdout: SplitParser {
            onRead: data => root.currentTime = data.trim()
        }
    }

    Process {
        id: dateProc
        command: ["date", "+%a, %b %d %Y"]
        running: true
        stdout: SplitParser {
            onRead: data => root.currentDate = data.trim()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeProc.running = true
            dateProc.running = true
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | grep -m1 connected || echo 'none:disconnected:None'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":")
                if (parts.length >= 3) {
                    root.networkName = parts[2] || "None"
                    root.networkStatus = parts[1] || "disconnected"
                } else {
                    root.networkName = "None"
                    root.networkStatus = "disconnected"
                }
            }
        }
    }

    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d %s\", $2*100, ($3==\"[MUTED]\"?\"muted\":\"unmuted\")}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                root.volumePercent = parseInt(parts[0]) || 0
                root.volumeMuted = (parts[1] === "muted")
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            netProc.running = true
            volProc.running = true
        }
    }

    onActivePopupChanged: {
        if (root.activePopup === "network") {
            root.networkInterfaces = []
            netListProc.running = true
        } else if (root.activePopup === "volume") {
            root.audioSinks = []
            sinkListProc.running = true
        }
    }

    // ── Shared processes ──────────────────────────────────────────────
    Process { id: rofiLaunch;    command: ["sh", "-c", "~/.config/rofi/launchers/misc/launcher.sh"] }
    Process { id: volToggleProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volUpProc;     command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"] }
    Process { id: volDownProc;   command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
    Process { id: lockProc;      command: ["hyprlock"] }
    Process { id: sleepProc;     command: ["systemctl", "suspend"] }
    Process { id: rebootProc;    command: ["systemctl", "reboot"] }
    Process { id: shutProc;      command: ["systemctl", "poweroff"] }

    // ── Bar on every screen ──────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: root.barHeight
            color: root.colBarBg

            // ── Click-outside overlay to dismiss popups ──────────────
            MouseArea {
                anchors.fill: parent
                enabled: root.activePopup !== ""
                z: 1
                onClicked: root.activePopup = ""
            }

            // ── Network popup ────────────────────────────────────────
            PopupWindow {
                id: networkPopup
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 420
                anchor.rect.y: 0
                implicitWidth: 240
                implicitHeight: netIfaceCol.implicitHeight + 24
                visible: root.activePopup === "network"
                color: "transparent"

                onVisibleChanged: {
                    if (!visible && root.activePopup === "network") {
                        root.activePopup = ""
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.widgetRadius + 2
                    color: root.colPopupBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Column {
                        id: netIfaceCol
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        width: parent.width - 16

                        Text {
                            text: "󰛳  Network Interfaces"
                            color: root.colPurpleGlow
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colPurpleBorder
                            opacity: 0.3
                        }

                        Repeater {
                            model: root.networkInterfaces

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: netIfaceCol.width
                                height: 38
                                radius: 6
                                color: "transparent"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.state === "connected" ? root.colGreen : root.colFgDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            text: modelData.device
                                            color: root.colFg
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            text: modelData.connection + " (" + modelData.type + ")"
                                            color: root.colFgDim
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.networkInterfaces.length === 0
                            text: "Scanning..."
                            color: root.colFgDim
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            topPadding: 8
                        }
                    }
                }
            }

            // ── Volume popup ─────────────────────────────────────────
            PopupWindow {
                id: volumePopup
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 310
                anchor.rect.y: 0
                implicitWidth: 220
                implicitHeight: volPopupCol.implicitHeight + 24
                visible: root.activePopup === "volume"
                color: "transparent"

                onVisibleChanged: {
                    if (!visible && root.activePopup === "volume") {
                        root.activePopup = ""
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.widgetRadius + 2
                    color: root.colPopupBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Column {
                        id: volPopupCol
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        width: parent.width - 16

                        Text {
                            text: "󰕾  Volume"
                            color: root.colPurpleGlow
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colPurpleBorder
                            opacity: 0.3
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 6
                                color: volDownMa.containsMouse ? root.colHover : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝞"
                                    color: root.colFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: volDownMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        volDownProc.running = true
                                        volProc.running = true
                                    }
                                }
                            }

                            Rectangle {
                                height: 8
                                width: parent.width - 100
                                radius: 4
                                color: root.colWidgetBg
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: parent.width * (root.volumePercent / 100)
                                    height: parent.height
                                    radius: 4
                                    color: root.volumeMuted ? root.colFgDim : root.colPurpleGlow
                                }
                            }

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 6
                                color: volUpMa.containsMouse ? root.colHover : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝝"
                                    color: root.colFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: volUpMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        volUpProc.running = true
                                        volProc.running = true
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 10

                            Text {
                                text: root.volumePercent + "%"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 18
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item { width: 10; height: 1 }

                            Rectangle {
                                width: muteBtnRow.implicitWidth + 16
                                height: 28
                                radius: 6
                                color: muteMa.containsMouse ? root.colHover : "transparent"
                                border.color: root.colPurpleBorder
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    id: muteBtnRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: root.volumeMuted ? "󰖁" : "󰕾"
                                        color: root.volumeMuted ? root.colRed : root.colFg
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: root.volumeMuted ? "Unmute" : "Mute"
                                        color: root.colFg
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: muteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        volToggleProc.running = true
                                        volProc.running = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colPurpleBorder
                            opacity: 0.3
                        }

                        Text {
                            text: "Output Devices"
                            color: root.colFgDim
                            font.family: root.fontFamily
                            font.pixelSize: 11
                        }

                        Repeater {
                            model: root.audioSinks

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: volPopupCol.width
                                height: 30
                                radius: 6
                                color: "transparent"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        text: modelData.isDefault ? "󰓃" : "󰓄"
                                        color: modelData.isDefault ? root.colPurpleGlow : root.colFgDim
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.name
                                        color: modelData.isDefault ? root.colFg : root.colFgDim
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        width: volPopupCol.width - 40
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.audioSinks.length === 0
                            text: "Scanning..."
                            color: root.colFgDim
                            font.family: root.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // ── Power popup ──────────────────────────────────────────
            PopupWindow {
                id: powerPopup
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 178
                anchor.rect.y: 0
                implicitWidth: 170
                implicitHeight: 184
                visible: root.activePopup === "power"
                color: "transparent"

                onVisibleChanged: {
                    if (!visible && root.activePopup === "power") {
                        root.activePopup = ""
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.widgetRadius + 2
                    color: root.colPopupBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width - 16

                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 6
                            color: lockMa.containsMouse ? root.colHover : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: ""
                                    color: root.colPurpleGlow
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Lock"
                                    color: root.colFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: lockMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activePopup = ""
                                    lockProc.running = true
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 6
                            color: sleepMa.containsMouse ? root.colHover : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: "󰤄"
                                    color: root.colPurpleGlow
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Sleep"
                                    color: root.colFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: sleepMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activePopup = ""
                                    sleepProc.running = true
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 6
                            color: rebootMa.containsMouse ? root.colHover : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: ""
                                    color: root.colPurpleGlow
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Reboot"
                                    color: root.colFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: rebootMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activePopup = ""
                                    rebootProc.running = true
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 6
                            color: shutMa.containsMouse ? root.colHover : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: "⏻"
                                    color: root.colRed
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Shutdown"
                                    color: root.colRed
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: shutMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activePopup = ""
                                    shutProc.running = true
                                }
                            }
                        }
                    }
                }
            }

            // ── Main bar layout ──────────────────────────────────────
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 6
                z: 2

                // ═════════════════════════════════════════════════════
                //  LEFT: Rofi (Arch logo) + Dynamic app launchers
                // ═════════════════════════════════════════════════════

                // Rofi launcher — Arch logo
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 34
                    radius: root.widgetRadius
                    color: rofiMa.containsMouse ? root.colHover : root.colWidgetBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Item {
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize

                        Image {
                            id: rofiIcon
                            anchors.fill: parent
                            source: "image://icon/archlinux-logo"
                            sourceSize.width: root.iconSize
                            sourceSize.height: root.iconSize
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰣇"
                            color: root.colPurpleGlow
                            font.family: root.fontFamily
                            font.pixelSize: 20
                            visible: rofiIcon.status !== Image.Ready
                        }
                    }

                    MouseArea {
                        id: rofiMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rofiLaunch.running = true
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    color: root.colPurpleBorder
                    opacity: 0.4
                }

                // ── Dynamic launcher buttons from launchers.json ─────
                Repeater {
                    model: root.launcherItems

                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: root.widgetRadius
                        color: launcherMa.containsMouse ? root.colHover : "transparent"
                        border.width: 0

                        Item {
                            anchors.centerIn: parent
                            width: root.iconSize
                            height: root.iconSize

                            Image {
                                id: launcherIcon
                                anchors.fill: parent
                                source: "image://icon/" + modelData.icon
                                sourceSize.width: root.iconSize
                                sourceSize.height: root.iconSize
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.fallback
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 16
                                visible: launcherIcon.status !== Image.Ready
                            }
                        }

                        MouseArea {
                            id: launcherMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                launcherProcess.command = ["sh", "-c", modelData.command]
                                launcherProcess.running = true
                            }
                        }

                        Process {
                            id: launcherProcess
                        }
                    }
                }

                // ═════════════════════════════════════════════════════
                Item { Layout.fillWidth: true }

                // ═════════════════════════════════════════════════════
                //  CENTER: Time & Date (12hr)
                // ═════════════════════════════════════════════════════
                Rectangle {
                    Layout.preferredWidth: clockRow.implicitWidth + 24
                    Layout.preferredHeight: 34
                    radius: root.widgetRadius
                    color: root.colWidgetBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: "  " + root.currentTime
                            color: root.colFg
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 1
                            height: 18
                            color: root.colPurpleBorder
                            opacity: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.currentDate
                            color: root.colFgDim
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // ═════════════════════════════════════════════════════
                Item { Layout.fillWidth: true }

                // ═════════════════════════════════════════════════════
                //  RIGHT: Network, Volume, Power
                // ═════════════════════════════════════════════════════

                // Network
                Rectangle {
                    Layout.preferredWidth: netRow.implicitWidth + 20
                    Layout.preferredHeight: 34
                    radius: root.widgetRadius
                    color: netMa.containsMouse ? root.colHover : root.colWidgetBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Row {
                        id: netRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: root.networkStatus === "connected" ? "󰤨" : "󰤭"
                            color: root.networkStatus === "connected" ? root.colPurpleGlow : root.colFgDim
                            font.family: root.fontFamily
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.networkName
                            color: root.colFg
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: netMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePopup("network")
                    }
                }

                // Volume
                Rectangle {
                    Layout.preferredWidth: volRow.implicitWidth + 20
                    Layout.preferredHeight: 34
                    radius: root.widgetRadius
                    color: volMa.containsMouse ? root.colHover : root.colWidgetBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Row {
                        id: volRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: root.volumeMuted ? "󰖁" : (root.volumePercent > 50 ? "󰕾" : (root.volumePercent > 0 ? "󰖀" : "󰕿"))
                            color: root.volumeMuted ? root.colFgDim : root.colPurpleGlow
                            font.family: root.fontFamily
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.volumePercent + "%"
                            color: root.colFg
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: volMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePopup("volume")
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    color: root.colPurpleBorder
                    opacity: 0.4
                }

                // Power button
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 34
                    radius: root.widgetRadius
                    color: powerMa.containsMouse ? root.colHover : root.colWidgetBg
                    border.color: root.colPurpleBorder
                    border.width: root.borderWidth

                    Text {
                        anchors.centerIn: parent
                        text: "⏻"
                        color: root.colPurpleGlow
                        font.family: root.fontFamily
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: powerMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePopup("power")
                    }
                }
            }
        }
    }
}
