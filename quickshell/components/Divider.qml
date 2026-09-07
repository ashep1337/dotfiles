import QtQuick
import qs

// The thin purple rule used between sections. Callers set the width (usually
// `width: parent.width`) and may raise the opacity for a harder edge.
Rectangle {
    height: 1
    color: Theme.colPurpleBorder
    opacity: 0.3
}
