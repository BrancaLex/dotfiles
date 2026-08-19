pragma Singleton

// Conteggio aggiornamenti pacchetti. Reimplementa la logica di
// waybar/.config/waybar/scripts/update (Jesse Mirabel, MIT) senza il wrapper
// bash: checkupdates per i repo ufficiali, paru -Quaq per l'AUR.
//
// checkupdates esce 2 quando non ci sono aggiornamenti: e' un successo, non un
// errore, e va distinto da un fallimento reale (rete assente, db lockato).

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
    id: root

    property int pacman: 0
    property int aur: 0
    property bool failed: false

    readonly property int total: pacman + aur
    readonly property string icon: failed ? "󰒑" : total === 0 ? "󰸟" : "󰄠"
    readonly property string tooltip: failed
        ? "Impossibile controllare gli aggiornamenti"
        : total === 0
            ? "Nessun aggiornamento"
            : `Ufficiali: ${pacman}\nAUR: ${aur}`

    function refresh() {
        pacProc.running = true;
        aurProc.running = true;
    }

    Timer {
        interval: 900000                 // 15 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: pacProc
        command: ["checkupdates"]
        stdout: StdioCollector {
            onStreamFinished: root.pacman = text.trim() ? text.trim().split("\n").length : 0
        }
        // exit 2 = "nessun aggiornamento", non un guasto.
        onExited: (code) => root.failed = (code !== 0 && code !== 2)
    }

    Process {
        id: aurProc
        command: ["paru", "-Quaq"]
        stdout: StdioCollector {
            onStreamFinished: root.aur = text.trim() ? text.trim().split("\n").length : 0
        }
    }
}
