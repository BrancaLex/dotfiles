// Orologio + data. Usa SystemClock (tick nativo allineato al secondo) invece del
// pattern Timer + Process("date") mostrato nella guida introduttiva di
// Quickshell: zero fork per aggiornamento.
//
// La precisione e' Minutes, non Seconds: il formato mostrato e' HH:MM come in
// waybar (clock#time), quindi svegliarsi ogni secondo ridisegnerebbe la stessa
// stringa 59 volte su 60.

import Quickshell
import QtQuick
import qs
import qs.services
import qs.bar

Row {
    spacing: 6

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Capsule {
        tint: Pywal.accent
        tooltipText: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Pywal.foreground
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
            font.weight: Config.fontWeight
        }
    }

    Capsule {
        tooltipText: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰸗"
            color: Pywal.accent
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "dd-MM")
            color: Pywal.foreground
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
            font.weight: Config.fontWeight
        }
    }
}
