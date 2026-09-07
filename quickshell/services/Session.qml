pragma Singleton

import Quickshell
import QtQuick

// Lock state, shared between the lock surface and everything that needs to
// know whether the session is locked. The PAM exchange and the lock surface
// itself live in windows/LockScreen.qml; this holds only the shared state, so
// nothing here depends on another service.
Singleton {
    id: session

    property bool locked: false
    property string password: ""
    property string error: ""
    property bool busy: false

    // Requests the lock surface. Overlays (popups, launcher, ask) close in
    // response to `locked` changing — see the Connections block in shell.qml —
    // rather than being torn down from here, which would make this service
    // depend on all of them.
    function lock() {
        session.password = ""
        session.error = ""
        session.busy = false
        session.locked = true
    }
}
