import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    id: root

    readonly property bool warning: Sys.cpuUsage >= 75
    readonly property bool critical: Sys.cpuUsage >= 90

    tint: critical ? Pywal.error : warning ? Pywal.color3 : Pywal.secondary
    tooltipText: `CPU: ${Sys.cpuUsage}%`
    onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.warning ? "󰀨" : "󰍛"
        color: root.critical ? Pywal.error : Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        // padStart: senza, la larghezza della capsula oscilla a ogni tick fra
        // "9%" e "100%" e trascina tutti i moduli adiacenti. waybar risolveva
        // con min-length/max-length 7.
        text: `${String(Sys.cpuUsage).padStart(3, " ")}%`
        color: Pywal.foreground
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Config.fontWeight
    }
}
