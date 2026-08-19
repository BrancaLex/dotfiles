// Indicatore workspace, alimentato da Hyprland.workspaces (aggiornato leggendo
// .socket2.sock: nessun polling).
//
// Replica "persistent-workspaces": {"*": 5} del modulo waybar: i primi cinque
// slot sono sempre disegnati anche se vuoti, cosi' la barra non cambia larghezza
// mentre si apre e si chiude l'ultima finestra di un workspace. Gli eventuali
// workspace oltre il quinto compaiono in coda solo se esistono.
//
// ATTENZIONE ai click: Hyprland.dispatch() NON traduce la sintassi per il parser
// Lua, malgrado l'esistenza di Hyprland.usingLua. Quickshell wrappa l'argomento
// in `hl.dispatch(<arg>)` e lo invia verbatim, quindi passargli la forma legacy
// "workspace 2" produce `hl.dispatch(workspace 2)` -> "')' expected near '2'".
// L'errore e' silenzioso lato UI (compare solo nel log) - stessa classe di
// trappola annotata in CLAUDE.md per `hyprctl dispatch`.
// Forme testate su questa macchina:
//   hl.dispatch("workspace 2")      -> "expected a dispatcher"
//   hl.dsp.workspace(2)             -> "attempt to call a table value"
//   hl.dsp.focus({ workspace = 2 }) -> ok   <- la sola valida
// E' la stessa forma gia' usata in hyprland/.config/hypr/hyprland.lua.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.services

Row {
    id: root

    // Nome del monitor su cui vive questa istanza della barra: ogni schermo
    // mostra solo i propri workspace.
    required property string screenName

    readonly property int persistentCount: 5

    // Unione fra gli slot persistenti e i workspace realmente esistenti su
    // questo monitor, esclusi gli speciali (id negativo, es. "special:magic").
    readonly property var slots: {
        const ids = [];
        for (let i = 1; i <= persistentCount; i++) ids.push(i);
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id <= 0) continue;
            if (!ws.monitor || ws.monitor.name !== screenName) continue;
            if (!ids.includes(ws.id)) ids.push(ws.id);
        }
        return ids.sort((a, b) => a - b);
    }

    function wsById(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) || null;
    }

    spacing: 4

    Repeater {
        model: root.slots

        delegate: Item {
            id: slot
            required property var modelData

            readonly property var ws: root.wsById(modelData)
            readonly property bool focused: ws ? ws.focused : false
            readonly property bool occupied: ws ? ws.toplevels.values.length > 0 : false
            readonly property bool urgent: ws ? ws.urgent : false

            implicitWidth: focused ? 26 : 14
            implicitHeight: 22

            Behavior on implicitWidth {
                NumberAnimation { duration: Config.animNormal; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 10
                radius: height / 2

                color: slot.urgent
                    ? Pywal.error
                    : slot.focused
                        ? Pywal.accent
                        : slot.occupied
                            ? Pywal.alpha(Pywal.secondary, 0.75)
                            : Pywal.alpha(Pywal.muted, 0.35)

                Behavior on color {
                    ColorAnimation { duration: Config.animFast }
                }

                scale: mouse.containsMouse && !slot.focused ? 1.25 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: Config.animFast }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${slot.modelData} })`)
            }
        }
    }
}
