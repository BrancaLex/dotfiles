// Inibitore di sospensione.
//
// Implementato fermando e riavviando hypridle invece di usare il protocollo
// Wayland idle-inhibit: quest'ultimo richiede una superficie applicativa che lo
// richieda, e hypridle e' comunque l'unico consumatore di idle in questa
// sessione (avviato da hyprland.lua). Fermarlo e' quindi equivalente e, cosa
// piu' utile, verificabile con un pgrep.
//
// NB: hypridle riparte con la configurazione da ~/.config/hypr/hypridle.conf,
// quindi riattivare l'inibitore non perde i listener di lock/dpms/suspend.

import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    id: root
    property bool inhibited: false

    active: inhibited
    tint: inhibited ? Pywal.color3 : Pywal.secondary
    tooltipText: inhibited
        ? "Sospensione inibita (hypridle fermo)"
        : "Sospensione automatica attiva"

    onClicked: {
        if (inhibited) Quickshell.execDetached(["hypridle"]);
        else Quickshell.execDetached(["pkill", "-x", "hypridle"]);
        // Lo stato reale e' verificato dal probe, non assunto dal click: se il
        // comando fallisce l'icona non mente.
        probeDelay.restart();
    }

    Timer {
        id: probeDelay
        interval: 500
        onTriggered: probe.running = true
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        command: ["pgrep", "-x", "hypridle"]
        onExited: (code) => root.inhibited = (code !== 0)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.inhibited ? "󰈈" : "󰈉"
        color: root.inhibited ? Pywal.color3 : Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }
}
