import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    tint: Net.kind === "disconnected" || Net.kind === "disabled" ? Pywal.error : Pywal.secondary
    tooltipText: Net.tooltip

    // Le azioni riusano gli script TUI ereditati da waybar (fzf wifi picker):
    // riscriverli in QML non aggiungerebbe nulla, sono gia' collaudati.
    onClicked: Quickshell.execDetached(["ghostty", "-e", "nmtui"])
    onRightClicked: {
        Quickshell.execDetached(["nmcli", "radio", "wifi", Net.wifiEnabled ? "off" : "on"]);
        refreshDelay.restart();
    }

    Timer {
        id: refreshDelay
        interval: 800
        onTriggered: Net.refresh()
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Net.icon
        color: Net.kind === "disconnected" || Net.kind === "disabled" ? Pywal.error : Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }
}
