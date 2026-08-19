// Titolo della finestra attiva. Replica la mappa "rewrite" del modulo
// hyprland/window di waybar: le shell e i terminali collassano su "Terminal",
// il desktop vuoto su "Desktop".

import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.services

Text {
    id: root

    readonly property string rawTitle: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""

    text: {
        const t = rawTitle.trim();
        if (t === "" || t === "~") return "Desktop";
        if (["kitty", "ghostty", "zsh", "fish"].includes(t)) return "Terminal";
        return t;
    }

    color: Pywal.foreground
    opacity: 0.85
    elide: Text.ElideRight
    maximumLineCount: 1
    font.family: Config.fontFamily
    font.pixelSize: Config.fontSize
    // Il titolo e' l'unico elemento non-bold della barra, come in waybar
    // (styles/fonts.css: "#window label { font-weight: normal }").
    font.weight: Font.Normal
}
