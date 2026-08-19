// Layout di tastiera attivo. Hyprland non espone il layout come proprieta' del
// modulo Quickshell, ma lo annuncia sull'event socket: si parte da una query
// esplicita e si aggiorna sull'evento activelayout.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    id: root
    property string layout: "en"

    tooltipText: `Layout tastiera: ${layout}`

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            // "tastiera,Italian (IT)" -> prende la parte dopo la virgola
            const parts = event.data.split(",");
            if (parts.length < 2) return;
            root.layout = parts[1].slice(0, 2).toLowerCase();
        }
    }

    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main) || JSON.parse(text).keyboards[0];
                    if (kb) root.layout = String(kb.active_keymap).slice(0, 2).toLowerCase();
                } catch (e) {
                    // hyprctl assente o output inatteso: resta il default.
                }
            }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.layout
        color: Pywal.foreground
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Config.fontWeight
    }
}
