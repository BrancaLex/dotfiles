import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    tint: Updates.failed ? Pywal.error : Updates.total > 0 ? Pywal.color3 : Pywal.secondary
    tooltipText: Updates.tooltip

    onClicked: Quickshell.execDetached(["ghostty", "-e", "bash", "-c", "paru -Syu; read -rsn1 -p 'Premi un tasto...'"])
    onRightClicked: Updates.refresh()

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Updates.icon
        color: Updates.failed ? Pywal.error : Updates.total > 0 ? Pywal.color3 : Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        visible: Updates.total > 0
        anchors.verticalCenter: parent.verticalCenter
        text: Updates.total
        color: Pywal.foreground
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Config.fontWeight
    }
}
