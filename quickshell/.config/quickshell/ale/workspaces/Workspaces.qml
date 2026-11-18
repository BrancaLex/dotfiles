// Indicatore workspace: capsula in alto a sinistra, una pillola per slot.
// Lo slot attivo si allarga orizzontalmente invece di limitarsi a cambiare
// colore.
// Perche' una PanelWindow propria e non un modulo dentro l'isola: l'isola e'
// ancorata left+right e centra la sua pill, quindi non offre un punto di
// aggancio a sinistra. Due layer surface separate non costano nulla (stesso
// processo, stesso scene graph) e restano indipendenti: l'espansione
// dell'isola non sposta i workspace.
// Dati da Hyprland.workspaces, alimentato leggendo .socket2.sock: nessun
// polling. Il pattern delle pillole e' ripreso da bar/modules/Workspaces.qml,
// rimosso nel passaggio a island/ (recuperabile con
// `git show HEAD:quickshell/.config/quickshell/ale/bar/modules/Workspaces.qml`).
// ATTENZIONE ai click: Hyprland.dispatch() NON traduce la sintassi per il
// parser Lua, malgrado l'esistenza di Hyprland.usingLua. Quickshell wrappa
// l'argomento in `hl.dispatch(<arg>)` e lo invia verbatim, quindi passargli la
// forma legacy "workspace 2" produce `hl.dispatch(workspace 2)` ->
// "')' expected near '2'". L'errore e' silenzioso lato UI (compare solo nel
// log) - stessa classe di trappola annotata in CLAUDE.md per `hyprctl
// dispatch`. Forme testate su questa macchina:
//   hl.dispatch("workspace 2")      -> "expected a dispatcher"
//   hl.dsp.workspace(2)             -> "attempt to call a table value"
//   hl.dsp.focus({ workspace = 2 }) -> ok   <- la sola valida

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        // Trasparente: lo sfondo lo dipinge la capsula, cosi' il margine lascia
        // passare il wallpaper.
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-workspaces"
        // Stessa derivazione dell'isola: la finestra insegue la capsula, quindi
        // esiste una sola animazione e la superficie non puo' restare indietro
        // clippando il figlio.
        implicitWidth: capsule.implicitWidth + Config.barMargin * 2
        implicitHeight: capsule.implicitHeight + Config.barMargin * 2
        // Non riserva spazio: la striscia superiore la riserva gia' l'isola.
        // Ignore (non 0!) e' obbligatorio: con exclusiveZone 0 la superficie
        // *rispetta* le zone altrui e il compositore la spingerebbe sotto i
        // 39 px dell'isola, cioe' fuori dall'angolo. Ignore la lascia sul bordo.
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
        }

        Pill {
            id: capsule

            anchors.centerIn: parent
            implicitWidth: row.implicitWidth + Config.modulePadding * 2

            RowLayout {
                id: row

                anchors.centerIn: parent
                spacing: Config.wsPillSpacing + 2

                Repeater {
                    model: Config.slotsFor(win.modelData.name)

                    delegate: Item {
                        id: slot

                        required property var modelData
                        // find() legge w.id a ogni valutazione, quindi QML registra
                        // una dipendenza dinamica su ciascun id. Serve davvero:
                        // all'avvio i workspace compaiono con id -1 e monitor null,
                        // e solo al refresh successivo prendono il valore reale --
                        // il binding si rivaluta da se'. Una lookup table
                        // precalcolata una volta resterebbe ferma sui placeholder.
                        readonly property var ws: Hyprland.workspaces.values.find((w) => {
                            return w.id === slot.modelData;
                        }) || null
                        // active, non focused: active e' "attivo sul proprio
                        // monitor", focused e' "ha l'input". Sono la stessa cosa con
                        // un solo schermo, ma con eDP-2 + HDMI-A-1 focused
                        // lascerebbe spento il widget del monitor non in focus.
                        readonly property bool active: ws ? ws.active : false
                        readonly property bool occupied: ws ? ws.toplevels.values.length > 0 : false
                        readonly property bool urgent: ws ? ws.urgent : false

                        // L'Item e' piu' alto della pillola visibile: fa da bersaglio
                        // di click generoso senza ingrassare la grafica.
                        implicitWidth: active ? Config.wsPillWidthActive : Config.wsPillWidth
                        implicitHeight: Config.barHeight - Config.modulePadding

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: Config.wsPillHeight
                            radius: height / 2
                            // Convenzione del repo: color4 accento, color2
                            // secondario, color1 errore.
                            color: slot.urgent ? Pywal.error : slot.active ? Pywal.accent : slot.occupied ? Pywal.alpha(Pywal.secondary, 0.75) : Pywal.alpha(Pywal.muted, 0.35)
                            // Feedback di hover solo sugli slot non attivi: su
                            // quello attivo sarebbe rumore, e' gia' evidenziato.
                            scale: mouse.containsMouse && !slot.active ? 1.25 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animFast
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animFast
                                }

                            }

                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${slot.modelData} })`)
                        }

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Config.animNormal
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            // La capsula si allarga quando una pillola si espande: senza questo
            // Behavior lo sfondo scatterebbe mentre le pillole scorrono.
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Config.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        mask: Region {
            item: capsule
        }

    }

}
