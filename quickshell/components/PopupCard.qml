import Quickshell
import QtQuick
import qs
import qs.services

// The chrome every bar popup shares: anchored to the bar window, bordered
// panel, and the two-way tie to Popups.active. Children are placed in a
// Column that sizes the popup, so a popup file is just its own content.
PopupWindow {
    id: card

    // The PanelWindow this popup hangs off. anchor.rect.x is left to the
    // caller because each popup pins to a different bar widget.
    property var barWindow: null
    // The Popups.active value that shows this card.
    property string popupName: ""
    property int contentSpacing: 6
    property int contentMargin: 16
    // Power's menu is centered in a fixed-height panel; everything else
    // grows downward from the top.
    property bool centerContent: false

    // The bar this card belongs to. Popups.screenName has to agree before it
    // shows, or all three monitors would pop up their own copy.
    readonly property string screenName:
        (card.barWindow && card.barWindow.screen) ? card.barWindow.screen.name : ""

    readonly property alias contentWidth: col.width
    default property alias content: col.data

    anchor.window: card.barWindow
    anchor.rect.y: 0
    implicitHeight: col.implicitHeight + 24
    visible: Popups.active === card.popupName
             && (Popups.screenName === "" || Popups.screenName === card.screenName)
    color: "transparent"
    // A dismissal that comes from the compositor rather than from a bar click
    // has to clear the shared state too, or the bar button stays highlighted.
    onVisibleChanged: {
        if (!visible && Popups.active === card.popupName
                && Popups.screenName === card.screenName) {
            Popups.close()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.widgetRadius + 2
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth
        Column {
            id: col
            anchors.top: card.centerContent ? undefined : parent.top
            anchors.topMargin: 12
            anchors.verticalCenter: card.centerContent ? parent.verticalCenter : undefined
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - card.contentMargin
            spacing: card.contentSpacing
        }
    }
}
