pragma Singleton

import Quickshell
import QtQuick

// One internal timer, ticking on the minute — no `date` subprocesses.
Singleton {
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }
    readonly property string currentTime: Qt.formatDateTime(sysClock.date, "hh:mm AP")
    readonly property string currentDate: Qt.formatDateTime(sysClock.date, "ddd, MMM dd yyyy")
}
