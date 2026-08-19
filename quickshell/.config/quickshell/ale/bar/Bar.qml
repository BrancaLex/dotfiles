// La barra. Una PanelWindow per monitor, istanziate da Variants sul modello
// Quickshell.screens.
//
// Nota strutturale: questo e' cio' che rende obsoleto waybar/scripts/launch.sh.
// Quel launcher esiste solo perche' waybar e' un processo per barra e al boot
// piu' hook (launch.sh + apply_theme.sh) partivano in parallelo, sovrapponendo
// le istanze -> serviva un flock. Qui le barre sono oggetti figli di un processo
// unico: l'aggiunta o rimozione di un monitor crea/distrugge la finestra da se',
// e non esiste alcuno stato da serializzare.
//
// Il layout replica modules-left / modules-center / modules-right di
// waybar/.config/waybar/config.jsonc.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.services
import qs.bar.modules

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData

        screen: modelData
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-bar"

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: Config.barHeight + Config.barMargin * 2
        // Riserva lo spazio: le finestre tile non passano sotto la barra.
        exclusiveZone: Config.barHeight + Config.barMargin

        Rectangle {
            anchors.fill: parent
            anchors.margins: Config.barMargin
            radius: Config.radius
            // Lo sfondo segue la palette: nessun CSS da rigenerare, il binding
            // si rivaluta quando Pywal ricarica colors.json.
            color: Pywal.alpha(Pywal.background, 0.75)

            border.width: 1
            border.color: Pywal.alpha(Pywal.secondary, 0.35)

            Behavior on color {
                ColorAnimation { duration: Config.animNormal }
            }

            // --- Zona sinistra: workspace + titolo finestra ---
            Row {
                id: leftZone
                anchors.left: parent.left
                anchors.leftMargin: Config.modulePadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Workspaces {
                    anchors.verticalCenter: parent.verticalCenter
                    screenName: bar.modelData.name
                }

                WindowTitle {
                    anchors.verticalCenter: parent.verticalCenter
                    // Non deve mai invadere la zona centrale: il titolo e'
                    // l'unico modulo di larghezza non prevedibile.
                    width: Math.min(implicitWidth, Math.max(0, (centerZone.x - leftZone.x) - 220))
                }
            }

            // --- Zona centrale: sistema, orologio, connettivita' ---
            Row {
                id: centerZone
                anchors.centerIn: parent
                spacing: 6

                Language { anchors.verticalCenter: parent.verticalCenter }
                Memory { anchors.verticalCenter: parent.verticalCenter }
                Cpu { anchors.verticalCenter: parent.verticalCenter }
                Distro { anchors.verticalCenter: parent.verticalCenter }
                IdleInhibitor { anchors.verticalCenter: parent.verticalCenter }
                Clock { anchors.verticalCenter: parent.verticalCenter }
                Network { anchors.verticalCenter: parent.verticalCenter }
                Bluetooth { anchors.verticalCenter: parent.verticalCenter }
                PkgUpdates { anchors.verticalCenter: parent.verticalCenter }
            }

            // --- Zona destra: media, audio, luminosita', batteria, tray ---
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Config.modulePadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Media { anchors.verticalCenter: parent.verticalCenter }
                Audio { anchors.verticalCenter: parent.verticalCenter }
                Brightness { anchors.verticalCenter: parent.verticalCenter }
                Battery { anchors.verticalCenter: parent.verticalCenter }
                Tray { anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
