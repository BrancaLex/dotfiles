import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    tint: Bt.connected ? Pywal.accent : Pywal.secondary
    tooltipText: Bt.tooltip
    active: Bt.connected

    onClicked: Quickshell.execDetached(["ghostty", "-e", "bluetoothctl"])
    onRightClicked: {
        Quickshell.execDetached(["rfkill", Bt.powered ? "block" : "unblock", "bluetooth"]);
        refreshDelay.restart();
    }

    Timer {
        id: refreshDelay
        interval: 800
        onTriggered: Bt.refresh()
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Bt.icon
        color: Bt.powered ? Pywal.accent : Pywal.muted
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }
}
