// Capsula condivisa da isola, workspace e metriche: sfondo pywal, raggio e
// altezza di barra, transizione di colore al cambio palette. Un consumatore
// che deve animare la geometria (l'isola) sovrascrive i binding di
// radius/implicitHeight e aggiunge i propri Behavior: quello sul colore resta.

import QtQuick
import qs
import qs.services

Rectangle {
    implicitHeight: Config.barHeight
    radius: Config.radius
    // Il binding si rivaluta quando Pywal ricarica colors.json: nessun CSS da
    // rigenerare, nessun restart.
    color: Pywal.background

    Behavior on color {
        ColorAnimation {
            duration: Config.animNormal
        }
    }
}
