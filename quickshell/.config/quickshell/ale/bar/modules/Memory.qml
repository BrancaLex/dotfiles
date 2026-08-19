import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    id: root

    readonly property bool warning: Sys.memUsage >= 75
    readonly property bool critical: Sys.memUsage >= 90

    tint: critical ? Pywal.error : warning ? Pywal.color3 : Pywal.secondary
    tooltipText: `Memoria: ${Sys.memUsedGb.toFixed(1)}/${Sys.memTotalGb.toFixed(1)} GB`
    onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.warning ? "󰀧" : "󰘚"
        color: root.critical ? Pywal.error : Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: `${String(Sys.memUsage).padStart(3, " ")}%`
        color: Pywal.foreground
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Config.fontWeight
    }
}
