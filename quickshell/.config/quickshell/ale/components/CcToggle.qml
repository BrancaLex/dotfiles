// Pulsante della griglia del Control Center: icona + etichetta, stato attivo
// a colore pieno d'accento (come .toggle:checked nel CSS di swaync).

import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    required property string icon
    required property string label
    property bool active: false

    signal clicked()

    implicitHeight: 64
    radius: Config.radius
    color: active ? Pywal.accent : Pywal.alpha(Pywal.muted, hover.hovered ? 0.4 : 0.22)
    // Feedback di pressione: lieve rimpicciolimento, nessun rimbalzo.
    scale: tap.pressed ? 0.95 : 1

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: root.active ? Pywal.background : Pywal.foreground
            font.pixelSize: Config.fontSize + 4
            font.family: Config.fontFamily
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.active ? Pywal.background : Pywal.foreground
            font.pixelSize: Config.fontSize - 5
            font.family: Config.fontFamily
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Config.animFast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Config.animFast
            easing.type: Easing.OutCubic
        }
    }
}
