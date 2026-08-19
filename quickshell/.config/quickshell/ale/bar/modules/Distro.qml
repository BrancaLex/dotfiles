// Logo Arch: apre il power menu. Finche' la Fase 4 non porta il menu dentro la
// shell, delega a wlogout con gli stessi argomenti del keybind SUPER+Backspace
// in hyprland.lua.

import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    tint: Pywal.accent
    tooltipText: "Sessione"

    onClicked: Quickshell.execDetached([
        "wlogout", "-b", "5", "-T", "348", "-B", "348", "-n",
        "-C", `${Quickshell.env("HOME")}/.config/wlogout/style.css`
    ])

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰣇"
        color: Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSizeLarge
    }
}
