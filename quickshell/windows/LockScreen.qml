import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import qs
import qs.components
import qs.services

// ext-session-lock-v1 + PAM. The compositor keeps the screen blanked even if
// this process dies, which is what makes a self-written lock screen safe.
//
// Session.locked is the shared switch: everything else in the shell reads it,
// this file is the only thing that drives it back down.
Item {
    id: lockRoot

    function submit() {
        if (Session.busy || Session.password === "") return
        Session.error = ""
        Session.busy = true
        pam.start()
    }

    // Wake the displays and restart the blank countdown while locked
    function wake() {
        if (!Session.locked) return
        if (!lockBlank.running) Power.displayOn()
        lockBlank.restart()
    }

    // hypridle's own dpms listener never fires while the lock surface is up,
    // so the blank timer lives here instead — inside the process that owns the
    // lock state, where nothing external can reset it.
    Timer {
        id: lockBlank
        interval: Theme.lockBlankDelayMs
        repeat: false
        onTriggered: if (Session.locked) Power.displayOff()
    }

    PamContext {
        id: pam
        // Reads /etc/pam.d/login. A dedicated /etc/pam.d/quickshell stack
        // avoids pam_securetty in non-tty contexts if this ever misbehaves.
        config: "login"
        onPamMessage: {
            if (pam.responseRequired) pam.respond(Session.password)
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

            // Any input on the lock screen wakes the displays and restarts the
            // countdown, so typing your password doesn't blank mid-entry.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                onPositionChanged: lockRoot.wake()
                onPressed: lockRoot.wake()
            }

            Rectangle {
                id: lockCard
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
                    // Unread mail is a useful thing to see before unlocking
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

                    // ── Password field ───────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: 42
                        radius: Theme.widgetRadius
                        color: Theme.colPopupInset
                        border.color: Session.error !== "" ? Theme.colRed : Theme.colPurpleBorder
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
                                    focus: true
                                    enabled: !Session.busy
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
                                    visible: lockInput.text === "" && !Session.busy
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
                        text: Session.busy ? "Checking..."
                                           : (Session.error !== "" ? Session.error : " ")
                        color: Session.error !== "" ? Theme.colRed : Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
            // Keep the caret in the password box whenever the lock appears,
            // including on a second monitor's surface.
            Component.onCompleted: lockInput.forceActiveFocus()
        }

        onLockedChanged: {
            if (sessionLock.locked) {
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
