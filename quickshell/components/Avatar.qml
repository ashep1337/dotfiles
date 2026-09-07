import QtQuick
import qs

// Initials in a tinted disc. The tint is derived from the conversation id, so
// a person keeps the same color everywhere without anything being stored.
Item {
    id: av

    property string name: ""
    property string key: ""
    property bool group: false
    property int size: 34

    implicitWidth: av.size
    implicitHeight: av.size

    readonly property var tints: ["#8b5cf6", "#3b82f6", "#06b6d4", "#10b981",
                                  "#f59e0b", "#ef4444", "#ec4899", "#6366f1"]
    readonly property color tint: {
        var s = av.key !== "" ? av.key : av.name
        var h = 0
        for (var i = 0; i < s.length; i++) h = ((h * 31) + s.charCodeAt(i)) >>> 0
        return av.tints[h % av.tints.length]
    }

    readonly property string initials: {
        var parts = (av.name || "?").trim().split(/\s+/)
        if (parts.length === 0 || parts[0] === "") return "?"
        // A number instead of a name has no initials worth showing.
        if (parts[0].charAt(0) === "+") return "#"
        if (parts.length === 1) return parts[0].substring(0, 1).toUpperCase()
        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase()
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(av.tint.r, av.tint.g, av.tint.b, 0.22)
        border.color: Qt.rgba(av.tint.r, av.tint.g, av.tint.b, 0.55)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: av.group ? "󰡉" : av.initials
            color: Qt.lighter(av.tint, 1.35)
            font.family: Theme.fontFamily
            font.pixelSize: av.group ? Math.round(av.size * 0.5) : Math.round(av.size * 0.4)
            font.bold: true
        }
    }
}
