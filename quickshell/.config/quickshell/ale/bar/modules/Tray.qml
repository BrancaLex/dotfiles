// System tray (StatusNotifierItem). Il modulo "extras/tray" di waybar era
// disponibile ma non incluso nel layout attivo; qui e' attivo perche' senza
// waybar sarebbe l'unico punto d'accesso alle icone di stato.

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.services

Row {
    spacing: 10

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry
            required property var modelData

            implicitWidth: 18
            implicitHeight: 18

            Image {
                anchors.fill: parent
                source: entry.modelData.icon
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: mouse.containsMouse ? 1.0 : 0.85

                Behavior on opacity {
                    NumberAnimation { duration: Config.animFast }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // onlyMenu: alcune app non implementano l'attivazione e
                // reagiscono solo al menu contestuale; attivarle non farebbe nulla.
                onClicked: (e) => {
                    if (e.button === Qt.RightButton || entry.modelData.onlyMenu)
                        entry.modelData.display(entry, entry.width / 2, entry.height);
                    else
                        entry.modelData.activate();
                }
            }
        }
    }
}
