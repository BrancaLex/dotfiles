import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    tooltipText: `Luminosita': ${Backlight.percent}%`
    // Scroll per regolare, come on-scroll-up/down del modulo backlight waybar.
    onScrolled: (d) => Backlight.step(d * 5)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Backlight.icon
        color: Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: `${String(Backlight.percent).padStart(3, " ")}%`
        color: Pywal.foreground
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Config.fontWeight
    }
}
