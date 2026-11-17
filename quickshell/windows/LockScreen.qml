import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtMultimedia
import qs
import qs.components
import qs.services

Item {
    id: lockRoot

    property string frigateHost: "10.0.1.12"
    property string cameraMonitor: "DP-2"

    function submit() {
        if (Session.busy || Session.password === "") return
        Session.error = ""
        Session.busy = true
        pam.start()
    }

    function wake() {
        if (!Session.locked) return
        if (!lockBlank.running) Power.displayOn()
        lockBlank.restart()
    }

    // Blank the other monitors while keeping the camera monitor on.
    Timer {
        id: lockBlank
        interval:  Theme.lockBlankDelayMs
        repeat: false
        onTriggered: {
            if (Session.locked)
                Power.lockDisplaysOff()
        }
    }

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(Session.password)
        }

        onCompleted: result => {
            Session.busy = false
            Session.password = ""

            if (result === PamResult.Success) {
                Session.error = ""
                Session.locked = false
            } else if (result === PamResult.MaxTries) {
                Session.error = "Too many attempts"
            } else {
                Session.error = "Authentication failed"
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: Session.locked

        WlSessionLockSurface {
            id: lockSurface
            color: "#000000"

            readonly property bool cameraScreen:
                screen !== null
                && screen.name === lockRoot.cameraMonitor
	       
// Only load cameras on DP-2 while the session is locked.
Loader {
    anchors.fill: parent
    active: lockSurface.cameraScreen && Session.locked

    sourceComponent: Component {
        CameraGrid {
            frigateHost: lockRoot.frigateHost
            streamingEnabled: Session.locked
        }
    }
}

	// Old camera grid config
	//
	// // Only create video players on the camera monitor.
            // Loader {
            //     anchors.fill: parent
            //     active: false // lockSurface.cameraScreen && Session.locked
            //
            //     sourceComponent: Component {
            //         Grid {
            //             id: cameraGrid
            //             columns: 2
            //             spacing: 4
            //
            //             Repeater {
            //                 model: [
            //                     "rtsp_cam",
            //                     "rtsp_cam2",
            //                     "rtsp_cam3",
            //                     "rtsp_cam4"
            //                 ]
            //
            //                 delegate: Rectangle {
            //                     id: cameraTile
            //                     required property string modelData
            //
            //                     width: (cameraGrid.width
            //                             - cameraGrid.spacing) / 2
            //                     height: (cameraGrid.height
            //                              - cameraGrid.spacing) / 2
            //                     color: "black"
            //                     clip: true
            //
            //                     readonly property string streamUrl:
            //                         "rtsp://" + lockRoot.frigateHost
            //                         + ":8554/" + modelData
            //
            //                     VideoOutput {
            //                         id: cameraVideo
            //                         anchors.fill: parent
            //                         fillMode: VideoOutput.PreserveAspectFit
            //                     }
            //
            //                     // No AudioOutput: camera audio stays muted.
            //                     MediaPlayer {
            //                         id: cameraPlayer
            //                         source: cameraTile.streamUrl
            //                         videoOutput: cameraVideo
            //
            //                         Component.onCompleted: play()
            //
            //                         onErrorOccurred: (error, errorString) => {
            //                             console.warn(
            //                                 cameraTile.modelData,
            //                                 errorString
            //                             )
            //                             reconnect.restart()
            //                         }
            //                     }
            //
            //                     Timer {
            //                         id: reconnect
            //                         interval: 5000
            //                         repeat: false
            //
            //                         onTriggered: {
            //                             cameraPlayer.stop()
            //                             cameraPlayer.source = ""
            //                             cameraPlayer.source =
            //                                 cameraTile.streamUrl
            //                             cameraPlayer.play()
            //                         }
            //                     }
            //
            //                     Text {
            //                         anchors.centerIn: parent
            //                         visible: reconnect.running
            //                                  || cameraPlayer.error
            //                                     !== MediaPlayer.NoError
            //                         text: cameraTile.modelData
            //                               + "\nReconnecting..."
            //                         horizontalAlignment: Text.AlignHCenter
            //                         color: "white"
            //                         font.family: Theme.fontFamily
            //                         font.pixelSize: 14
            //                     }
            //                 }
            //             }
            //         }
            //     }
            // }
            //
            // Wake displays on pointer activity, including on DP-2.
	  

	    MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons

                onPositionChanged: lockRoot.wake()
                onPressed: lockRoot.wake()
            }

            Rectangle {
                id: lockCard
                visible: !lockSurface.cameraScreen
                anchors.centerIn: parent
                width: 380
                height: lockCol.implicitHeight + 40
                radius: Theme.widgetRadius + 4
                color: Theme.colPopupBg
                border.color: Theme.colPurpleBorder
                border.width: Theme.borderWidth

                Column {
                    id: lockCol
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 14

                    Text {
                        text: Clock.currentTime
                        color: Theme.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: 44
                        font.bold: true
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: Clock.currentDate
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: Gmail.count > 0
                        text: "󰇮  " + Gmail.count + " unread"
                        color: Theme.colPurpleGlow
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Divider {
                        width: parent.width
                        opacity: 0.4
                    }

                    Rectangle {
                        width: parent.width
                        height: 42
                        radius: Theme.widgetRadius
                        color: Theme.colPopupInset
                        border.color: Session.error !== ""
                                      ? Theme.colRed
                                      : Theme.colPurpleBorder
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                text: ""
                                color: Theme.colPurpleGlow
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - 40
                                height: parent.height

                                TextInput {
                                    id: lockInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    focus: !lockSurface.cameraScreen
                                    enabled: !Session.busy
                                             && !lockSurface.cameraScreen
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    color: Theme.colFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    clip: true

                                    onTextChanged: {
                                        Session.password = text
                                        lockRoot.wake()
                                    }

                                    Keys.onPressed: lockRoot.wake()
                                    Keys.onReturnPressed: lockRoot.submit()
                                    Keys.onEnterPressed: lockRoot.submit()
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: lockInput.text === ""
                                             && !Session.busy
                                    text: "Password"
                                    color: Theme.colFgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Session.busy
                              ? "Checking..."
                              : (Session.error !== "" ? Session.error : " ")
                        color: Session.error !== ""
                               ? Theme.colRed
                               : Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            // Clear the local input after authentication or unlocking.
            Connections {
                target: Session

                function onPasswordChanged() {
                    if (Session.password === "")
                        lockInput.text = ""
                }
            }

            Component.onCompleted: {
                if (!lockSurface.cameraScreen)
                    lockInput.forceActiveFocus()
            }
        }

        onLockedChanged: {
            if (sessionLock.locked) {
                Power.displayOn()
                lockBlank.restart()
            } else {
                lockBlank.stop()
                Power.displayOn()
                Session.password = ""
                Session.error = ""
            }
        }
    }
}
