import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs
import qs.components
import qs.services

// The fullscreen app search. State lives in services/AppLauncher.qml so the
// bar button and the global shortcut can drive it without reaching in here.
PanelWindow {
    id: appLauncherWindow
    visible: AppLauncher.open
    screen: AppLauncher.screen

    // Overlay layer + exclusive focus is what lets a layer-shell surface
    // receive keystrokes at all — a PopupWindow cannot.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-launcher"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "#aa000000"

    onVisibleChanged: {
        if (visible) {
            appSearch.text = ""
            appSearch.forceActiveFocus()
        } else {
            Launchers.cancelIncoming()
        }
    }

    // ── Drag a result onto the bar to pin it ─────────────────────────
    // The bar is a separate window, so this can't be a Qt drop. What makes it
    // work anyway is the pointer grab: once the button is down, motion keeps
    // arriving here even after the pointer leaves this surface. The pointer is
    // republished through Launchers in *bar* coordinates and bar/PinStrip.qml
    // draws the caret and takes the drop.
    //
    // This window is anchored to the top of the screen and the bar reserves an
    // exclusive zone at the bottom, so this window's bottom edge is exactly the
    // bar's top edge — which is all the conversion needs.
    property var dragEntry: null
    property real dragX: 0
    property real dragY: 0

    function updateEntryDrag(scenePos) {
        appLauncherWindow.dragX = scenePos.x
        appLauncherWindow.dragY = scenePos.y
        Launchers.updateIncoming(scenePos.x, scenePos.y - appLauncherWindow.height)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: AppLauncher.close()
    }

    Rectangle {
        id: appCard
        width: 560
        height: appCardCol.implicitHeight + 24
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        radius: Theme.widgetRadius + 4
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth
        // Swallows clicks so they don't reach the dismiss overlay behind
        MouseArea { anchors.fill: parent }

        Column {
            id: appCardCol
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 10

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
                        text: "󰍉"
                        color: Theme.colPurpleGlow
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item {
                        width: parent.width - 40
                        height: parent.height
                        TextInput {
                            id: appSearch
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            focus: true
                            color: Theme.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            selectByMouse: true
                            selectionColor: Theme.colPurple
                            selectedTextColor: Theme.colFg
                            clip: true
                            onTextChanged: {
                                AppLauncher.query = text
                                AppLauncher.index = 0
                            }
                            Keys.onEscapePressed: AppLauncher.close()
                            Keys.onDownPressed: AppLauncher.moveIndex(1)
                            Keys.onUpPressed: AppLauncher.moveIndex(-1)
                            Keys.onReturnPressed: AppLauncher.run(AppLauncher.results[AppLauncher.index])
                            Keys.onEnterPressed: AppLauncher.run(AppLauncher.results[AppLauncher.index])
                            Keys.onTabPressed: AppLauncher.moveIndex(1)
                            Keys.onPressed: event => {
                                if (event.modifiers & Qt.ControlModifier) {
                                    if (event.key === Qt.Key_N) {
                                        AppLauncher.moveIndex(1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_P) {
                                        AppLauncher.moveIndex(-1)
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: appSearch.text === ""
                            text: "Search applications..."
                            color: Theme.colFgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                        }
                    }
                }
            }

            ListView {
                id: appList
                width: parent.width
                height: Math.min(contentHeight, 380)
                visible: AppLauncher.results.length > 0
                clip: true
                model: AppLauncher.results
                currentIndex: AppLauncher.index
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 90
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property bool selected: appRow.index === AppLauncher.index
                    width: appList.width
                    height: 48
                    radius: 6
                    color: appRow.selected ? Theme.colPurple
                                           : (appRowMa.containsMouse ? Theme.colPopupHover : "transparent")
                    border.color: appRow.selected ? Theme.colPurpleGlow : "transparent"
                    border.width: appRow.selected ? 1 : 0
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12
                        Item {
                            width: 28
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            // Drawn first, so it shows through if the icon
                            // fails to resolve (IconImage renders nothing).
                            Text {
                                anchors.centerIn: parent
                                text: (appRow.modelData.name || "?").charAt(0).toUpperCase()
                                color: Theme.colPurpleGlow
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                            }
                            IconImage {
                                anchors.fill: parent
                                source: appRow.modelData.icon ? ("image://icon/" + appRow.modelData.icon) : ""
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 52
                            spacing: 1
                            Text {
                                text: appRow.modelData.name || appRow.modelData.id
                                color: Theme.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: appRow.selected
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: text !== ""
                                text: appRow.modelData.comment || appRow.modelData.genericName || ""
                                color: Theme.colFgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        id: appRowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: AppLauncher.index = appRow.index
                        onClicked: AppLauncher.run(appRow.modelData)
                    }

                    // Steals the grab from the MouseArea past the drag
                    // threshold, so a click still launches and a drag pins.
                    DragHandler {
                        id: appRowDrag
                        target: null
                        cursorShape: Qt.ClosedHandCursor
                        onActiveChanged: {
                            if (appRowDrag.active) {
                                appLauncherWindow.dragEntry = appRow.modelData
                                appLauncherWindow.updateEntryDrag(appRowDrag.centroid.scenePosition)
                                Launchers.beginIncoming(appRow.modelData,
                                                        AppLauncher.screen ? AppLauncher.screen.name : "")
                            } else {
                                // The strip under the pointer claims this, if any.
                                Launchers.dropIncoming()
                                appLauncherWindow.dragEntry = null
                            }
                        }
                        onCentroidChanged: {
                            if (appRowDrag.active)
                                appLauncherWindow.updateEntryDrag(appRowDrag.centroid.scenePosition)
                        }
                    }
                }
            }

            Text {
                visible: AppLauncher.results.length === 0
                text: "No matches"
                color: Theme.colFgDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 10
                bottomPadding: 10
            }
            Divider { width: parent.width }
            Text {
                text: AppLauncher.results.length + " app" + (AppLauncher.results.length === 1 ? "" : "s")
                      + "  ·  ↑↓ navigate  ·  ⏎ launch  ·  drag to the bar to pin  ·  esc close"
                color: Theme.colFgDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // The icon under the pointer while dragging a result out. It stops at this
    // window's bottom edge, which is where the bar takes over drawing.
    Item {
        id: entryGhost
        visible: appLauncherWindow.dragEntry !== null
        z: 100
        width: 34
        height: 34
        x: appLauncherWindow.dragX - width / 2
        y: appLauncherWindow.dragY - height / 2

        Rectangle {
            anchors.fill: parent
            radius: Theme.widgetRadius
            color: Theme.colHover
            border.color: Theme.colPurpleGlow
            border.width: Theme.borderWidth
        }
        Item {
            anchors.centerIn: parent
            width: Theme.iconSize
            height: Theme.iconSize
            Text {
                anchors.centerIn: parent
                visible: !appLauncherWindow.dragEntry || !appLauncherWindow.dragEntry.icon
                text: appLauncherWindow.dragEntry
                      ? (appLauncherWindow.dragEntry.name || "?").charAt(0).toUpperCase() : ""
                color: Theme.colPurpleGlow
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
            }
            IconImage {
                anchors.fill: parent
                source: (appLauncherWindow.dragEntry && appLauncherWindow.dragEntry.icon)
                        ? ("image://icon/" + appLauncherWindow.dragEntry.icon) : ""
            }
        }
    }
}
