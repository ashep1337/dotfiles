pragma Singleton

import Quickshell
import QtQuick
import qs.services

// The month grid behind the calendar popup.
Singleton {
    id: cal

    property date ref: new Date()
    property int epoch: 0          // bumped at midnight so "today" restyles
    property var cells: cal.buildCalendar(cal.ref, cal.epoch)
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function buildCalendar(ref, epoch) {
        var year = ref.getFullYear()
        var month = ref.getMonth()
        var now = new Date()
        var startDow = new Date(year, month, 1).getDay()
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var cells = []
        for (var i = 0; i < startDow; i++) {
            cells.push({ "day": 0, "current": false, "isToday": false })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            cells.push({
                "day": d,
                "current": true,
                "isToday": (d === now.getDate() && month === now.getMonth() && year === now.getFullYear())
            })
        }
        while (cells.length % 7 !== 0) {
            cells.push({ "day": 0, "current": false, "isToday": false })
        }
        return cells
    }

    function shift(delta) {
        cal.ref = new Date(cal.ref.getFullYear(), cal.ref.getMonth() + delta, 1)
    }
    function today() {
        cal.ref = new Date()
    }

    // Rolling past midnight has to restyle the "today" cell, and the date
    // string flipping is the only signal for it that costs nothing.
    Connections {
        target: Clock
        function onCurrentDateChanged() { cal.epoch = cal.epoch + 1 }
    }
}
